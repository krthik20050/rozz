import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rozz/core/security/secure_storage_service.dart';
import 'package:rozz/features/mab/domain/entities/mab_record.dart';
import 'package:rozz/features/mab/domain/entities/mab_status.dart';
import 'package:rozz/features/mab/domain/repositories/mab_repository.dart';
import 'package:rozz/features/mab/domain/usecases/calculate_mab.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:intl/intl.dart';

part 'mab_event.dart';
part 'mab_state.dart';

class MabBloc extends Bloc<MabEvent, MabState> {
  /// Default required minimum balance until the user sets their own.
  static const double defaultRequiredMin = 5000;
  static const String requiredMinKey = 'mab_min_balance';

  final MabRepository _repository;
  final CalculateMab _calculateMab;
  final TransactionRepository _transactionRepository;
  final SecureStorageService _secureStorage;

  MabBloc(
    this._repository,
    this._calculateMab,
    this._transactionRepository,
    this._secureStorage,
  ) : super(MabInitial()) {
    on<LoadMabStatus>(_onLoadMabStatus);
    on<RecordEodBalance>(_onRecordEodBalance);
    on<SetRequiredMin>(_onSetRequiredMin);
  }

  Future<void> _onLoadMabStatus(
    LoadMabStatus event,
    Emitter<MabState> emit,
  ) async {
    emit(MabLoading());
    try {
      final month = event.month;
      final year = event.year;
      final now = event.now ?? DateTime.now();

      // 1. Real balances already in the DB (SMS balance snapshots + prior fills).
      //    These are the ground truth — estimates below never overwrite them.
      final existingRecords = await _repository.getMonthRecords(month, year);
      final Map<String, double> dailyBalances = {
        for (final r in existingRecords) r.date: r.endOfDayBalance,
      };

      // 2. Estimate EOD balances for days that have transactions but no snapshot.
      final transactions = await _transactionRepository.getAllTransactions();
      if (transactions.isNotEmpty) {
        final sortedTxs = [...transactions]..sort((a, b) => a.date.compareTo(b.date));

        // Seed from the last known balance; reverse-accumulate so every day's
        // value is relative to a real balance, not zero.
        final lastBalance = await _transactionRepository.getLastKnownBalance();
        if (lastBalance != null) {
          double balanceBefore = lastBalance;
          for (final tx in sortedTxs.reversed) {
            final txDate = DateTime.parse(tx.date).toLocal();
            if (txDate.month == month && txDate.year == year) {
              // putIfAbsent: first write in reversed order = balance after the
              // day's LAST transaction, which is the EOD balance.
              dailyBalances.putIfAbsent(
                DateFormat('yyyy-MM-dd').format(txDate),
                () => balanceBefore,
              );
            }
            balanceBefore = tx.direction == 'credit'
                ? balanceBefore - tx.amount
                : balanceBefore + tx.amount;
          }
        } else {
          // No balance anchor anywhere; forward estimate from zero.
          double runningBalance = 0;
          for (final tx in sortedTxs) {
            if (tx.direction == 'credit') {
              runningBalance += tx.amount;
            } else {
              runningBalance -= tx.amount;
            }
            
            final txDate = DateTime.parse(tx.date).toLocal();
            if (txDate.month == month && txDate.year == year) {
              final dateKey = DateFormat('yyyy-MM-dd').format(txDate);
              dailyBalances.putIfAbsent(dateKey, () => runningBalance);
            }
          }
        }
      }

      // 3. Carry-forward fill. Days with NO data (no SMS, no transaction, no
      //    snapshot) previously counted as ₹0 in the MAB, dragging it down.
      //    Instead, walk the month day-by-day and give gap days the last real
      //    balance. Seed from the previous month's closing balance so early-
      //    month gaps (before the first record) get a value too. Days before
      //    any known balance with no prior-month record stay unfilled — we
      //    genuinely don't know them.
      final isCurrentMonth = now.year == year && now.month == month;
      final isPastMonth = year < now.year || (year == now.year && month < now.month);
      final int lastDay;
      if (isCurrentMonth) {
        lastDay = now.day;
      } else if (isPastMonth) {
        lastDay = DateTime(year, month + 1, 0).day;
      } else {
        lastDay = 0; // future month — nothing to fill
      }

      double? carry;
      if (lastDay > 0) {
        final priorMonth = DateTime(year, month - 1, 1);
        final priorRecords = await _repository.getMonthRecords(priorMonth.month, priorMonth.year);
        if (priorRecords.isNotEmpty) {
          carry = priorRecords.last.endOfDayBalance;
        }
      }

      final existingDates = existingRecords.map((r) => r.date).toSet();
      // Month already fully recorded (or filled by a prior run) — nothing to do.
      if (existingDates.length < lastDay) {
        // NEVER write an estimated row for TODAY: the home balance reads
        // mab_history's newest row, and a carry estimate for today would pin it
        // to a stale value all day (real snapshots arrive "as on yesterday" and
        // can't displace it). Today gets a row only from real data.
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        for (int d = 1; d <= lastDay; d++) {
          final dateStr = DateFormat('yyyy-MM-dd').format(DateTime(year, month, d));
          final known = dailyBalances[dateStr];
          if (known != null) {
            // Real data refreshes the carry for subsequent gap days.
            carry = known;
            if (!existingDates.contains(dateStr)) {
              await _repository.insertEodBalance(MabRecord(
                date: dateStr,
                endOfDayBalance: known,
                month: month,
                year: year,
              ));
            }
          } else if (carry != null &&
              dateStr != todayStr &&
              !existingDates.contains(dateStr)) {
            await _repository.insertEodBalance(MabRecord(
              date: dateStr,
              endOfDayBalance: carry,
              month: month,
              year: year,
            ));
          }
        }
      }

      // 4. Fetch updated records and calculate with the user's real required
      //    minimum (default ₹5,000, editable in the MAB screen).
      final updatedRecords = await _repository.getMonthRecords(month, year);
      final storedMin = await _secureStorage.readValue(requiredMinKey);
      final threshold = double.tryParse(storedMin ?? '') ?? defaultRequiredMin;
      final status = _calculateMab(
        monthRecords: updatedRecords,
        month: month,
        year: year,
        now: now,
        threshold: threshold,
      );
      emit(MabLoaded(status, updatedRecords, month, year));
    } catch (e) {
      emit(MabError(e.toString()));
    }
  }

  Future<void> _onSetRequiredMin(
    SetRequiredMin event,
    Emitter<MabState> emit,
  ) async {
    try {
      await _secureStorage.writeValue(
        requiredMinKey,
        event.amount.toString(),
      );
      final now = DateTime.now();
      add(LoadMabStatus(month: event.month, year: event.year, now: now));
    } catch (e) {
      emit(MabError(e.toString()));
    }
  }

  Future<void> _onRecordEodBalance(
    RecordEodBalance event,
    Emitter<MabState> emit,
  ) async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      await _repository.insertEodBalance(MabRecord(
        date: dateStr,
        endOfDayBalance: event.balance,
        month: now.month,
        year: now.year,
      ));
      add(LoadMabStatus(month: now.month, year: now.year, now: now));
    } catch (e) {
      emit(MabError(e.toString()));
    }
  }
}