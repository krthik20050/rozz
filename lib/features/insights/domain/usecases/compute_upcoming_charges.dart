import 'package:rozz/features/insights/domain/entities/subscription.dart';
import 'package:rozz/features/insights/domain/entities/upcoming_charge.dart';

/// Predicts the next charge for each detected [Subscription], sorted soonest
/// first.
///
/// Pure: takes subscriptions + today, returns upcoming charges. Prediction:
/// the next charge lands on the same day-of-month as the last occurrence, one
/// month later — clamped to the last day of the target month (a Jan 31 charge
/// lands Feb 28, not Mar 3). If that date has already passed (the merchant
/// charged early), roll forward month by month until it is today or later.
///
/// A charge only surfaces once it is within [daysAhead] of its due date — a
/// charge you already paid this month shouldn't nag you three weeks early
/// (e.g. Spotify paid Aug 8 appears only from ~Sep 1 for the Sep 8 charge).
class ComputeUpcomingCharges {
  /// How many days before the due date a charge starts showing. Research:
  /// reminders closer than a week convert; earlier ones get ignored.
  final int daysAhead;

  const ComputeUpcomingCharges({this.daysAhead = 7});

  List<UpcomingCharge> call({
    required List<Subscription> subscriptions,
    required DateTime today,
  }) {
    final todayStart = DateTime(today.year, today.month, today.day);
    final horizon = todayStart.add(Duration(days: daysAhead));
    final upcoming = <UpcomingCharge>[];

    for (final sub in subscriptions) {
      final last = sub.lastOccurrence;
      if (last == null) continue;

      var next = _addMonthClamped(last);
      while (next.isBefore(todayStart)) {
        next = _addMonthClamped(next);
      }

      // Too early to remind — stay quiet until the window opens.
      if (next.isAfter(horizon)) continue;

      upcoming.add(UpcomingCharge(
        merchant: sub.merchant,
        amount: sub.monthlyAmount,
        predictedDate: next,
      ));
    }

    upcoming.sort((a, b) => a.predictedDate.compareTo(b.predictedDate));
    return upcoming;
  }

  /// Same day next month, never overflowing: the day is clamped to the last
  /// day of the target month before [DateTime] is constructed.
  DateTime _addMonthClamped(DateTime date) {
    var targetMonth = date.month + 1;
    var targetYear = date.year;
    if (targetMonth > 12) {
      targetMonth = 1;
      targetYear++;
    }
    final lastDayOfTarget = DateTime(targetYear, targetMonth + 1, 0).day;
    final day = date.day > lastDayOfTarget ? lastDayOfTarget : date.day;
    return DateTime(targetYear, targetMonth, day);
  }
}
