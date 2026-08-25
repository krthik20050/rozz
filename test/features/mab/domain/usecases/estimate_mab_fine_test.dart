import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/features/mab/domain/usecases/estimate_mab_fine.dart';

void main() {
  final estimate = EstimateMabFine();

  test('no fine when the MAB meets the required minimum', () {
    final result = estimate.call(mab: 7000, requiredMin: 5000);
    expect(result.hasShortfall, isFalse);
    expect(result.fine, 0);
    expect(result.shortfall, 0);
  });

  test('no fine when the MAB exactly equals the required minimum', () {
    final result = estimate.call(mab: 5000, requiredMin: 5000);
    expect(result.hasShortfall, isFalse);
    expect(result.fine, 0);
  });

  test('fine is 6% of the shortfall', () {
    // MAB 3,000 vs 5,000 required = 40% shortfall → 6% of 2,000 = 120.
    final result = estimate.call(mab: 3000, requiredMin: 5000);
    expect(result.hasShortfall, isTrue);
    expect(result.shortfall, 2000);
    expect(result.shortfallPercent, closeTo(40, 0.01));
    expect(result.fine, closeTo(120, 0.01));
  });

  test('fine grows with the shortfall', () {
    // 6% of 3,500 = 210.
    final result = estimate.call(mab: 1500, requiredMin: 5000);
    expect(result.fine, closeTo(210, 0.01));
  });

  test('fine caps at the metro/urban cap', () {
    // 6% of 5,000 = 300 → under the ₹600 metro cap.
    final zero = estimate.call(mab: 0, requiredMin: 5000);
    expect(zero.shortfallPercent, 100);
    expect(zero.fine, 300);

    // 6% of 15,000 = 900 → capped at ₹600.
    final capped = estimate.call(mab: 0, requiredMin: 15000);
    expect(capped.fine, 600);
  });

  test('semi-urban/rural accounts cap at ₹300', () {
    final semi = EstimateMabFine(maxFine: EstimateMabFine.semiRuralCap);
    // 6% of 5,000 = 300 → exactly the cap.
    expect(semi.call(mab: 0, requiredMin: 5000).fine, 300);
    // 6% of 15,000 = 900 → capped at ₹300.
    expect(semi.call(mab: 0, requiredMin: 15000).fine, 300);
  });
}