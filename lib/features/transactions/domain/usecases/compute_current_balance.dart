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

    // Everything strictly AFTER the anchor moment moves the number. The
    // anchor's instant is derived from its own precision: a transaction-SMS
    // or statement anchor is exact to the second (the bank computed that
    // balance at that instant); a day-precision anchor (mab_history) is the
    // day's CLOSING balance, so it counts as end-of-day.
    //
    // Why instant precision matters: same-day spends after an "Avl bal" SMS
    // are real money out. Day-granularity here silently ignored them — the
    // app showed a balance the bank had already debited (the "app says
    // ₹1,440 but my real balance is ₹500" bug).
    final anchorInstant = _instantOf(anchor);
    double balance = anchor.balance;
    var replayed = 0;
    for (final tx in sorted) {
      if (_instantFromIso(tx.date, isEndOfDay: false).compareTo(anchorInstant) > 0) {
        balance += tx.direction == 'credit' ? tx.amount : -tx.amount;
        replayed++;
      }
    }

    return ComputedBalance(
      value: balance,
      replayedTransactions: replayed,
      // Normalized to the day: transaction-SMS anchors carry a full ISO
      // timestamp, snapshot anchors don't — the UI ("as of 18 Aug") and
      // comparisons only care about the day.
      anchoredOn: _day(anchor.date),
      confidence: BalanceConfidence.bankVerified,
    );
  }

  static int _byDateAsc(Transaction a, Transaction b) =>
      a.date.compareTo(b.date);

  static int _anchorByDateAsc(BalanceAnchor a, BalanceAnchor b) =>
      a.date.compareTo(b.date);

  /// The anchor's effective instant: full timestamps are exact; day-precision
  /// anchors (mab_history rows) are the day's closing balance → end of day.
  static DateTime _instantOf(BalanceAnchor anchor) =>
      _instantFromIso(anchor.date, isEndOfDay: !anchor.date.contains('T'));

  /// Parses an ISO date(-time) into a comparable instant. Day-precision input
  /// with [isEndOfDay] maps to 23:59:59.999 of that day (a closing balance);
  /// without it, to midnight (inclusive start). Falls back to day-granularity
  /// string comparison if the format is not parseable — never throws.
  static DateTime _instantFromIso(String iso, {required bool isEndOfDay}) {
    final parsed = DateTime.tryParse(iso);
    if (parsed != null) {
      if (iso.contains('T')) return parsed;
      return isEndOfDay
          ? DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59, 999)
          : DateTime(parsed.year, parsed.month, parsed.day);
    }
    // Unparseable — treat as end-of-day of the date part so a same-day
    // transaction after it still replays (safe direction: never hide spends).
    final day = _day(iso);
    final dayParsed = DateTime.tryParse(day);
    if (dayParsed != null) {
      return DateTime(
          dayParsed.year, dayParsed.month, dayParsed.day, 23, 59, 59, 999);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// The yyyy-MM-dd day part of an ISO date(-time).
  static String _day(String isoDate) =>
      isoDate.length >= 10 ? isoDate.substring(0, 10) : isoDate;
}

/// One bank-reported balance: when it was reported and the balance the bank
/// stated. Both sources in the ledger qualify:
///  - a transaction SMS with "Avl bal ₹X" → [Transaction.balanceAfter]
///    (full ISO timestamp — the moment the bank computed that balance)
///  - HDFC's daily balance advice → mab_history.end_of_day_balance (a
///    yyyy-MM-dd day; treated as the END of that day, since the bank states
///    the day's closing balance)
/// Statement imports (closing balance per row) also land here with their
/// full transaction timestamps — the strongest anchors in the ledger.
class BalanceAnchor {
  final String date;
  final double balance;

  const BalanceAnchor({required this.date, required this.balance});
}
