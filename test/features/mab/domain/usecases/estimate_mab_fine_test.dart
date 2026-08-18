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

  test('shortfall up to 50% → ₹600', () {
    // MAB 3,000 vs 5,000 required = 40% shortfall.
    final result = estimate.call(mab: 3000, requiredMin: 5000);
    expect(result.hasShortfall, isTrue);
    expect(result.shortfall, 2000);
    expect(result.shortfallPercent, closeTo(40, 0.01));
    expect(result.fine, 600);
  });

  test('shortfall between 50% and 75% → ₹750', () {
    // MAB 1,500 vs 5,000 required = 70% shortfall.
    final result = estimate.call(mab: 1500, requiredMin: 5000);
    expect(result.fine, 750);
  });

  test('shortfall above 75% → ₹1,200', () {
    // MAB 500 vs 5,000 required = 90% shortfall.
    final result = estimate.call(mab: 500, requiredMin: 5000);
    expect(result.fine, 1200);
  });

  test('full shortfall (zero balance) → ₹1,200', () {
    final result = estimate.call(mab: 0, requiredMin: 5000);
    expect(result.shortfallPercent, 100);
    expect(result.fine, 1200);
  });
}
