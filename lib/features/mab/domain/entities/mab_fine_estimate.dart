/// The likely MAB non-maintenance fine for a month, derived from the month's
/// average balance vs the account's required minimum.
class MabFineEstimate {
  /// Monthly average balance actually achieved.
  final double mab;

  /// The account's required minimum balance (e.g. ₹5,000/month).
  final double requiredMin;

  /// Shortfall = required − achieved, zero when the MAB is met.
  final double shortfall;

  /// Shortfall as a percentage of the required minimum (0–100).
  final double shortfallPercent;

  /// The fine amount (0 when the MAB is met). Base amount — banks add GST
  /// (18%) on top.
  final double fine;

  final bool hasShortfall;

  const MabFineEstimate({
    required this.mab,
    required this.requiredMin,
    required this.shortfall,
    required this.shortfallPercent,
    required this.fine,
    required this.hasShortfall,
  });
}
