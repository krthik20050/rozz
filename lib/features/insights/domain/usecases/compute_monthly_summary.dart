import 'package:rozz/features/insights/domain/entities/monthly_summary.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/shared/utils/merchant_brand_resolver.dart';

/// Computes a [MonthlySummary] from two months of transactions.
///
/// Pure: takes the transaction lists, returns the summary. The caller (bloc)
/// is responsible for fetching the right months; this is where the rules live:
///   - credits count toward received, debits toward spent; unknown direction
///     counts toward neither.
///   - a transaction's category is the Gemini word stored on it when present,
///     otherwise the normalized merchant-brand category (one vocabulary).
///   - % change is only meaningful when the prior month actually had spend.
class ComputeMonthlySummary {
  MonthlySummary call({
    required List<Transaction> monthTransactions,
    required List<Transaction> priorMonthTransactions,
    required int month,
    required int year,
  }) {
    final received = _sumByDirection(monthTransactions, 'credit');
    final spent = _sumByDirection(monthTransactions, 'debit');
    final priorReceived = _sumByDirection(priorMonthTransactions, 'credit');
    final priorSpent = _sumByDirection(priorMonthTransactions, 'debit');

    final currentByCategory = _spendByCategory(monthTransactions);
    final priorByCategory = _spendByCategory(priorMonthTransactions);

    final categories = <CategorySpend>[];
    currentByCategory.forEach((category, amount) {
      final prior = priorByCategory[category];
      categories.add(CategorySpend(
        category: category,
        amount: amount,
        priorAmount: prior,
        changePercent: _changePercent(amount, prior),
      ));
    });
    categories.sort((a, b) => b.amount.compareTo(a.amount));

    return MonthlySummary(
      month: month,
      year: year,
      received: received,
      spent: spent,
      saved: received - spent,
      priorReceived: priorReceived,
      priorSpent: priorSpent,
      priorSaved: priorReceived - priorSpent,
      categories: categories,
    );
  }

  double _sumByDirection(List<Transaction> transactions, String direction) {
    return transactions
        .where((tx) => tx.direction == direction)
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  Map<String, double> _spendByCategory(List<Transaction> transactions) {
    final byCategory = <String, double>{};
    for (final tx in transactions) {
      if (tx.direction != 'debit') continue;
      final category = _categoryFor(tx);
      byCategory[category] = (byCategory[category] ?? 0) + tx.amount;
    }
    return byCategory;
  }

  /// Payment modes that are *not* spending categories. Gemini sometimes
  /// answers "UPI" or "NEFT" to a categorization prompt, which would make
  /// "UPI" the biggest expense — filter those out and fall back to the
  /// merchant-derived category.
  static const _paymentModes = {
    'upi', 'neft', 'imps', 'atm', 'card', 'bank', 'transfer', 'transfers',
    'fine', 'payment', 'debit', 'withdrawal',
  };

  /// Gemini word when stored, else the normalized merchant-brand category —
  /// both speak the same single-word vocabulary. Payment-mode words are never
  /// categories.
  String _categoryFor(Transaction tx) {
    final gemini = tx.category?.trim();
    if (gemini != null &&
        gemini.isNotEmpty &&
        !_paymentModes.contains(gemini.toLowerCase())) {
      return gemini;
    }
    return MerchantBrandResolver.categoryOf(
      tx.recipientName ?? '',
      tx.labelType,
      tx.direction,
    );
  }

  double? _changePercent(double current, double? prior) {
    if (prior == null || prior <= 0) return null;
    return ((current - prior) / prior) * 100;
  }
}
