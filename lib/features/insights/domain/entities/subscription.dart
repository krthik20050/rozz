import 'package:equatable/equatable.dart';

/// A recurring monthly charge detected from transaction history: the same
/// merchant, charged across two or more different months. [amountVaries] is
/// true when the amount moves between a small set of tiers (e.g. Spotify's
/// ₹139/₹199 plans) — still a subscription, but shown as a range.
class Subscription extends Equatable {
  /// Slug-normalized grouping key — the stable identity used to dismiss this
  /// subscription (so "SPOTIFY AB" and "Spotify" share one dismissal).
  final String key;
  final String merchant;
  final double monthlyAmount;
  final int occurrences;
  final DateTime? lastOccurrence;
  final bool amountVaries;
  final double minAmount;
  final double maxAmount;

  const Subscription({
    this.key = '',
    required this.merchant,
    required this.monthlyAmount,
    required this.occurrences,
    this.lastOccurrence,
    this.amountVaries = false,
    this.minAmount = 0,
    this.maxAmount = 0,
  });

  @override
  List<Object?> get props => [
        key,
        merchant,
        monthlyAmount,
        occurrences,
        lastOccurrence,
        amountVaries,
        minAmount,
        maxAmount,
      ];
}
