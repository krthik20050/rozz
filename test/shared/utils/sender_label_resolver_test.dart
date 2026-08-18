import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/shared/utils/sender_label_resolver.dart';

void main() {
  const labels = {
    'tfam9396@ybl': 'papa',
    'tt9396': 'father',
  };

  test('exact key match wins', () {
    expect(resolveSenderLabel('tfam9396@ybl', labels), 'papa');
  });

  test('VPA local-part match applies across PSPs', () {
    expect(resolveSenderLabel('tt9396@okhdfcbank', labels), 'father');
  });

  test('stem match names the same person on other VPAs (tfam → papa)', () {
    expect(resolveSenderLabel('tfam1967@ybl', labels), 'papa');
    expect(resolveSenderLabel('tfam1967@axl', labels), 'papa');
  });

  test('PSP handles are never stems — no label leaks', () {
    expect(resolveSenderLabel('someotherguy@ybl', labels), isNull);
    expect(resolveSenderLabel('random@axl', labels), isNull);
  });

  test('unrelated keys stay unnamed', () {
    expect(resolveSenderLabel('gokulnenmini212@okaxis', labels), isNull);
    expect(resolveSenderLabel('81112222', labels), isNull);
  });

  test('empty labels resolve to null', () {
    expect(resolveSenderLabel('tfam9396@ybl', const {}), isNull);
  });
}
