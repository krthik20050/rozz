import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/features/statement_upload/data/datasources/statement_row_parser.dart';

void main() {
  final parser = StatementRowParser();

  group('UPI rows', () {
    test('HDFC-style UPI debit with VPA, ref and the user GPay note', () {
      const text = '''
Statement of Account
01-08-2026 UPI-DR-swiggy@ybl-123456789012-for dinner  189.00  3,540.11
''';
      final rows = parser.parse(text);
      expect(rows, hasLength(1));
      final r = rows.single;
      expect(r.date, '2026-08-01');
      expect(r.direction, 'debit');
      expect(r.amount, 189.00);
      expect(r.balanceAfter, 3540.11);
      expect(r.vpa, 'swiggy@ybl');
      expect(r.ref, '123456789012');
      expect(r.note, 'for dinner');
      expect(r.labelType, 'upi');
      expect(r.unparsed, isFalse);
    });

    test('slash-style UPI (ref + payee, no VPA)', () {
      const text = '''
05-08-2026 UPI/DR/819019125918/SWIGGY/UPI  135.00  4,128.86
''';
      final rows = parser.parse(text);
      final r = rows.single;
      expect(r.direction, 'debit');
      expect(r.amount, 135.00);
      expect(r.ref, '819019125918');
      expect(r.labelType, 'upi');
      expect(r.unparsed, isFalse);
    });

    test('UPI credit from a family VPA', () {
      const text = '''
07-08-2026 UPI-CR-father@okhdfcbank-998877665511  5,000.00  8,939.11
''';
      final r = parser.parse(text).single;
      expect(r.direction, 'credit');
      expect(r.amount, 5000.00);
      expect(r.balanceAfter, 8939.11);
      expect(r.vpa, 'father@okhdfcbank');
    });
  });

  group('other instruments', () {
    test('NEFT debit carries its 16-char UTR', () {
      const text = '''
02-08-2026 NEFT-DR-HDFC0000123-N027260812345678-ACME INDUSTRIES PVT  12,000.00  1,039.11
''';
      final r = parser.parse(text).single;
      expect(r.direction, 'debit');
      expect(r.ref, 'N027260812345678');
      expect(r.labelType, 'neft');
      expect(r.amount, 12000.00);
      expect(r.unparsed, isFalse);
    });

    test('ATM + MAB-fine rows map to their labels', () {
      const text = '''
10-08-2026 ATM CASH WITHDRAWAL 3107XX  2,000.00  500.00
15-08-2026 MAB NON-MAINTENANCE CHARGES  354.00  146.00
''';
      final rows = parser.parse(text);
      expect(rows[0].labelType, 'atm');
      expect(rows[1].labelType, 'fine');
    });
  });

  test('wrapped narration lines join the row they belong to', () {
    const text = '''
04-08-2026 UPI-DR-swiggy@ybl-123456789012-orders
 at night  420.00  3,120.11
''';
    final r = parser.parse(text).single;
    expect(r.amount, 420.00);
    expect(r.note, 'orders at night');
  });

  test('headers, page footers and totals never become rows', () {
    const text = '''
Date Narration Chq/Ref Value Dt Withdrawal Amt Deposit Amt Closing Balance
Page 1 of 2
Statement of Account for a/c 4321
01-08-2026 UPI-DR-swiggy@ybl-123456789012-for dinner  189.00  3,540.11
Total Debits 189.00
Closing Balance 3,540.11
''';
    final rows = parser.parse(text);
    expect(rows, hasLength(1));
    expect(rows.single.amount, 189.00);
  });

  test('ambiguous rows surface as unparsed instead of disappearing', () {
    const text = '''
09-08-2026 Some unclear entry without direction  45.00
''';
    final r = parser.parse(text).single;
    expect(r.unparsed, isTrue);
  });
}
