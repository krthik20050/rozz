import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/features/insights/domain/entities/subscription.dart';
import 'package:rozz/features/insights/domain/usecases/compute_upcoming_charges.dart';

void main() {
  // Prediction-logic tests use a wide window so they exercise the date math,
  // not the reminder timing. The window itself gets its own test below.
  final compute = ComputeUpcomingCharges(daysAhead: 90);

  Subscription sub({
    required String merchant,
    required double monthlyAmount,
    required DateTime lastOccurrence,
  }) {
    return Subscription(
      merchant: merchant,
      monthlyAmount: monthlyAmount,
      occurrences: 3,
      lastOccurrence: lastOccurrence,
    );
  }

  test('predicts same day next month as upcoming', () {
    final charges = compute(
      subscriptions: [
        sub(merchant: 'Netflix Ent', monthlyAmount: 649, lastOccurrence: DateTime(2026, 7, 18)),
      ],
      today: DateTime(2026, 8, 15),
    );

    expect(charges, hasLength(1));
    expect(charges.single.merchant, 'Netflix Ent');
    expect(charges.single.amount, 649);
    expect(charges.single.predictedDate, DateTime(2026, 8, 18));
  });

  test('rolls a stale subscription forward to its next upcoming charge', () {
    final charges = compute(
      subscriptions: [
        // Last charged 10 Jun; the 10 Jul and 10 Aug charges were already
        // taken, so the next one is 10 Sep.
        sub(merchant: 'Gym', monthlyAmount: 1200, lastOccurrence: DateTime(2026, 6, 10)),
      ],
      today: DateTime(2026, 8, 15),
    );

    expect(charges, hasLength(1));
    expect(charges.single.predictedDate, DateTime(2026, 9, 10));
  });

  test('rolls forward when the predicted date already passed', () {
    final charges = compute(
      subscriptions: [
        // Last charged 20 Jul; next predicted 20 Aug, but today is 28 Aug —
        // the charge already happened, so the *following* one is 20 Sep.
        sub(merchant: 'Internet', monthlyAmount: 799, lastOccurrence: DateTime(2026, 7, 20)),
      ],
      today: DateTime(2026, 8, 28),
    );

    expect(charges.single.predictedDate, DateTime(2026, 9, 20));
  });

  test('clamps month-end dates to the last day of the target month', () {
    final charges = compute(
      subscriptions: [
        sub(merchant: 'Vendor', monthlyAmount: 500, lastOccurrence: DateTime(2026, 1, 31)),
      ],
      today: DateTime(2026, 2, 15),
    );

    expect(charges.single.predictedDate, DateTime(2026, 2, 28));
  });

  test('sorts by predicted date soonest first', () {
    final charges = compute(
      subscriptions: [
        sub(merchant: 'Later', monthlyAmount: 100, lastOccurrence: DateTime(2026, 8, 25)),
        sub(merchant: 'Soon', monthlyAmount: 200, lastOccurrence: DateTime(2026, 7, 20)),
      ],
      today: DateTime(2026, 8, 15),
    );

    expect(charges.map((c) => c.merchant).toList(), ['Soon', 'Later']);
  });

  test('ignores subscriptions without a last occurrence', () {
    final charges = compute(
      subscriptions: [
        const Subscription(merchant: 'X', monthlyAmount: 100, occurrences: 2),
      ],
      today: DateTime(2026, 8, 15),
    );

    expect(charges, isEmpty);
  });

  test('stays quiet until a charge is within the look-ahead window', () {
    // Default window: 7 days. Spotify charged 8 Aug → next due 8 Sep; on
    // 16 Aug that's 23 days away — already paid this month, so stay quiet.
    final quiet = ComputeUpcomingCharges()(
      subscriptions: [
        sub(merchant: 'Spotify', monthlyAmount: 139, lastOccurrence: DateTime(2026, 8, 8)),
      ],
      today: DateTime(2026, 8, 16),
    );
    expect(quiet, isEmpty);

    // Six days before the 8 Sep due date it finally surfaces.
    final due = ComputeUpcomingCharges()(
      subscriptions: [
        sub(merchant: 'Spotify', monthlyAmount: 139, lastOccurrence: DateTime(2026, 8, 8)),
      ],
      today: DateTime(2026, 9, 2),
    );
    expect(due, hasLength(1));
    expect(due.single.predictedDate, DateTime(2026, 9, 8));

    // Exactly on the horizon edge (7 days out) it shows.
    final edge = ComputeUpcomingCharges()(
      subscriptions: [
        sub(merchant: 'Spotify', monthlyAmount: 139, lastOccurrence: DateTime(2026, 8, 8)),
      ],
      today: DateTime(2026, 9, 1),
    );
    expect(edge, hasLength(1));
  });
}
