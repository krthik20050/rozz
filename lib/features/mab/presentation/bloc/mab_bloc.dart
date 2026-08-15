import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rozz/features/mab/domain/entities/mab_record.dart';
import 'package:rozz/features/mab/domain/entities/mab_status.dart';
import 'package:rozz/features/mab/domain/repositories/mab_repository.dart';
import 'package:rozz/features/mab/domain/usecases/calculate_mab.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:intl/intl.dart';

part 'mab_event.dart';
part 'mab_state.dart';

class MabBloc extends Bloc<MabEvent, MabState> {
  final MabRepository _repository;
  final CalculateMab _calculateMab;
  final TransactionRepository _transactionRepository;

  MabBloc(this._repository, this._calculateMab, this._transactionRepository) : super(MabInitial()) {
    on<LoadMabStatus>(_onLoadMabStatus);
    on<RecordEodBalance>(_onRecordEodBalance);
  }

  Future<void> _onLoadMabStatus(
    LoadMabStatus event,
    Emitter<MabState> emit,
  ) async {
    emit(MabLoading());
    try {
      // 1. Check if we need to auto-backfill records from transactions
      final existingRecords = await _repository.getMonthRecords(event.month, event.year);
      final transactions = await _transactionRepository.getAllTransactions();
      
      if (transactions.isNotEmpty) {
        // Simple backfill logic: find last balance for each day
        final Map<String, double> dailyBalances = {};
        
        // Sort transactions by date ASC to calculate running balances
        final sortedTxs = List.from(transactions)..sort((a, b) => a.date.compareTo(b.date));

        // Seed from the last SMS balance-after when known; reverse-accumulate so
        // every day's value is relative to a real balance, not zero.
        final lastBalance = await _transactionRepository.getLastKnownBalance();
        if (lastBalance != null) {
          double balanceBefore = lastBalance;
          for (final tx in sortedTxs.reversed) {
            final txDate = DateTime.parse(tx.date).toLocal();
            if (txDate.month == event.month && txDate.year == event.year) {
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
          // ponytail: no balance-after in history; forward estimate from zero.
          double runningBalance = 0;
          for (var tx in sortedTxs) {
            if (tx.direction == 'credit') {
              runningBalance += tx.amount;
            } else {
              runningBalance -= tx.amount;
            }
            
            final txDate = DateTime.parse(tx.date).toLocal();
            if (txDate.month == event.month && txDate.year == event.year) {
              final dateKey = DateFormat('yyyy-MM-dd').format(txDate);
              dailyBalances[dateKey] = runningBalance;
            }
          }
        }

        // Save missing days to DB
        for (var entry in dailyBalances.entries) {
          if (!existingRecords.any((r) => r.date == entry.key)) {
            await _repository.insertEodBalance(MabRecord(
              date: entry.key,
              endOfDayBalance: entry.value,
              month: event.month,
              year: event.year,
            ));
          }
        }
      }

      // 2. Fetch updated records and calculate
      final updatedRecords = await _repository.getMonthRecords(event.month, event.year);
      final now = event.now ?? DateTime.now();
      final status = _calculateMab(
        monthRecords: updatedRecords,
        month: event.month,
        year: event.year,
        now: now,
      );
      emit(MabLoaded(status, records));
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