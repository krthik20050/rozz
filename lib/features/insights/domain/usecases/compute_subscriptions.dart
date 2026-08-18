import 'package:rozz/features/insights/domain/entities/subscription.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/shared/utils/merchant_brand_resolver.dart';

/// Detects recurring monthly charges from transaction history.
///
/// Rules (deliberately conservative — better to miss than to guess wrong):
///   - debits only, grouped by merchant key: the brand name when the merchant
///     resolves to a known brand (so "SPOTIFY AB" and "Spotify" are the same
///     subscription), otherwise the raw name, slug-normalized
///   - must appear in at least two *different* months
///   - amounts within 20% of the smallest occurrence → a fixed subscription
///     (a ₹649 Netflix charge)
///   - amounts that drift between a few tiers but appear in 3+ months with
///     largest/smallest ≤ 1.75× → still a subscription, flagged amountVaries
///     (Spotify's ₹139/₹199 plans); a wildly variable Amazon bill is not
///   - monthly cost = the most recent occurrence's amount
/// [dismissedKeys] are slug keys the user removed (a monthly haircut, a local
/// merchant) — they never come back.
class ComputeSubscriptions {
  static const double _amountTolerance = 0.20;

  /// Max largest/smallest ratio for a variable-amount subscription.
  static const double _variableTolerance = 1.75;

  List<Subscription> call({
    required List<Transaction> transactions,
    Set<String> dismissedKeys = const {},
  }) {
    final byMerchant = <String, List<Transaction>>{};
    for (final tx in transactions) {
      if (tx.direction != 'debit') continue;
      final key = _merchantKey(tx);
      if (key.isEmpty || dismissedKeys.contains(key)) continue;
      byMerchant.putIfAbsent(key, () => []).add(tx);
    }

    final subscriptions = <Subscription>[];
    byMerchant.forEach((merchant, txs) {
      txs.sort((a, b) => a.date.compareTo(b.date));

      final months = txs
          .map((tx) => DateTime.parse(tx.date).toLocal())
          .map((d) => '${d.year}-${d.month}')
          .toSet();
      if (months.length < 2) return;

      var smallest = double.infinity;
      for (final tx in txs) {
        if (tx.amount < smallest) smallest = tx.amount;
      }
      if (smallest <= 0) return;

      final largest = txs.map((tx) => tx.amount).reduce((a, b) => a > b ? a : b);
      final ratio = largest / smallest;
      final amountVaries = ratio > 1 + _amountTolerance;
      if (amountVaries) {
        // Variable: only count it when it recurs broadly (3+ months) and stays
        // within a plausible tier range.
        if (months.length < 3 || ratio > _variableTolerance) return;
      }

      final last = txs.last;
      final brand = MerchantBrandResolver.resolve(
        last.recipientName ?? '',
        last.labelType,
        last.direction,
      );
      subscriptions.add(Subscription(
        key: merchant,
        merchant: brand.name.isEmpty ? _displayName(last.recipientName) : brand.name,
        monthlyAmount: last.amount,
        occurrences: txs.length,
        lastOccurrence: DateTime.tryParse(last.date)?.toLocal(),
        amountVaries: amountVaries,
        minAmount: smallest,
        maxAmount: largest,
      ));
    });

    subscriptions.sort((a, b) => b.monthlyAmount.compareTo(a.monthlyAmount));
    return subscriptions;
  }

  /// Slug-normalized grouping key: the brand name when the merchant resolves
  /// to a known brand (canonical spelling across aliases), otherwise the raw
  /// name — so "SPOTIFY AB", "Spotify" and "spotify" all group as Spotify.
  String _merchantKey(Transaction tx) {
    final raw = tx.recipientName?.trim() ?? '';
    if (raw.isEmpty) return '';
    final brand = MerchantBrandResolver.resolve(raw, tx.labelType, tx.direction);
    if (brand.name.isNotEmpty && _slug(brand.name) != _slug(raw)) {
      return _slug(brand.name);
    }
    return _slug(raw);
  }

  String _slug(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _displayName(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return 'Unknown';
    return trimmed
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
