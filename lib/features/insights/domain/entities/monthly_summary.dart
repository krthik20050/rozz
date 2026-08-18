import 'package:equatable/equatable.dart';

/// One category's spending within a month, compared with the same category in
/// the prior month. [changePercent] is null when there is nothing to compare
/// against (no prior spend) — callers should show "new" instead of a %.
class CategorySpend extends Equatable {
  final String category;
  final double amount;
  final double? priorAmount;
  final double? changePercent;

  const CategorySpend({
    required this.category,
    required this.amount,
    this.priorAmount,
    this.changePercent,
  });

  @override
  List<Object?> get props => [category, amount, priorAmount, changePercent];
}

/// A computed statement about one month: money in, money out, net saved, and
/// a spend breakdown by category (largest first). Derived from real
/// transactions — never literals.
class MonthlySummary extends Equatable {
  final int month;
  final int year;

  final double received;
  final double spent;
  final double saved;

  final double priorReceived;
  final double priorSpent;
  final double priorSaved;

  /// Debit transactions grouped by category, sorted by amount descending.
  final List<CategorySpend> categories;

  const MonthlySummary({
    required this.month,
    required this.year,
    required this.received,
    required this.spent,
    required this.saved,
    required this.priorReceived,
    required this.priorSpent,
    required this.priorSaved,
    required this.categories,
  });

  @override
  List<Object?> get props => [
        month,
        year,
        received,
        spent,
        saved,
        priorReceived,
        priorSpent,
        priorSaved,
        categories,
      ];
}
