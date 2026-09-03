import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rozz/features/statement_upload/domain/repositories/statement_sync_repository.dart';

part 'statement_sync_event.dart';
part 'statement_sync_state.dart';

class StatementSyncBloc extends Bloc<StatementSyncEvent, StatementSyncState> {
  final StatementSyncRepository _repository;

  StatementSyncBloc(this._repository) : super(StatementSyncInitial()) {
    on<StatementSyncLoad>(_onLoad);
    on<StatementSyncSaveConfig>(_onSaveConfig);
    on<StatementSyncRequested>(_onSync);
  }

  Future<void> _onLoad(
    StatementSyncLoad event,
    Emitter<StatementSyncState> emit,
  ) async {
    try {
      final config = await _repository.loadConfig();
      emit(StatementSyncReady(config: config));
    } catch (e) {
      emit(StatementSyncError(e.toString()));
    }
  }

  Future<void> _onSaveConfig(
    StatementSyncSaveConfig event,
    Emitter<StatementSyncState> emit,
  ) async {
    try {
      await _repository.saveConfig(
        serverUrl: event.serverUrl,
        apiKey: event.apiKey,
      );
      add(StatementSyncLoad());
    } catch (e) {
      emit(StatementSyncError(e.toString()));
    }
  }

  Future<void> _onSync(
    StatementSyncRequested event,
    Emitter<StatementSyncState> emit,
  ) async {
    emit(StatementSyncSyncing());
    try {
      final result = await _repository.syncNow();
      final config = await _repository.loadConfig();
      emit(StatementSyncReady(
        config: config,
        result: result,
      ));
    } catch (e) {
      emit(StatementSyncError(
        e is StatementSyncException ? e.message : e.toString(),
      ));
    }
  }
}