import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/features/insights/domain/usecases/compute_balance_streak.dart';
import 'package:rozz/features/mab/domain/entities/mab_record.dart';

void main() {
  test('counts only recorded days at or above the threshold, up to today', () {
    final streak = computeBalanceStreak(
      records: const [
        MabRecord(date: '2026-08-01', endOfDayBalance: 12000, month: 8, year: 2026),
        MabRecord(date: '2026-08-02', endOfDayBalance: 9000, month: 8, year: 2026), // below
        MabRecord(date: '2026-08-03', endOfDayBalance: 15000, month: 8, year: 2026),
        MabRecord(date: '2026-08-20', endOfDayBalance: 20000, month: 8, year: 2026), // future
      ],
      threshold: 10000,
      month: 8,
      year: 2026,
      today: DateTime(2026, 8, 15),
    );

    expect(streak.daysAbove, 2);
    expect(streak.daysRecorded, 3); // future day excluded
  });

  test('a past month counts every recorded day', () {
    final streak = computeBalanceStreak(
      records: const [
        MabRecord(date: '2026-03-01', endOfDayBalance: 11000, month: 3, year: 2026),
        MabRecord(date: '2026-03-02', endOfDayBalance: 9999, month: 3, year: 2026),
        MabRecord(date: '2026-03-03', endOfDayBalance: 10000, month: 3, year: 2026),
      ],
      threshold: 10000,
      month: 3,
      year: 2026,
      today: DateTime(2026, 8, 15),
    );

    expect(streak.daysAbove, 2); // 10000 is exactly at threshold → counts
    expect(streak.daysRecorded, 3);
  });

  test('empty records yield an empty streak', () {
    final streak = computeBalanceStreak(
      records: const [],
      threshold: 10000,
      month: 8,
      year: 2026,
      today: DateTime(2026, 8, 15),
    );

    expect(streak.daysAbove, 0);
    expect(streak.daysRecorded, 0);
  });

  test('ignores records from other months', () {
    final streak = computeBalanceStreak(
      records: const [
        MabRecord(date: '2026-07-31', endOfDayBalance: 50000, month: 7, year: 2026),
        MabRecord(date: '2026-08-01', endOfDayBalance: 12000, month: 8, year: 2026),
      ],
      threshold: 10000,
      month: 8,
      year: 2026,
      today: DateTime(2026, 8, 15),
    );

    expect(streak.daysAbove, 1);
    expect(streak.daysRecorded, 1);
  });
}
