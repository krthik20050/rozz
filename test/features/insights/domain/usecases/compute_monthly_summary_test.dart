import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/features/insights/domain/usecases/compute_monthly_summary.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';

void main() {
  final compute = ComputeMonthlySummary();

  TransactionModel tx({
    required String date,
    required double amount,
    required String direction,
    String labelType = 'upi',
    String? recipientName,
    String? category,
  }) {
    return TransactionModel(
      date: date,
      amount: amount,
      direction: direction,
      labelType: labelType,
      recipientName: recipientName,
      source: 'sms',
      category: category,
    );
  }

  test('sums received/spent/saved and groups debits by category', () {
    final month = [
      tx(date: '2026-08-01', amount: 340, direction: 'debit', recipientName: 'SWIGGY'),
      tx(date: '2026-08-02', amount: 120, direction: 'debit', recipientName: 'ZOMATO'),
      tx(date: '2026-08-03', amount: 500, direction: 'debit', recipientName: 'NETFLIX'),
      tx(date: '2026-08-04', amount: 600, direction: 'debit', recipientName: 'AMAZON', category: 'Shopping'),
      tx(date: '2026-08-05', amount: 450, direction: 'debit', recipientName: 'UBER INDIA', category: 'Transport'),
      tx(date: '2026-08-06', amount: 45000, direction: 'credit', recipientName: 'EMPLOYER INC'),
      tx(date: '2026-08-07', amount: 200, direction: 'credit', recipientName: 'REFUND'),
    ];
    final prior = [
      tx(date: '2026-07-01', amount: 300, direction: 'debit', recipientName: 'SWIGGY'),
      tx(date: '2026-07-02', amount: 200, direction: 'debit', recipientName: 'UBER INDIA'),
      tx(date: '2026-07-03', amount: 40000, direction: 'credit', recipientName: 'EMPLOYER INC'),
    ];

    final summary = compute(
      monthTransactions: month,
      priorMonthTransactions: prior,
      month: 8,
      year: 2026,
    );

    expect(summary.month, 8);
    expect(summary.year, 2026);
    expect(summary.received, 45200);
    expect(summary.spent, 2010);
    expect(summary.saved, closeTo(43190, 0.001));
    expect(summary.priorReceived, 40000);
    expect(summary.priorSpent, 500);
    expect(summary.priorSaved, closeTo(39500, 0.001));

    // Sorted largest first: Shopping 600, Subscriptions 500, Food 460, Transport 450
    expect(summary.categories.map((c) => c.category).toList(),
        ['Shopping', 'Subscriptions', 'Food', 'Transport']);

    final food = summary.categories.firstWhere((c) => c.category == 'Food');
    expect(food.amount, 460); // SWIGGY + ZOMATO, both resolved to 'Food' via fallback
    expect(food.priorAmount, 300);
    expect(food.changePercent, closeTo(53.33, 0.01));

    final transport = summary.categories.firstWhere((c) => c.category == 'Transport');
    expect(transport.changePercent, closeTo(125.0, 0.01)); // (450-200)/200

    // No prior spend in this category → no % change, just null.
    final shopping = summary.categories.firstWhere((c) => c.category == 'Shopping');
    expect(shopping.priorAmount, isNull);
    expect(shopping.changePercent, isNull);
  });

  test('Gemini category wins over the merchant fallback', () {
    final month = [
      tx(date: '2026-08-01', amount: 340, direction: 'debit', recipientName: 'SWIGGY', category: 'Rent'),
    ];

    final summary = compute(
      monthTransactions: month,
      priorMonthTransactions: const [],
      month: 8,
      year: 2026,
    );

    expect(summary.categories.single.category, 'Rent');
    expect(summary.categories.single.amount, 340);
  });

  test('unknown direction counts toward neither received nor spent', () {
    final month = [
      tx(date: '2026-08-01', amount: 100, direction: 'unknown'),
      tx(date: '2026-08-02', amount: 500, direction: 'debit', recipientName: 'SWIGGY'),
    ];

    final summary = compute(
      monthTransactions: month,
      priorMonthTransactions: const [],
      month: 8,
      year: 2026,
    );

    expect(summary.received, 0);
    expect(summary.spent, 500);
    expect(summary.categories.single.category, 'Food');
  });

  test('empty month yields zero summary with no categories', () {
    final summary = compute(
      monthTransactions: const [],
      priorMonthTransactions: const [],
      month: 8,
      year: 2026,
    );

    expect(summary.received, 0);
    expect(summary.spent, 0);
    expect(summary.saved, 0);
    expect(summary.categories, isEmpty);
  });
}
