import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/features/insights/domain/usecases/compute_recurring_income.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';

void main() {
  const compute = ComputeRecurringIncome();
  final now = DateTime(2026, 8, 16);

  TransactionModel credit({
    required String date,
    required double amount,
    required String from,
  }) {
    return TransactionModel(
      date: date,
      amount: amount,
      direction: 'credit',
      labelType: 'upi',
      recipientName: from,
      source: 'sms',
    );
  }

  test('detects a sender who credits most months with a steady amount', () {
    final result = compute(
      transactions: [
        credit(date: '2026-03-05', amount: 2000, from: 'kknair9396@ybl'),
        credit(date: '2026-04-05', amount: 2500, from: 'kknair9396@ybl'),
        credit(date: '2026-05-05', amount: 2100, from: 'kknair9396@ybl'),
        credit(date: '2026-07-05', amount: 2200, from: 'kknair9396@ybl'),
        credit(date: '2026-08-05', amount: 2300, from: 'kknair9396@ybl'),
      ],
      labels: {'kknair9396@ybl': 'papa'},
      contactPhoneToName: const {},
      now: now,
    );

    expect(result, hasLength(1));
    final recurring = result.single;
    expect(recurring.displayName, 'papa');
    expect(recurring.typicalAmount, 2200); // median of the band
    expect(recurring.monthsSeen, 5);
    expect(recurring.arrivedThisMonth, isTrue);
    expect(recurring.paymentsThisMonth, 1);
    expect(recurring.expectedNext, DateTime(2026, 9, 5));
  });

  test('excludes senders with wildly irregular amounts (one-off windfalls)', () {
    final result = compute(
      transactions: [
        credit(date: '2026-02-05', amount: 7000, from: '9855343141-2@ybl'),
        credit(date: '2026-04-05', amount: 10500, from: '9855343141-2@ybl'),
        credit(date: '2026-06-05', amount: 5000, from: '9855343141-2@ybl'),
        credit(date: '2026-07-05', amount: 1000, from: '9855343141-2@ybl'),
      ],
      labels: const {},
      contactPhoneToName: const {},
      now: now,
    );

    // ₹10,500 vs ₹1,000 is outside the 1.75× band — not recurring income.
    expect(result, isEmpty);
  });

  test('needs 3+ months before calling something recurring', () {
    final result = compute(
      transactions: [
        credit(date: '2026-07-05', amount: 700, from: 'kavyakarthik1995-1@okaxis'),
        credit(date: '2026-08-05', amount: 700, from: 'kavyakarthik1995-1@okaxis'),
      ],
      labels: const {},
      contactPhoneToName: const {},
      now: now,
    );

    expect(result, isEmpty);
  });

  test('flags when this month has not arrived yet and guesses the next date', () {
    final result = compute(
      transactions: [
        credit(date: '2026-03-20', amount: 1000, from: 'pension@upi'),
        credit(date: '2026-04-20', amount: 1000, from: 'pension@upi'),
        credit(date: '2026-05-20', amount: 1000, from: 'pension@upi'),
        credit(date: '2026-07-20', amount: 1000, from: 'pension@upi'),
      ],
      labels: const {},
      contactPhoneToName: const {},
      now: now,
    );

    expect(result, hasLength(1));
    final recurring = result.single;
    expect(recurring.arrivedThisMonth, isFalse);
    // Last seen 20 Jul → expected around 20 Aug, which is still ahead.
    expect(recurring.expectedNext, DateTime(2026, 8, 20));
  });

  test('resolves a phone-embedded sender via the contact book', () {
    final result = compute(
      transactions: [
        credit(date: '2026-03-10', amount: 700, from: '9855343141-2@ybl'),
        credit(date: '2026-04-10', amount: 700, from: '9855343141-2@ybl'),
        credit(date: '2026-05-10', amount: 700, from: '9855343141-2@ybl'),
        credit(date: '2026-06-10', amount: 700, from: '9855343141-2@ybl'),
        credit(date: '2026-07-10', amount: 700, from: '9855343141-2@ybl'),
      ],
      labels: const {},
      contactPhoneToName: const {'9855343141': 'Jagan'},
      now: now,
    );

    expect(result.single.displayName, 'Jagan');
  });
}
