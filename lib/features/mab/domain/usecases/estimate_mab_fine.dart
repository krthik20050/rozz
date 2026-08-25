import '../entities/mab_fine_estimate.dart';

/// Estimates the monthly MAB non-maintenance fine from the achieved average
/// balance vs the required minimum.
///
/// Pure and unit-tested. Matches HDFC's published Regular Savings schedule:
/// 6% of the shortfall OR a cap (whichever is lower), with GST charged on top
/// by the bank. The cap is ₹600 (metro/urban) by default; pass ₹300 for
/// semi-urban/rural accounts.
class EstimateMabFine {
  static const double _fineRate = 0.06;

  /// Metro/urban cap from HDFC's service-charges schedule.
  static const double metroCap = 600;

  /// Semi-urban/rural cap (GIGA schedule).
  static const double semiRuralCap = 300;

  final double maxFine;

  const EstimateMabFine({this.maxFine = metroCap});

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
    final fine = (shortfall * _fineRate).clamp(0, maxFine).toDouble();

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