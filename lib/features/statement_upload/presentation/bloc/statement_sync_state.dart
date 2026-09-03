part of 'statement_sync_bloc.dart';

abstract class StatementSyncState extends Equatable {
  const StatementSyncState();

  @override
  List<Object?> get props => [];
}

class StatementSyncInitial extends StatementSyncState {}

class StatementSyncReady extends StatementSyncState {
  final StatementSyncConfig config;

  /// Present right after a successful sync (shown as a summary).
  final StatementSyncResult? result;

  const StatementSyncReady({required this.config, this.result});

  @override
  List<Object?> get props => [config, result];
}

class StatementSyncSyncing extends StatementSyncState {}

class StatementSyncError extends StatementSyncState {
  final String message;

  const StatementSyncError(this.message);

  @override
  List<Object?> get props => [message];
}