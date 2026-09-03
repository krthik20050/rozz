import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/shared/utils/merchant_key.dart';

void main() {
  group('MerchantKey.slug', () {
    test('lowercases and strips non-alphanumerics', () {
      expect(MerchantKey.slug('SWIGGY'), 'swiggy');
      expect(MerchantKey.slug('Swiggy India'), 'swiggyindia');
      expect(MerchantKey.slug('  RAHUL VERMA!! '), 'rahulverma');
      expect(MerchantKey.slug('big.basket@123'), 'bigbasket123');
      expect(MerchantKey.slug(''), '');
    });
  });

  group('MerchantKey.vpaLocalPart', () {
    test('returns the local part of a VPA', () {
      expect(MerchantKey.vpaLocalPart('swiggy@ybl'), 'swiggy');
      expect(MerchantKey.vpaLocalPart('9898989898@paytm'), '9898989898');
    });
    test('null for missing or malformed VPAs', () {
      expect(MerchantKey.vpaLocalPart(null), isNull);
      expect(MerchantKey.vpaLocalPart(''), isNull);
      expect(MerchantKey.vpaLocalPart('not-a-vpa'), isNull);
    });
  });

  group('MerchantKey.brandCanonicalSlug', () {
    test('resolves aliases of a known brand to the canonical slug', () {
      expect(MerchantKey.brandCanonicalSlug('SPOTIFY AB', 'upi', 'debit'), 'spotify');
      expect(MerchantKey.brandCanonicalSlug('Swiggy India Pvt Ltd', 'upi', 'debit'), 'swiggy');
      expect(MerchantKey.brandCanonicalSlug('AMAZON PAY', 'upi', 'debit'), 'amazon');
    });
    test('null for generic fallbacks and raw names the resolver echoes back', () {
      expect(MerchantKey.brandCanonicalSlug('UPI Transfer', 'upi', 'debit'), isNull);
      expect(MerchantKey.brandCanonicalSlug('', 'upi', 'debit'), isNull);
      expect(MerchantKey.brandCanonicalSlug('Rahul Verma', 'upi', 'debit'), isNull);
    });
  });

  group('MerchantKey.aliasKeysFor', () {
    test('brand slug first; duplicates collapse to one candidate', () {
      final keys = MerchantKey.aliasKeysFor(
        recipientName: 'SWIGGY',
        upiId: 'swiggy@ybl',
        labelType: 'upi',
        direction: 'debit',
      );
      expect(keys, ['swiggy']);
    });
    test('person payee falls back to raw slug + VPA local part', () {
      final keys = MerchantKey.aliasKeysFor(
        recipientName: 'Rahul Verma',
        upiId: 'rahul.v98@okhdfcbank',
        labelType: 'upi',
        direction: 'debit',
      );
      expect(keys, contains('rahulverma'));
      expect(keys, contains('rahulv98'));
    });
  });
}
