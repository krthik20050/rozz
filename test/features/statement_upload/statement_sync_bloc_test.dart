import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rozz/features/statement_upload/domain/repositories/statement_sync_repository.dart';
import 'package:rozz/features/statement_upload/presentation/bloc/statement_sync_bloc.dart';

class MockStatementSyncRepository extends Mock
    implements StatementSyncRepository {}

void main() {
  late MockStatementSyncRepository repository;
  late StatementSyncBloc bloc;

  setUp(() {
    repository = MockStatementSyncRepository();
    bloc = StatementSyncBloc(repository);
  });

  tearDown(() {
    bloc.close();
  });

  const config = StatementSyncConfig(
    serverUrl: 'https://rozz.example.com',
    apiKeySet: true,
  );

  group('StatementSyncLoad', () {
    blocTest<StatementSyncBloc, StatementSyncState>(
      'emits Ready with the loaded config',
      build: () {
        when(() => repository.loadConfig())
            .thenAnswer((_) async => config);
        return bloc;
      },
      act: (bloc) => bloc.add(const StatementSyncLoad()),
      expect: () => [
        const StatementSyncReady(config: config),
      ],
    );

    blocTest<StatementSyncBloc, StatementSyncState>(
      'emits Error when the config load fails',
      build: () {
        when(() => repository.loadConfig())
            .thenThrow(Exception('keystore broken'));
        return bloc;
      },
      act: (bloc) => bloc.add(const StatementSyncLoad()),
      expect: () => [
        isA<StatementSyncError>()
            .having((e) => e.message, 'message', contains('keystore')),
      ],
    );
  });

  group('StatementSyncSaveConfig', () {
    blocTest<StatementSyncBloc, StatementSyncState>(
      'saves and reloads the config',
      build: () {
        when(() => repository.saveConfig(
              serverUrl: any(named: 'serverUrl'),
              apiKey: any(named: 'apiKey'),
            )).thenAnswer((_) async {});
        when(() => repository.loadConfig())
            .thenAnswer((_) async => config);
        return bloc;
      },
      act: (bloc) => bloc.add(const StatementSyncSaveConfig(
            serverUrl: 'https://rozz.example.com',
            apiKey: 'k',
          )),
      expect: () => [
        const StatementSyncReady(config: config),
      ],
      verify: (_) {
        verify(() => repository.saveConfig(
              serverUrl: 'https://rozz.example.com',
              apiKey: 'k',
            )).called(1);
      },
    );

    blocTest<StatementSyncBloc, StatementSyncState>(
      'surfaces a save failure as Error',
      build: () {
        when(() => repository.saveConfig(
              serverUrl: any(named: 'serverUrl'),
              apiKey: any(named: 'apiKey'),
            )).thenThrow(const StatementSyncException('URL cannot be empty.'));
        return bloc;
      },
      act: (bloc) => bloc.add(const StatementSyncSaveConfig(
            serverUrl: '',
            apiKey: 'k',
          )),
      expect: () => [
        const StatementSyncError('URL cannot be empty.'),
      ],
    );
  });

  group('StatementSyncRequested', () {
    const result = StatementSyncResult(
      fetched: 5,
      inserted: 3,
      duplicates: 2,
      lastSync: '2026-08-20T10:00:00.000Z',
    );

    blocTest<StatementSyncBloc, StatementSyncState>(
      'emits Syncing then Ready with the sync result',
      build: () {
        when(() => repository.syncNow()).thenAnswer((_) async => result);
        when(() => repository.loadConfig())
            .thenAnswer((_) async => config);
        return bloc;
      },
      act: (bloc) => bloc.add(const StatementSyncRequested()),
      expect: () => [
        StatementSyncSyncing(),
        const StatementSyncReady(config: config, result: result),
      ],
      verify: (_) {
        verify(() => repository.syncNow()).called(1);
      },
    );

    blocTest<StatementSyncBloc, StatementSyncState>(
      'emits Error with the unauthorized message on a key rejection',
      build: () {
        when(() => repository.syncNow())
            .thenThrow(const StatementSyncException.unauthorized());
        return bloc;
      },
      act: (bloc) => bloc.add(const StatementSyncRequested()),
      expect: () => [
        StatementSyncSyncing(),
        isA<StatementSyncError>().having(
          (e) => e.message,
          'message',
          contains('API key'),
        ),
      ],
    );
  });
}