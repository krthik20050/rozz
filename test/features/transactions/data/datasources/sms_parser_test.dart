import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';

void main() {
  final parser = SmsParser();

  group('HDFC SMS Parser Patterns', () {
    test('Pattern A: UPI Debit', () {
      const sms = "Rs.340.00 debited from A/c XX1234 on 04-03-26 to SWIGGY via UPI Ref 421874651243. Avl bal:Rs.42,340.00";
      final result = parser.parse(sms);
      
      expect(result, isNotNull);
      expect(result!['amount'], 340.0);
      expect(result['direction'], 'debit');
      expect(result['recipient_name'], 'SWIGGY');
      expect(result['upi_ref_number'], '421874651243');
      expect(result['balance_after'], 42340.0);
      expect(result['label_type'], 'upi_debit');
    });

    test('Pattern B: UPI Credit', () {
      const sms = "Rs.1500.00 credited to A/c XX1234 on 04-03-26 via UPI from JOHN. Ref 521874651244. Bal:Rs.43,840.00";
      final result = parser.parse(sms);
      
      expect(result, isNotNull);
      expect(result!['amount'], 1500.0);
      expect(result['direction'], 'credit');
      expect(result['recipient_name'], 'JOHN');
      expect(result['upi_ref_number'], '521874651244');
      expect(result['balance_after'], 43840.0);
      expect(result['label_type'], 'upi_credit');
    });

    test('Pattern C: ATM Withdrawal', () {
      const sms = "Rs.2000.00 withdrawn from A/c XX1234 at ATM on 04-03-26. Avl Bal:Rs.41,840.00";
      final result = parser.parse(sms);
      
      expect(result, isNotNull);
      expect(result!['amount'], 2000.0);
      expect(result['direction'], 'debit');
      expect(result['label_type'], 'atm');
      expect(result['balance_after'], 41840.0);
    });

    test('Pattern D: NEFT Credit', () {
      const sms = "Rs.45000.00 credited to A/c XX1234 on 04-03-26 by NEFT from EMPLOYER. Ref:N042611234. Bal:Rs.86,840.00";
      final result = parser.parse(sms);
      
      expect(result, isNotNull);
      expect(result!['amount'], 45000.0);
      expect(result['direction'], 'credit');
      expect(result['recipient_name'], 'EMPLOYER');
      expect(result['upi_ref_number'], 'N042611234');
      expect(result['balance_after'], 86840.0);
      expect(result['label_type'], 'neft');
    });

    test('Pattern E: MAB Fine', () {
      const sms = "Rs.413.00 debited from A/c XX1234 on 01-03-26 for non-maintenance of Average Balance.";
      final result = parser.parse(sms);
      
      expect(result, isNotNull);
      expect(result!['amount'], 413.0);
      expect(result['direction'], 'debit');
      expect(result['label_type'], 'fine');
    });

    test('Unknown Pattern', () {
      const sms = "Some random SMS from bank that doesn't match our regex exactly.";
      final result = parser.parse(sms);
      
      expect(result, isNotNull);
      expect(result!['label_type'], 'unknown');
      expect(result['raw_sms'], sms);
    });
  });
}
