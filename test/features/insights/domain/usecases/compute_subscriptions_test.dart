import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/features/insights/domain/usecases/compute_subscriptions.dart';
import 'package:rozz/features/transactions/data/models/transaction_model.dart';

void main() {
  final compute = ComputeSubscriptions();

  TransactionModel tx({
    required String date,
    required double amount,
    String direction = 'debit',
    String? recipientName,
  }) {
    return TransactionModel(
      date: date,
      amount: amount,
      direction: direction,
      labelType: 'upi',
      recipientName: recipientName,
      source: 'sms',
    );
  }

  test('detects a monthly recurring charge across different months', () {
    final subscriptions = compute(transactions: [
      tx(date: '2026-03-15', amount: 649, recipientName: 'NETFLIX ENT'),
      tx(date: '2026-04-15', amount: 649, recipientName: 'NETFLIX ENT'),
      tx(date: '2026-05-15', amount: 649, recipientName: 'NETFLIX ENT'),
    ]);

    expect(subscriptions, hasLength(1));
    final sub = subscriptions.single;
    // Resolves to the canonical brand name, not the raw SMS spelling.
    expect(sub.merchant, 'Netflix');
    expect(sub.monthlyAmount, 649);
    expect(sub.occurrences, 3);
    expect(sub.lastOccurrence, DateTime(2026, 5, 15));
  });

  test('brand aliases group as one subscription (Spotify / SPOTIFY AB)', () {
    final subscriptions = compute(transactions: [
      tx(date: '2026-03-15', amount: 139, recipientName: 'SPOTIFY AB'),
      tx(date: '2026-04-15', amount: 139, recipientName: 'Spotify'),
    ]);

    expect(subscriptions, hasLength(1));
    expect(subscriptions.single.merchant, 'Spotify');
    expect(subscriptions.single.monthlyAmount, 139);
  });

  test('monthly mobile recharges are detected as subscriptions', () {
    final subscriptions = compute(transactions: [
      tx(date: '2026-03-10', amount: 299, recipientName: 'JIO RECHARGE'),
      tx(date: '2026-04-10', amount: 299, recipientName: 'JIO RECHARGE'),
    ]);

    expect(subscriptions, hasLength(1));
    expect(subscriptions.single.merchant, 'Jio');
    expect(subscriptions.single.monthlyAmount, 299);
  });

  test('amounts within tolerance still count as a subscription', () {
    final subscriptions = compute(transactions: [
      tx(date: '2026-03-15', amount: 649, recipientName: 'SPOTIFY'),
      tx(date: '2026-04-15', amount: 699, recipientName: 'SPOTIFY'), // +7.7%
    ]);

    expect(subscriptions, hasLength(1));
    expect(subscriptions.single.monthlyAmount, 699);
  });

  test('wildly different amounts are not a subscription', () {
    final subscriptions = compute(transactions: [
      tx(date: '2026-03-15', amount: 100, recipientName: 'AMAZON'),
      tx(date: '2026-04-15', amount: 300, recipientName: 'AMAZON'), // +200%
    ]);

    expect(subscriptions, isEmpty);
  });

  test('a single occurrence is not a subscription', () {
    final subscriptions = compute(transactions: [
      tx(date: '2026-04-15', amount: 649, recipientName: 'NETFLIX ENT'),
    ]);

    expect(subscriptions, isEmpty);
  });

  test('two charges in the same month are not a subscription', () {
    final subscriptions = compute(transactions: [
      tx(date: '2026-04-01', amount: 649, recipientName: 'NETFLIX ENT'),
      tx(date: '2026-04-20', amount: 649, recipientName: 'NETFLIX ENT'),
    ]);

    expect(subscriptions, isEmpty);
  });

  test('credits are ignored', () {
    final subscriptions = compute(transactions: [
      tx(date: '2026-03-01', amount: 40000, direction: 'credit', recipientName: 'EMPLOYER INC'),
      tx(date: '2026-04-01', amount: 40000, direction: 'credit', recipientName: 'EMPLOYER INC'),
    ]);

    expect(subscriptions, isEmpty);
  });

  test('variable-amount tiers across 3+ months still count (Spotify 139/199)', () {
    final subscriptions = compute(transactions: [
      tx(date: '2026-03-15', amount: 139, recipientName: 'SPOTIFY'),
      tx(date: '2026-04-15', amount: 199, recipientName: 'SPOTIFY'),
      tx(date: '2026-05-15', amount: 139, recipientName: 'SPOTIFY'),
      tx(date: '2026-06-15', amount: 199, recipientName: 'SPOTIFY'),
    ]);

    expect(subscriptions, hasLength(1));
    final sub = subscriptions.single;
    expect(sub.amountVaries, isTrue);
    expect(sub.minAmount, 139);
    expect(sub.maxAmount, 199);
    expect(sub.monthlyAmount, 199); // most recent
  });

  test('wildly variable recurring spends are not subscriptions', () {
    final subscriptions = compute(transactions: [
      tx(date: '2026-03-15', amount: 100, recipientName: 'AMAZON'),
      tx(date: '2026-04-15', amount: 300, recipientName: 'AMAZON'),
      tx(date: '2026-05-15', amount: 2500, recipientName: 'AMAZON'), // 25x
    ]);

    expect(subscriptions, isEmpty);
  });

  test('dismissed merchants are skipped', () {
    final subscriptions = compute(
      transactions: [
        tx(date: '2026-03-15', amount: 200, recipientName: 'AMIR HUSAIN'),
        tx(date: '2026-04-15', amount: 200, recipientName: 'AMIR HUSAIN'),
        tx(date: '2026-03-15', amount: 649, recipientName: 'NETFLIX ENT'),
        tx(date: '2026-04-15', amount: 649, recipientName: 'NETFLIX ENT'),
      ],
      dismissedKeys: const {'amirhusain'},
    );

    expect(subscriptions, hasLength(1));
    expect(subscriptions.single.merchant, 'Netflix');
  });

  test('sorts by monthly amount descending', () {
    final subscriptions = compute(transactions: [
      tx(date: '2026-03-01', amount: 200, recipientName: 'A'),
      tx(date: '2026-04-01', amount: 200, recipientName: 'A'),
      tx(date: '2026-03-01', amount: 1000, recipientName: 'B'),
      tx(date: '2026-04-01', amount: 1000, recipientName: 'B'),
    ]);

    expect(subscriptions.map((s) => s.merchant).toList(), ['B', 'A']);
  });
}
