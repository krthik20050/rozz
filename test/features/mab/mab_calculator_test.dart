import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/features/mab/domain/entities/mab_record.dart';
import 'package:rozz/features/mab/domain/entities/mab_status.dart';
import 'package:rozz/features/mab/domain/usecases/calculate_mab.dart';

void main() {
  group('MabCalculator Tests', () {
    test('1. March day 5, 5 records, verify exact value', () {
      final records = List.generate(5, (i) => MabRecord(
        date: '2026-03-${(i + 1).toString().padLeft(2, '0')}',
        endOfDayBalance: 10000.0,
        month: 3,
        year: 2026,
      ));
      final status = CalculateMab()(
        monthRecords: records,
        month: 3,
        year: 2026,
        now: DateTime(2026, 3, 5),
      );
      expect(status.currentMab, closeTo(1612.90, 0.01));
      expect(status.remainingDays, 31 - 5);
    });

    test('2. March day 31, safe', () {
      final records = List.generate(31, (i) => MabRecord(
        date: '2026-03-${(i + 1).toString().padLeft(2, '0')}',
        endOfDayBalance: 10000.0,
        month: 3,
        year: 2026,
      ));
      final status = CalculateMab()(
        monthRecords: records,
        month: 3,
        year: 2026,
        now: DateTime(2026, 3, 31),
      );
      expect(status.zone, MabZone.safe);
      expect(status.isSafe, true);
    });

    test('3. March day 31, unsafe', () {
      final records = List.generate(31, (i) => MabRecord(
        date: '2026-03-${(i + 1).toString().padLeft(2, '0')}',
        endOfDayBalance: 5000.0,
        month: 3,
        year: 2026,
      ));
      final status = CalculateMab()(
        monthRecords: records,
        month: 3,
        year: 2026,
        now: DateTime(2026, 3, 31),
      );
      expect(status.zone, MabZone.fine);
      expect(status.isSafe, false);
    });

    test('4. Feb leap year (29 days)', () {
      final records = [MabRecord(
        date: '2024-02-01',
        endOfDayBalance: 29000.0,
        month: 2,
        year: 2024,
      )];
      final status = CalculateMab()(
        monthRecords: records,
        month: 2,
        year: 2024,
        threshold: 1000,
        now: DateTime(2024, 2, 1),
      );
      expect(status.currentMab, 1000.0);
    });

    test('5. Feb non-leap (28 days)', () {
      final records = [MabRecord(
        date: '2026-02-01',
        endOfDayBalance: 28000.0,
        month: 2,
        year: 2026,
      )];
      final status = CalculateMab()(
        monthRecords: records,
        month: 2,
        year: 2026,
        threshold: 1000,
        now: DateTime(2026, 2, 1),
      );
      expect(status.currentMab, 1000.0);
    });

    test('6. First day, zero records', () {
      final status = CalculateMab()(
        monthRecords: [],
        month: 3,
        year: 2026,
        now: DateTime(2026, 3, 1),
      );
      expect(status.currentMab, 0.0);
      expect(status.remainingDays, 30);
    });

    test('7. Already safe (minDailyNeeded <= 0)', () {
      final records = List.generate(15, (i) => MabRecord(
        date: '2026-03-${(i + 1).toString().padLeft(2, '0')}',
        endOfDayBalance: 25000.0,
        month: 3,
        year: 2026,
      ));
      final status = CalculateMab()(
        monthRecords: records,
        month: 3,
        year: 2026,
        threshold: 10000,
        now: DateTime(2026, 3, 15),
      );
      expect(status.isSafe, true);
      expect(status.minDailyNeeded, lessThanOrEqualTo(0));
    });

    test('8. Exact ratio 1.0 -> safe', () {
       final records = List.generate(31, (i) => MabRecord(
        date: '2026-03-${(i + 1).toString().padLeft(2, '0')}',
        endOfDayBalance: 10000.0,
        month: 3,
        year: 2026,
      ));
      final status = CalculateMab()(
        monthRecords: records,
        month: 3,
        year: 2026,
        threshold: 10000,
        now: DateTime(2026, 3, 31),
      );
      expect(status.zone, MabZone.safe);
    });

    test('9. Exact ratio 0.85 -> middle', () {
       final records = List.generate(31, (i) => MabRecord(
        date: '2026-03-${(i + 1).toString().padLeft(2, '0')}',
        endOfDayBalance: 8500.0,
        month: 3,
        year: 2026,
      ));
      final status = CalculateMab()(
        monthRecords: records,
        month: 3,
        year: 2026,
        threshold: 10000,
        now: DateTime(2026, 3, 31),
      );
      expect(status.zone, MabZone.middle);
    });

    test('10. Exact ratio 0.70 -> danger', () {
       final records = List.generate(31, (i) => MabRecord(
        date: '2026-03-${(i + 1).toString().padLeft(2, '0')}',
        endOfDayBalance: 7000.0,
        month: 3,
        year: 2026,
      ));
      final status = CalculateMab()(
        monthRecords: records,
        month: 3,
        year: 2026,
        threshold: 10000,
        now: DateTime(2026, 3, 31),
      );
      expect(status.zone, MabZone.danger);
    });

    test('11. Ratio 0.69 -> fine', () {
       final records = List.generate(31, (i) => MabRecord(
        date: '2026-03-${(i + 1).toString().padLeft(2, '0')}',
        endOfDayBalance: 6900.0,
        month: 3,
        year: 2026,
      ));
      final status = CalculateMab()(
        monthRecords: records,
        month: 3,
        year: 2026,
        threshold: 10000,
        now: DateTime(2026, 3, 31),
      );
      expect(status.zone, MabZone.fine);
    });

    test('12. Sparse records (missing days mid-month)', () {
      final records = [
        MabRecord(date: '2026-03-01', endOfDayBalance: 10000.0, month: 3, year: 2026),
        MabRecord(date: '2026-03-10', endOfDayBalance: 20000.0, month: 3, year: 2026),
      ];
      final status = CalculateMab()(
        monthRecords: records,
        month: 3,
        year: 2026,
        now: DateTime(2026, 3, 10),
      );
      expect(status.currentMab, closeTo(967.74, 0.01));
      expect(status.daysRecorded, 2);
    });
  });
}
