import '../entities/mab_fine_estimate.dart';

/// Estimates the monthly MAB non-maintenance fine from the achieved average
/// balance vs the required minimum.
///
/// Pure and unit-tested. Uses the standard HDFC savings-account schedule
/// (metro/urban branches); GST is charged on top by the bank:
///   - shortfall ≤ 50% of required  → ₹600
///   - shortfall 50%–75%            → ₹750
///   - shortfall > 75%              → ₹1,200
class EstimateMabFine {
  static const double _fineUpTo50 = 600;
  static const double _fineUpTo75 = 750;
  static const double _fineAbove75 = 1200;

  MabFineEstimate call({
    required double mab,
    required double requiredMin,
  }) {
    if (requiredMin <= 0 || mab >= requiredMin) {
      return MabFineEstimate(
        mab: mab,
        requiredMin: requiredMin,
        shortfall: 0,
        shortfallPercent: 0,
        fine: 0,
        hasShortfall: false,
      );
    }

    final shortfall = requiredMin - mab;
    final percent = (shortfall / requiredMin) * 100;
    final double fine;
    if (percent <= 50) {
      fine = _fineUpTo50;
    } else if (percent <= 75) {
      fine = _fineUpTo75;
    } else {
      fine = _fineAbove75;
    }

    return MabFineEstimate(
      mab: mab,
      requiredMin: requiredMin,
      shortfall: shortfall,
      shortfallPercent: percent,
      fine: fine,
      hasShortfall: true,
    );
  }
}
