import 'package:equatable/equatable.dart';

/// A credit that arrives most months from the same sender — salary, pension,
/// interest, or a regular allowance. Answers: "do I get this every month,
/// how much, and has it landed this month?"
class RecurringIncome extends Equatable {
  /// Normalized sender key (VPA / phone / name), e.g. "kknair9396@ybl".
  final String sender;

  /// Display name after label/contact resolution.
  final String displayName;

  /// Typical monthly amount (median of the months seen).
  final double typicalAmount;

  /// Distinct months with credits from this sender (e.g. 6).
  final int monthsSeen;

  /// Month keys seen, oldest first (e.g. ['2026-03', '2026-04']).
  final List<String> months;

  /// Date of the most recent credit.
  final DateTime lastSeen;

  /// Predicted next arrival (last seen + 1 month, day-clamped). Null when the
  /// cadence is too irregular to guess.
  final DateTime? expectedNext;

  /// Whether a credit from this sender has already landed this month.
  final bool arrivedThisMonth;

  /// Credits from this sender this month.
  final int paymentsThisMonth;

  const RecurringIncome({
    required this.sender,
    required this.displayName,
    required this.typicalAmount,
    required this.monthsSeen,
    required this.months,
    required this.lastSeen,
    required this.expectedNext,
    required this.arrivedThisMonth,
    required this.paymentsThisMonth,
  });

  @override
  List<Object?> get props => [
        sender,
        displayName,
        typicalAmount,
        monthsSeen,
        months,
        lastSeen,
        expectedNext,
        arrivedThisMonth,
        paymentsThisMonth,
      ];
}
