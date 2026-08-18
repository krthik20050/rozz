import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rozz/core/security/secure_storage_service.dart';
import 'package:rozz/features/mab/domain/entities/mab_record.dart';
import 'package:rozz/features/mab/domain/entities/mab_status.dart';
import 'package:rozz/features/mab/domain/repositories/mab_repository.dart';
import 'package:rozz/features/mab/domain/usecases/calculate_mab.dart';
import 'package:rozz/features/mab/presentation/bloc/mab_bloc.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/features/transactions/domain/repositories/transaction_repository.dart';

class MockMabRepository extends Mock implements MabRepository {}
class MockCalculateMab extends Mock implements CalculateMab {}
class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockSecureStorage extends Mock implements SecureStorageService {}
class FakeMabRecord extends Fake implements MabRecord {}

void main() {
  late MockMabRepository mockRepository;
  late MockCalculateMab mockCalculateMab;
  late MockTransactionRepository mockTransactionRepository;
  late MockSecureStorage mockSecureStorage;
  late MabBloc mabBloc;

  setUpAll(() {
    registerFallbackValue(FakeMabRecord());
  });

  setUp(() {
    mockRepository = MockMabRepository();
    mockCalculateMab = MockCalculateMab();
    mockTransactionRepository = MockTransactionRepository();
    mockSecureStorage = MockSecureStorage();
    when(() => mockSecureStorage.readValue(any()))
        .thenAnswer((_) async => null);
    when(() => mockTransactionRepository.getAllTransactions())
        .thenAnswer((_) async => <Transaction>[]);
    when(() => mockTransactionRepository.getLastKnownBalance())
        .thenAnswer((_) async => null);
    mabBloc = MabBloc(
      mockRepository,
      mockCalculateMab,
      mockTransactionRepository,
      mockSecureStorage,
    );
  });

  tearDown(() {
    mabBloc.close();
  });

  final tRecords = [
    const MabRecord(date: '2026-03-01', endOfDayBalance: 10000.0, month: 3, year: 2026),
  ];

  final tStatus = MabStatus(
    currentMab: 10000.0,
    requiredMin: 10000.0,
    zone: MabZone.safe,
    minDailyNeeded: 0.0,
    remainingDays: 30,
    daysRecorded: 1,
    isSafe: true,
    instruction: 'Safe',
  );

  group('LoadMabStatus', () {
    blocTest<MabBloc, MabState>(
      'emits [MabLoading, MabLoaded] with correct status',
      build: () {
        when(() => mockRepository.getMonthRecords(3, 2026))
            .thenAnswer((_) async => tRecords);
        when(() => mockRepository.getMonthRecords(2, 2026))
            .thenAnswer((_) async => <MabRecord>[]);
        when(() => mockRepository.insertEodBalance(any()))
            .thenAnswer((_) async => {});
        when(() => mockCalculateMab(
              monthRecords: any(named: 'monthRecords'),
              month: any(named: 'month'),
              year: any(named: 'year'),
              now: any(named: 'now'),
              threshold: any(named: 'threshold'),
            )).thenReturn(tStatus);
        return mabBloc;
      },
      act: (bloc) => bloc.add(
        LoadMabStatus(month: 3, year: 2026, now: DateTime(2026, 3, 15)),
      ),
      expect: () => [
        MabLoading(),
        MabLoaded(tStatus, tRecords, 3, 2026),
      ],
    );
  });

  group('RecordEodBalance', () {
    blocTest<MabBloc, MabState>(
      'calls insertEodBalance and reloads status',
      build: () {
        when(() => mockRepository.insertEodBalance(any()))
            .thenAnswer((_) async => {});
        when(() => mockRepository.getMonthRecords(any(), any()))
            .thenAnswer((_) async => <MabRecord>[]);
        when(() => mockCalculateMab(
              monthRecords: any(named: 'monthRecords'),
              month: any(named: 'month'),
              year: any(named: 'year'),
              now: any(named: 'now'),
              threshold: any(named: 'threshold'),
            )).thenReturn(tStatus);
        return mabBloc;
      },
      act: (bloc) => bloc.add(const RecordEodBalance(10000.0)),
      expect: () => [
        MabLoading(),
        MabLoaded(
          tStatus,
          const [],
          DateTime.now().month,
          DateTime.now().year,
        ),
      ],
      verify: (_) {
        verify(() => mockRepository.insertEodBalance(any())).called(1);
      },
    );
  });

  group('Carry-forward fill', () {
    blocTest<MabBloc, MabState>(
      'fills gap days with the last real balance instead of ₹0',
      build: () {
        // One real balance known mid-month (Aug 10); days before it have no data
        // and must stay unfilled, days after it must be carried forward.
        when(() => mockRepository.getMonthRecords(8, 2026)).thenAnswer((_) async => const [
          MabRecord(date: '2026-08-10', endOfDayBalance: 20000.0, month: 8, year: 2026),
        ]);
        when(() => mockRepository.getMonthRecords(7, 2026))
            .thenAnswer((_) async => <MabRecord>[]);
        when(() => mockRepository.insertEodBalance(any()))
            .thenAnswer((_) async => {});
        when(() => mockCalculateMab(
              monthRecords: any(named: 'monthRecords'),
              month: any(named: 'month'),
              year: any(named: 'year'),
              now: any(named: 'now'),
              threshold: any(named: 'threshold'),
            )).thenReturn(tStatus);
        return mabBloc;
      },
      act: (bloc) => bloc.add(
        LoadMabStatus(month: 8, year: 2026, now: DateTime(2026, 8, 15)),
      ),
      expect: () => [
        MabLoading(),
        MabLoaded(tStatus, const [
          MabRecord(date: '2026-08-10', endOfDayBalance: 20000.0, month: 8, year: 2026),
        ], 8, 2026),
      ],
      verify: (_) {
        final captured = verify(() => mockRepository.insertEodBalance(captureAny())).captured;
        final records = captured.cast<MabRecord>();
        expect(records, hasLength(4)); // Aug 11-14; TODAY (Aug 15) is never estimated
        expect(
          records.map((r) => r.date).toList(),
          ['2026-08-11', '2026-08-12', '2026-08-13', '2026-08-14'],
        );
        for (final r in records) {
          expect(r.endOfDayBalance, 20000.0);
          expect(r.month, 8);
          expect(r.year, 2026);
        }
      },
    );
  });
}
