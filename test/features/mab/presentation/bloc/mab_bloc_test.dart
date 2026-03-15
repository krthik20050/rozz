import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rozz/features/mab/domain/entities/mab_record.dart';
import 'package:rozz/features/mab/domain/entities/mab_status.dart';
import 'package:rozz/features/mab/domain/repositories/mab_repository.dart';
import 'package:rozz/features/mab/domain/usecases/calculate_mab.dart';
import 'package:rozz/features/mab/presentation/bloc/mab_bloc.dart';

class MockMabRepository extends Mock implements MabRepository {}
class MockCalculateMab extends Mock implements CalculateMab {}
class FakeMabRecord extends Fake implements MabRecord {}

void main() {
  late MockMabRepository mockRepository;
  late MockCalculateMab mockCalculateMab;
  late MabBloc mabBloc;

  setUpAll(() {
    registerFallbackValue(FakeMabRecord());
  });

  setUp(() {
    mockRepository = MockMabRepository();
    mockCalculateMab = MockCalculateMab();
    mabBloc = MabBloc(mockRepository, mockCalculateMab);
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
        when(() => mockRepository.getMonthRecords(any(), any()))
            .thenAnswer((_) async => tRecords);
        when(() => mockCalculateMab(
              monthRecords: any(named: 'monthRecords'),
              month: any(named: 'month'),
              year: any(named: 'year'),
              now: any(named: 'now'),
            )).thenReturn(tStatus);
        return mabBloc;
      },
      act: (bloc) => bloc.add(const LoadMabStatus(month: 3, year: 2026)),
      expect: () => [
        MabLoading(),
        MabLoaded(tStatus),
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
            .thenAnswer((_) async => tRecords);
        when(() => mockCalculateMab(
              monthRecords: any(named: 'monthRecords'),
              month: any(named: 'month'),
              year: any(named: 'year'),
              now: any(named: 'now'),
            )).thenReturn(tStatus);
        return mabBloc;
      },
      act: (bloc) => bloc.add(const RecordEodBalance(10000.0)),
      expect: () => [
        MabLoading(),
        MabLoaded(tStatus),
      ],
      verify: (_) {
        verify(() => mockRepository.insertEodBalance(any())).called(1);
      },
    );
  });
}
