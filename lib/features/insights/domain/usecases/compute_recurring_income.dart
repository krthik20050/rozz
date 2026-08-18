import 'package:rozz/features/insights/domain/entities/recurring_income.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';

/// Detects income that arrives month after month from the same sender.
///
/// Pure: takes credit transactions (any date range) plus label/contact
/// lookups and returns recurring-income rows. A sender qualifies when credits
/// appear in 3+ distinct months with amounts within [toleranceFactor] of the
/// median — the same shape of rule used for subscriptions, so a variable
/// allowance (₹2,000 one month, ₹4,800 another) still counts, while one-off
/// windfalls don't.
class ComputeRecurringIncome {
  /// Ratio of the most extreme month to the median that still counts as
  /// "the same recurring payment" (1.75 ≈ Spotify's ₹139/₹199 tier swing).
  final double toleranceFactor;

  const ComputeRecurringIncome({this.toleranceFactor = 1.75});

  List<RecurringIncome> call({
    required List<Transaction> transactions,
    required Map<String, String> labels,
    required Map<String, String> contactPhoneToName,
    required DateTime now,
  }) {
    final monthKey = (DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
    final currentMonth = monthKey(now);

    // Group credit transactions per sender key.
    final byKey = <String, List<Transaction>>{};
    for (final tx in transactions) {
      if (tx.direction != 'credit') continue;
      final key = (tx.recipientName ?? '').trim().toLowerCase();
      if (key.isEmpty) continue;
      byKey.putIfAbsent(key, () => []).add(tx);
    }

    final result = <RecurringIncome>[];
    byKey.forEach((key, txs) {
      // Monthly totals, in month order.
      final byMonth = <String, double>{};
      for (final tx in txs) {
        final date = DateTime.tryParse(tx.date)?.toLocal();
        if (date == null) continue;
        final mk = monthKey(date);
        byMonth[mk] = (byMonth[mk] ?? 0) + tx.amount;
      }
      if (byMonth.length < 3) return; // not enough history to call it recurring

      final amounts = byMonth.values.toList()..sort();
      final median = amounts[amounts.length ~/ 2];
      final minAllowed = median / toleranceFactor;
      final maxAllowed = median * toleranceFactor;
      // Any month wildly outside the band means this sender is irregular
      // (e.g. Papa's ₹1,05,000 transfer) — exclude the whole sender rather
      // than half-label it as recurring income.
      if (amounts.any((a) => a < minAllowed || a > maxAllowed)) return;

      final dates = txs.map((tx) => DateTime.tryParse(tx.date)?.toLocal()).whereType<DateTime>().toList()
        ..sort();
      final lastSeen = dates.last;
      final arrivedThisMonth = byMonth.containsKey(currentMonth);

      // Roll forward past today (like subscription prediction) so the card
      // never suggests a date that already passed.
      var expectedNext = _addMonthClamped(lastSeen);
      while (expectedNext.isBefore(DateTime(now.year, now.month, now.day))) {
        expectedNext = _addMonthClamped(expectedNext);
      }
      final displayName = _displayName(key, labels, contactPhoneToName);

      final paymentsThisMonth = arrivedThisMonth
          ? txs.where((tx) {
              final d = DateTime.tryParse(tx.date)?.toLocal();
              return d != null && monthKey(d) == currentMonth;
            }).length
          : 0;

      result.add(RecurringIncome(
        sender: key,
        displayName: displayName,
        typicalAmount: median,
        monthsSeen: byMonth.length,
        months: byMonth.keys.toList()..sort(),
        lastSeen: lastSeen,
        expectedNext: expectedNext,
        arrivedThisMonth: arrivedThisMonth,
        paymentsThisMonth: paymentsThisMonth,
      ));
    });

    result.sort((a, b) => b.typicalAmount.compareTo(a.typicalAmount));
    return result;
  }

  /// Display name: user label, then contact name, then the raw key.
  String _displayName(
    String key,
    Map<String, String> labels,
    Map<String, String> contactPhoneToName,
  ) {
    final direct = labels[key] ?? labels[key.split('@').first];
    if (direct != null) return direct;
    final digits = key.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      for (var i = 0; i + 10 <= digits.length; i++) {
        final name = contactPhoneToName[digits.substring(i, i + 10)];
        if (name != null) return name;
      }
    }
    return key;
  }

  /// Same day next month, clamped to the target month's last day.
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
