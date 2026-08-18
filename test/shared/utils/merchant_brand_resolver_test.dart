import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/shared/utils/merchant_brand_resolver.dart';

void main() {
  group('categoryOf — normalized single-word vocabulary', () {
    test('maps known merchants to their category', () {
      expect(MerchantBrandResolver.categoryOf('SWIGGY', 'upi', 'debit'), 'Food');
      expect(MerchantBrandResolver.categoryOf('ZOMATO LMT', 'upi', 'debit'), 'Food');
      expect(MerchantBrandResolver.categoryOf('UBER INDIA', 'upi', 'debit'), 'Transport');
      expect(MerchantBrandResolver.categoryOf('SPOTIFY', 'card', 'debit'), 'Entertainment');
      expect(MerchantBrandResolver.categoryOf('AMAZON', 'upi', 'debit'), 'Shopping');
      expect(MerchantBrandResolver.categoryOf('IRCTC', 'upi', 'debit'), 'Travel');
      expect(MerchantBrandResolver.categoryOf('NETFLIX ENT', 'upi', 'debit'), 'Subscriptions');
    });

    test('credits and salary/deposit narrations are Income', () {
      expect(MerchantBrandResolver.categoryOf('EMPLOYER INC', 'bank_sms', 'credit'), 'Income');
      expect(MerchantBrandResolver.categoryOf('', 'bank_sms', 'credit'), 'Income');
      expect(MerchantBrandResolver.categoryOf('CASH DEPOSIT', 'bank_sms', 'debit'), 'Income');
    });

    test('falls back to label type with single-word names', () {
      expect(MerchantBrandResolver.categoryOf('', 'atm', 'debit'), 'ATM');
      // UPI is a payment mode, never a spending category.
      expect(MerchantBrandResolver.categoryOf('', 'upi', 'debit'), 'Transfers');
      expect(MerchantBrandResolver.categoryOf('', 'neft', 'debit'), 'Bank');
      expect(MerchantBrandResolver.categoryOf('', 'bank_sms', 'debit'), 'Bank');
    });

    test('telecom recharges and insurers get real categories', () {
      expect(MerchantBrandResolver.categoryOf('JIO RECHARGE', 'upi', 'debit'), 'Recharge');
      expect(MerchantBrandResolver.categoryOf('AIRTEL PREPAID', 'upi', 'debit'), 'Recharge');
      expect(MerchantBrandResolver.categoryOf('LIC PREMIUM', 'upi', 'debit'), 'Insurance');
      expect(MerchantBrandResolver.categoryOf('HDFC ERGO', 'upi', 'debit'), 'Insurance');
      final jio = MerchantBrandResolver.resolve('JIO RECHARGE', 'upi', 'debit');
      expect(jio.name, 'Jio');
      expect(jio.category, 'Recharge');
    });

    test('resolve() agrees with categoryOf()', () {
      final brand = MerchantBrandResolver.resolve('SWIGGY', 'upi', 'debit');
      expect(brand.category, MerchantBrandResolver.categoryOf('SWIGGY', 'upi', 'debit'));
    });
  });
}
