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

  test('debit mandate SMS extracts the merchant, not the whole SMS', () {
    final result = parser.parse(
      'UPI Mandate:\nSent Rs.139.00\nfrom HDFC Bank A/c 4736\nTo SPOTIFY\n08/08/26\nRef 103819764558\nNot You? Call 18002586161/SMS BLOCK UPI to 7308080808',
    );
    expect(result, isNotNull);
    expect(result!['recipient_name'], 'SPOTIFY');
    expect(result['amount'], 139.0);
    expect(result['direction'], 'debit');
  });

  test('credit SMS extracts the VPA sender, not the own account', () {
    final result = parser.parse(
      'Credit Alert!\nRs.200.00 credited to HDFC Bank A/c XX4736 on 06-08-26 from VPA 918075637374@wahdfcbank (UPI 127493362828)',
    );
    expect(result, isNotNull);
    expect(result!['recipient_name'], '918075637374@wahdfcbank');
    expect(result['direction'], 'credit');
  });

  test('credit SMS keeps the VPA local part intact (kknair9396@ybl)', () {
    final result = parser.parse(
      'Credit Alert!\nRs.1000.00 credited to HDFC Bank A/c XX4736 on 03-08-26 from VPA kknair9396@ybl (UPI 860638380533)',
    );
    expect(result!['recipient_name'], 'kknair9396@ybl');
  });

  test('debit with no named payee leaves recipient null', () {
    final result = parser.parse(
      'Rs.24.00 debited from HDFC Bank A/c XX4736 on 14-08-26. Avl Bal Rs.59.67. Not You? Call 18002586161.',
    );
    expect(result, isNotNull);
    expect(result!['recipient_name'], isNull);
    expect(result['amount'], 24.0);
  });

  test('daily balance advice is a balance snapshot, not a transaction', () {
    final result = parser.parse(
      'Available Bal in HDFC Bank A/c XX4736 as on yesterday:14-AUG-26 is INR 59.67. '
      'Cheques are subject to clearing.For updated A/C Bal dial 18002703333.',
    );
    expect(result, isNotNull);
    expect(result!['label_type'], 'balance_snapshot');
    expect(result['balance'], 59.67);
    expect(result['date'], '2026-08-14');
    expect(result['amount'], isNull);
  });

  test('standard balance advice (no "yesterday") is a snapshot', () {
    final result = parser.parse(
      'Available Bal in A/c XX4736 is INR 59.67 as on 14-AUG-26. '
      'Cheques are subject to clearing.For updated A/C Bal dial 18002703333.',
    );
    expect(result, isNotNull);
    expect(result!['label_type'], 'balance_snapshot');
    expect(result['balance'], 59.67);
    expect(result['date'], '2026-08-14');
    expect(result['amount'], isNull);
  });

  test('balance advice with space instead of colon after "yesterday"', () {
    final result = parser.parse(
      'Available Bal in HDFC Bank A/c XX4736 as on yesterday 14-AUG-26 is INR 59.67.',
    );
    expect(result, isNotNull);
    expect(result!['label_type'], 'balance_snapshot');
    expect(result['balance'], 59.67);
    expect(result['date'], '2026-08-14');
  });
}