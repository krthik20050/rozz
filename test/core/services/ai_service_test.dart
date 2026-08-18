import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/core/services/ai_service.dart';
import 'package:rozz/core/security/secure_storage_service.dart';

void main() {
  final service = AiService(SecureStorageService());

  test('redact strips balances, UPI ids, phones, and refs', () {
    const sms = 'Rs.340.00 debited from A/c XX1234 to test@okaxis on 04-03-26. '
        'Ref 421874651243. Avl bal:Rs.42,340.00 Contact 9876543210';
    final out = service.redact(sms);
    expect(out, isNot(contains('42,340')));
    expect(out, isNot(contains('test@okaxis')));
    expect(out, isNot(contains('421874651243')));
    expect(out, isNot(contains('9876543210')));
    expect(out, contains('[balance]'));
  });

  test('redact keeps the amount (needed for categorization)', () {
    const sms = 'Rs.340.00 debited from A/c XX1234 to SWIGGY via UPI Ref 421874651243. Avl bal:Rs.42,340.00';
    expect(service.redact(sms), contains('340.00'));
  });

  test('isFinancialQuestion flags money questions', () {
    expect(isFinancialQuestion('how much did i spend on food this month'), isTrue);
    expect(isFinancialQuestion('what is my balance'), isTrue);
    expect(isFinancialQuestion('tell me about my salary and income'), isTrue);
    expect(isFinancialQuestion('any subscriptions or emi coming up'), isTrue);
    expect(isFinancialQuestion('show recent transactions'), isTrue);
  });

  test('isFinancialQuestion leaves general chit-chat alone', () {
    expect(isFinancialQuestion('what is the date today'), isFalse);
    expect(isFinancialQuestion('tell me a joke'), isFalse);
    expect(isFinancialQuestion('who wrote the odyssey'), isFalse);
    expect(isFinancialQuestion('what is 2+2'), isFalse);
  });
}