import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/features/transactions/data/datasources/sms_parser.dart';
import '../../../../mock_sms.dart';

void main() {
  final parser = SmsParser();

  test('parses all 50 mock HDFC SMS fixtures', () {
    for (var i = 0; i < mockHdfcSms.length; i++) {
      final fixture = mockHdfcSms[i];
      final result = parser.parse(fixture['body'] as String);

      expect(result, isNotNull, reason: 'fixture ${i + 1} failed to parse');
      expect(result!['amount'], fixture['expectedAmount'], reason: 'fixture ${i + 1} amount mismatch: ${fixture['body']}');
      expect(result['direction'], fixture['expectedDirection'], reason: 'fixture ${i + 1} direction mismatch');
      expect(result['recipient_name'], fixture['expectedRecipient'], reason: 'fixture ${i + 1} recipient mismatch');
      expect(result['upi_ref_number'], fixture['expectedRef'], reason: 'fixture ${i + 1} ref mismatch');
    }
  });

  test('non-transactional SMS returns unknown and no amount', () {
    final result = parser.parse('HDFCBK: Congratulations! You have been pre-approved for a loan.');
    expect(result, isNotNull);
    expect(result!['label_type'], 'unknown');
    expect(result['amount'], isNull);
  });

  test('MAB fine is detected', () {
    final result = parser.parse('Rs.413.00 debited from A/c XX1234 on 01-03-26 for non-maintenance of Average Balance.');
    expect(result!['label_type'], 'fine');
    expect(result['direction'], 'debit');
    expect(result['amount'], 413.0);
  });
}