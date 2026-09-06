import 'package:flutter_test/flutter_test.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/features/transactions/domain/usecases/compute_current_balance.dart';

Transaction _tx(String date, double amount, String direction) => Transaction(
      date: date,
      amount: amount,
      direction: direction,
      labelType: 'upi_debit',
      source: 'sms',
    );

void main() {
  const engine = ComputeCurrentBalance();

  group('ComputeCurrentBalance — instant precision (the ₹1,440-vs-₹500 bug)', () {
    test('same-day spends AFTER an "Avl bal" SMS anchor DO apply', () {
      // THE user-reported bug: anchor SMS at 10:00 said ₹1,000; two same-day
      // spends at 14:00 and 16:00 were ignored under day-granularity, so the
      // app showed ₹1,000 while the real balance was ₹710.
      final result = engine.compute(
        transactions: [
          _tx('2026-09-06T10:00:00.000', 1000, 'credit'), // balance-setting SMS (has balance_after in real data)
          _tx('2026-09-06T14:00:00.000', 150, 'debit'),
          _tx('2026-09-06T16:00:00.000', 140, 'debit'),
        ],
        anchors: const [BalanceAnchor(date: '2026-09-06T10:00:00.000', balance: 1000)],
      );

      expect(result.value, closeTo(710, 0.001));
      expect(result.replayedTransactions, 2);
    });

    test('same-day transactions BEFORE the anchor instant are skipped', () {
      // The anchor SMS at 18:00 already includes the morning's spends — the
      // bank computed ₹900 knowing about them. Replaying them would subtract
      // twice.
      final result = engine.compute(
        transactions: [
          _tx('2026-09-06T09:00:00.000', 100, 'debit'),
          _tx('2026-09-06T18:00:00.000', 50, 'debit'), // the anchor SMS itself
        ],
        anchors: const [BalanceAnchor(date: '2026-09-06T18:00:00.000', balance: 900)],
      );

      expect(result.value, closeTo(900, 0.001));
      expect(result.replayedTransactions, 0);
    });

    test('a day-precision snapshot counts as END of that day', () {
      // mab_history rows are closing balances: a same-day spend at any hour
      // happened before the bank computed the day's closing number.
      final result = engine.compute(
        transactions: [
          _tx('2026-08-14T18:30:00.000', 200, 'debit'),
        ],
        anchors: const [BalanceAnchor(date: '2026-08-14', balance: 1000)],
      );

      expect(result.value, closeTo(1000, 0.001));
      expect(result.replayedTransactions, 0);
    });

    test('next-day transactions replay on top of a day snapshot', () {
      final result = engine.compute(
        transactions: [
          _tx('2026-08-15T08:00:00.000', 400, 'debit'),
          _tx('2026-08-15T20:00:00.000', 100, 'credit'),
        ],
        anchors: const [BalanceAnchor(date: '2026-08-14', balance: 1000)],
      );

      expect(result.value, closeTo(700, 0.001));
      expect(result.replayedTransactions, 2);
    });

    test('newer timestamp anchor wins over newer-numbered older anchor', () {
      final result = engine.compute(
        transactions: [
          _tx('2026-09-06T21:00:00.000', 60, 'debit'),
        ],
        anchors: const [
          BalanceAnchor(date: '2026-09-05', balance: 5000),
          BalanceAnchor(date: '2026-09-06T20:00:00.000', balance: 480),
        ],
      );

      expect(result.value, closeTo(420, 0.001));
      expect(result.anchoredOn, '2026-09-06');
    });
  });

  group('ComputeCurrentBalance — the made-up-balance regression', () {
    test('NO anchor -> unknown, never a sum-from-zero fiction', () {
      // The exact bug: ledger starts where capture started (unknown opening
      // balance). Old logic summed credits-debits from ₹0 and presented it
      // as the bank balance.
      final result = engine.compute(
        transactions: [
          _tx('2026-08-01T10:00:00.000', 500, 'credit'),
          _tx('2026-08-02T10:00:00.000', 200, 'debit'),
        ],
        anchors: const [],
      );

      expect(result.confidence, BalanceConfidence.unknown);
      expect(result.value, isNull);
      expect(result.anchoredOn, isNull);
    });

    test('anchor + replay: newest bank balance plus post-anchor deltas', () {
      final result = engine.compute(
        transactions: [
          _tx('2026-08-10T10:00:00.000', 300, 'credit'), // after anchor
          _tx('2026-08-11T10:00:00.000', 120.5, 'debit'), // after anchor
          _tx('2026-08-01T10:00:00.000', 9000, 'credit'), // pre-anchor history
        ],
        anchors: const [BalanceAnchor(date: '2026-08-09', balance: 1000)],
      );

      expect(result.confidence, BalanceConfidence.bankVerified);
      expect(result.value, closeTo(1000 + 300 - 120.5, 0.001));
      expect(result.anchoredOn, '2026-08-09');
      expect(result.replayedTransactions, 2);
    });

    test('picks the NEWEST anchor, not the first', () {
      final result = engine.compute(
        transactions: [
          _tx('2026-08-20T10:00:00.000', 50, 'debit'),
        ],
        anchors: const [
          BalanceAnchor(date: '2026-08-05', balance: 5000),
          BalanceAnchor(date: '2026-08-18', balance: 4200),
        ],
      );

      expect(result.value, closeTo(4150, 0.001));
      expect(result.anchoredOn, '2026-08-18');
    });

    test('same-day transactions do NOT double-apply on a same-day anchor', () {
      // The anchor is the balance AT that date (post-state as the bank
      // reported it); deltas apply only strictly after the anchor day.
      final result = engine.compute(
        transactions: [
          _tx('2026-08-18T09:00:00.000', 100, 'debit'),
          _tx('2026-08-18T18:00:00.000', 200, 'credit'),
          _tx('2026-08-19T09:00:00.000', 75, 'debit'),
        ],
        anchors: const [BalanceAnchor(date: '2026-08-18', balance: 1000)],
      );

      // Only the 19th's debit is replayed on top of the anchor.
      expect(result.value, closeTo(925, 0.001));
      expect(result.replayedTransactions, 1);
    });

    test('new transactions after the anchor keep the balance live', () {
      // The user's ask: "every time a new payment comes in or is deducted,
      // the balance keeps updating." Each new SMS lands after the anchor and
      // moves the number — no anchor needed for the new SMS itself.
      final before = engine.compute(
        transactions: [_tx('2026-08-20T10:00:00.000', 100, 'debit')],
        anchors: const [BalanceAnchor(date: '2026-08-18', balance: 2000)],
      );
      final after = engine.compute(
        transactions: [
          _tx('2026-08-20T10:00:00.000', 100, 'debit'),
          _tx('2026-08-21T09:00:00.000', 500, 'credit'),
          _tx('2026-08-21T11:00:00.000', 250, 'debit'),
        ],
        anchors: const [BalanceAnchor(date: '2026-08-18', balance: 2000)],
      );

      expect(before.value, closeTo(1900, 0.001));
      expect(after.value, closeTo(1900 + 500 - 250, 0.001));
    });

    test('an anchor newer than every transaction simply IS the balance', () {
      // Daily balance-advice SMS: the bank states the EOD balance; no
      // transactions after it — that stated number is current.
      final result = engine.compute(
        transactions: [_tx('2026-08-01T10:00:00.000', 300, 'debit')],
        anchors: const [BalanceAnchor(date: '2026-08-31', balance: 7777)],
      );

      expect(result.value, closeTo(7777, 0.001));
      expect(result.replayedTransactions, 0);
    });

    test('empty ledger and no anchors -> unknown', () {
      final result = engine.compute(transactions: [], anchors: const []);
      expect(result.confidence, BalanceConfidence.unknown);
      expect(result.value, isNull);
    });
  });
}
