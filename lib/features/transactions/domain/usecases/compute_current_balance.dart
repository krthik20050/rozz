import 'package:rozz/features/transactions/domain/entities/transaction.dart';

/// What the engine can say about the balance it computed.
enum BalanceConfidence {
  /// Anchored on a bank-reported balance and replayed forward — the real
  /// number, current to the minute the ledger is.
  bankVerified,

  /// No bank-reported balance exists anywhere in the ledger. The app cannot
  /// know the real balance, so the UI must not present a number as fact.
  unknown,
}

class ComputedBalance {
  final double? value;

  /// How much of the ledger had to be replayed on top of the anchor. A large
  /// replay over an old anchor means the number has drifted from reality —
  /// the UI can surface that ("as of 3 Aug").
  final int replayedTransactions;

  /// Date (yyyy-MM-dd) of the anchor this number was computed from, when one
  /// exists. Null in [BalanceConfidence.unknown].
  final String? anchoredOn;

  final BalanceConfidence confidence;

  const ComputedBalance({
    required this.value,
    required this.replayedTransactions,
    required this.anchoredOn,
    required this.confidence,
  });

  const ComputedBalance.unknown()
      : value = null,
        replayedTransactions = 0,
        anchoredOn = null,
        confidence = BalanceConfidence.unknown;
}

/// The balance engine.
///
/// The bank balance is NOT the sum of transactions the app happens to have
/// seen — the ledger begins wherever SMS capture began, with an unknown
/// opening balance. Summing from an implicit ₹0 produced a plausible-looking
/// but fictional number (the "made-up bank balance").
///
/// Instead, every bank-reported balance in the ledger is an anchor. The newest
/// anchor is the truth at that moment; every transaction AFTER it (each one
/// came from a real bank SMS with a known amount and direction) moves the
/// number from there:
///
///   balance = anchor + Σ(credits after anchor) − Σ(debits after anchor)
///
/// Transactions before the anchor are history for insights, not balance math.
/// With no anchor at all the balance is [BalanceConfidence.unknown] — the UI
/// shows "—" until a bank SMS lands, instead of inventing a number.
class ComputeCurrentBalance {
  const ComputeCurrentBalance();

  /// [anchors] are the bank-reported balances, newest-first-ready: each entry
  /// is (date, balance). Transactions may be in any order — they're sorted
  /// internally. Dates are ISO-8601 strings matching the ledger format.
  ComputedBalance compute({
    required List<Transaction> transactions,
    required List<BalanceAnchor> anchors,
  }) {
    if (transactions.isEmpty && anchors.isEmpty) {
      return const ComputedBalance.unknown();
    }

    final sorted = [...transactions]..sort(_byDateAsc);
    final sortedAnchors = [...anchors]..sort(_anchorByDateAsc);

    // Newest anchor overall (even one inside/outside the transaction window
    // is usable — it is the bank telling us the balance at that date).
    if (sortedAnchors.isEmpty) {
      return const ComputedBalance.unknown();
    }
    final anchor = sortedAnchors.last;

    // Everything strictly after the anchor date moves the number. The anchor
    // itself is the balance AT that date (EOD or "after this transaction"),
    // so a same-date transaction's delta is NOT applied on top of a same-date
    // anchor — the bank already reported the post-state.
    final anchorDay = _day(anchor.date);
    double balance = anchor.balance;
    var replayed = 0;
    for (final tx in sorted) {
      final txDay = _day(tx.date);
      if (txDay.compareTo(anchorDay) > 0) {
        balance += tx.direction == 'credit' ? tx.amount : -tx.amount;
        replayed++;
      }
    }

    return ComputedBalance(
      value: balance,
      replayedTransactions: replayed,
      anchoredOn: anchor.date,
      confidence: BalanceConfidence.bankVerified,
    );
  }

  static int _byDateAsc(Transaction a, Transaction b) =>
      a.date.compareTo(b.date);

  static int _anchorByDateAsc(BalanceAnchor a, BalanceAnchor b) =>
      a.date.compareTo(b.date);

  /// Ledger dates are ISO strings that may carry a time component; anchors
  /// are yyyy-MM-dd. Comparing at day granularity avoids substring length
  /// pitfalls and matches how mab_history rows are keyed.
  static String _day(String isoDate) =>
      isoDate.length >= 10 ? isoDate.substring(0, 10) : isoDate;
}

/// One bank-reported balance: the day it was reported and the balance the
/// bank stated. Both sources in the ledger qualify:
///  - a transaction SMS with "Avl bal ₹X" → [Transaction.balanceAfter]
///  - HDFC's daily balance advice → mab_history.end_of_day_balance
class BalanceAnchor {
  final String date;
  final double balance;

  const BalanceAnchor({required this.date, required this.balance});
}
