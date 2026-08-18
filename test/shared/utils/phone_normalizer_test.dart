import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/shared/utils/phone_normalizer.dart';

void main() {
  test('strips formatting and returns the last 10 digits', () {
    expect(lastTenDigits('+91 98765 43210'), '9876543210');
    expect(lastTenDigits('98765-43210'), '9876543210');
  });

  test('handles a full-length number with country code', () {
    // 12 digits → last 10 wins (drops the 91 country code).
    expect(lastTenDigits('919876543210'), '9876543210');
  });

  test('extracts digits from a phone-based VPA', () {
    expect(lastTenDigits('9876543210@ybl'), '9876543210');
    expect(lastTenDigits('91-98765-43210@okhdfcbank'), '9876543210');
  });

  test('returns null when there are not enough digits', () {
    expect(lastTenDigits('kk9396'), isNull);
    expect(lastTenDigits(null), isNull);
    expect(lastTenDigits('abc'), isNull);
  });
}
