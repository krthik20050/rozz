/// One transaction row parsed from a bank statement (PDF text or pasted text).
class StatementRow {
  /// Local date of the transaction (dd-mm-yyyy in the statement).
  final String date; // ISO yyyy-mm-dd
  final String narration;

  /// Bank reference when present: 12-digit UPI-TRN / 16-char NEFT UTR / etc.
  final String? ref;

  /// UPI VPA embedded in the narration ("swiggy@ybl") — the strong merchant
  /// identity anchor.
  final String? vpa;

  /// Movement amount (rupees, already parsed).
  final double amount;

  /// 'debit' | 'credit' | 'unknown'.
  final String direction;

  /// Closing balance after this entry, when the statement carries it.
  final double? balanceAfter;

  /// Best-guess payee name from the narration.
  final String? payee;

  /// The trailing segment of a UPI narration after the transaction ref — this
  /// is the note the user typed in Google Pay ("for food"); it seeds the
  /// transaction's user narration.
  final String? note;

  /// Payment-mode label ('upi' | 'neft' | 'imps' | 'card' | 'atm' | 'fine' |
  /// 'statement').
  final String labelType;

  /// True when the row could not be confidently parsed — surfaced in the
  /// upload summary, never silently dropped.
  final bool unparsed;

  const StatementRow({
    required this.date,
    required this.narration,
    this.ref,
    this.vpa,
    required this.amount,
    required this.direction,
    this.balanceAfter,
    this.payee,
    this.note,
    required this.labelType,
    this.unparsed = false,
  });
}
