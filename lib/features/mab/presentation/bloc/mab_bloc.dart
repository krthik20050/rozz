import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rozz/features/mab/domain/entities/mab_record.dart';
import 'package:rozz/features/mab/domain/entities/mab_status.dart';
import 'package:rozz/features/mab/domain/repositories/mab_repository.dart';
import 'package:rozz/features/mab/domain/usecases/calculate_mab.dart';
import 'package:intl/intl.dart';

part 'mab_event.dart';
part 'mab_state.dart';

class MabBloc extends Bloc<MabEvent, MabState> {
  final MabRepository _repository;
  final CalculateMab _calculateMab;

  MabBloc(this._repository, this._calculateMab) : super(MabInitial()) {
    on<LoadMabStatus>(_onLoadMabStatus);
    on<RecordEodBalance>(_onRecordEodBalance);
  }

  Future<void> _onLoadMabStatus(
    LoadMabStatus event,
    Emitter<MabState> emit,
  ) async {
    emit(MabLoading());
    try {
      final records = await _repository.getMonthRecords(event.month, event.year);
      final now = event.now ?? DateTime.now();
      final status = _calculateMab(
        monthRecords: records,
        month: event.month,
        year: event.year,
        now: now,
      );
      emit(MabLoaded(status));
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
