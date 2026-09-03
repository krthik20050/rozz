part of 'statement_sync_bloc.dart';

abstract class StatementSyncEvent extends Equatable {
  const StatementSyncEvent();

  @override
  List<Object?> get props => [];
}

class StatementSyncLoad extends StatementSyncEvent {
  const StatementSyncLoad();
}

class StatementSyncSaveConfig extends StatementSyncEvent {
  final String serverUrl;
  final String apiKey;

  const StatementSyncSaveConfig({
    required this.serverUrl,
    required this.apiKey,
  });

  @override
  List<Object?> get props => [serverUrl, apiKey];
}

class StatementSyncRequested extends StatementSyncEvent {
  const StatementSyncRequested();
}