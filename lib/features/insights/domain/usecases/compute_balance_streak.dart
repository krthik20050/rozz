import 'package:rozz/features/insights/domain/entities/balance_streak.dart';
import 'package:rozz/features/mab/domain/entities/mab_record.dart';

/// Counts recorded days in a month whose end-of-day balance stayed at or above
/// the MAB threshold. Only days up to [today] count for the current month —
/// future days are unknown. The denominator is the number of recorded days,
/// so the figure stays honest when the month is only partially recorded.
BalanceStreak computeBalanceStreak({
  required List<MabRecord> records,
  required double threshold,
  required int month,
  required int year,
  required DateTime today,
}) {
  final isCurrentMonth = today.year == year && today.month == month;
  final lastDay = isCurrentMonth ? today.day : DateTime(year, month + 1, 0).day;

  var daysAbove = 0;
  var daysRecorded = 0;
  for (final record in records) {
    final date = DateTime.tryParse(record.date);
    if (date == null || date.year != year || date.month != month) continue;
    if (date.day > lastDay) continue; // future days aren't known yet

    daysRecorded++;
    if (record.endOfDayBalance >= threshold) daysAbove++;
  }

  return BalanceStreak(daysAbove: daysAbove, daysRecorded: daysRecorded);
}
