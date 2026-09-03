import 'package:rozz/features/statement_upload/domain/entities/statement_row.dart';

/// Parses raw statement text (extracted from an HDFC eStatement PDF or pasted
/// from any source) into [StatementRow]s.
///
/// Layout reality: PDF text extraction flattens the table (Date | Narration |
/// Chq/Ref | Value Date | Withdrawal | Deposit | Closing Balance), so a row is
/// a date-led group of text lines, and the money lives in trailing decimal
/// numbers. Direction/ref/VPA come from the narration anatomy itself:
///
///   UPI-DR-`<vpa>`-`<12-digit UPI-TRN>`-`<user's GPay note>`
///   NEFT-CR-HDFC0000123-`<16-char UTR>`-`<counterparty>`
///   IMPS-DR-..., CHQ 123456 ..., NACH-`<UMRN>`...
///
/// Rows that cannot be confidently parsed are kept with [StatementRow.unparsed]
/// == true (surfaced in the summary, never silently dropped).
class StatementRowParser {
  static final _dateRe = RegExp(
    r'^\s*(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b',
  );
  static final _amountRe = RegExp(r'\b[\d,]+\.\d{2}\b');
  // 12-digit UPI-TRN / NPCI refs.
  static final _refRe = RegExp(r'\b(\d{12})\b');
  // Letter-led 16-char NEFT UTRs / longer RTGS refs like "N027261234567890".
  static final _utrRe = RegExp(r'\b([A-Z][A-Z0-9]{15,21})\b');

  /// Lines that never start a statement row.
  static final _junkRe = RegExp(
    r'^(page\b|date\b|narration\b|statement\b|account\b|customer\b|'
    r'opening\b|closing\b|balance\b|total\b|transaction\b|'
    r'withdrawal\b|deposit\b|value\b|chq\b|ref\b|e-statement\b|'
    r'transaction details|summary of|\bcash back\b|\bfees\b|\btaxes\b)',
    caseSensitive: false,
  );

  List<StatementRow> parse(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final groups = <List<String>>[];
    for (final line in lines) {
      if (_junkRe.hasMatch(line) && !_dateRe.hasMatch(line)) {
        // Keep footer-style continuation lines that belong to the current row
        // (they don't start with a date but aren't headers either) out of it;
        // headers only appear at page tops where no row is open.
        if (groups.isNotEmpty &&
            !line.contains(':') &&
            line.split(RegExp(r'\s+')).length > 1) {
          groups.last.add(line);
        }
        continue;
      }
      if (_dateRe.hasMatch(line)) {
        groups.add([line]);
      } else if (groups.isNotEmpty) {
        // Wrapped narration continuation.
        groups.last.add(line);
      }
    }

    return groups.map(_parseGroup).toList();
  }

  StatementRow _parseGroup(List<String> lines) {
    final first = lines.first;
    final dateMatch = _dateRe.firstMatch(first);
    final raw = lines.join(' ');

    final date = _toIsoDate(dateMatch!);
    final amounts = _amountRe.allMatches(raw).map((m) => _amount(m.group(0)!)).toList();
    // Text extraction keeps the amount columns right after the narration —
    // strip them so payee/note tails don't trip over trailing numbers.
    final stripped =
        raw.replaceAll(_amountRe, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    final markerDr = _hasWord(raw, ['dr', 'debit', 'debited', 'payment to', 'paid to']);
    final markerCr = _hasWord(raw, ['cr', 'credit', 'credited', 'received from', 'deposited']);
    final markerUpis = _hasWord(raw, ['upi']);
    final markerNefTs = _hasWord(raw, ['neft']);
    final markerImps = _hasWord(raw, ['imps']);
    final markerRtgs = _hasWord(raw, ['rtgs']);
    final markerAtm = _hasWord(raw, ['atm', 'cash withdrawal']);
    final markerCard = _hasWord(raw, ['pos', 'card', 'swipe']);
    final markerFine = _hasWord(raw, ['non-maintenance', 'average balance', 'mab', 'charges', 'penalty']);

    String? direction;
    if (markerDr && !markerCr) direction = 'debit';
    if (markerCr && !markerDr) direction = 'credit';
    // UPI rows that carry no explicit DR/CR but have a withdrawal amount first.
    if (direction == null && amounts.length >= 2) {
      direction = 'unknown';
    }

    String labelType;
    if (markerAtm) {
      labelType = 'atm';
    } else if (markerFine) {
      labelType = 'fine';
    } else if (markerCard) {
      labelType = 'card';
    } else if (markerUpis) {
      labelType = 'upi';
    } else if (markerNefTs) {
      labelType = 'neft';
    } else if (markerImps) {
      labelType = 'imps';
    } else if (markerRtgs) {
      labelType = 'rtgs';
    } else {
      labelType = 'statement';
    }

    double? amount;
    double? balance = amounts.isEmpty ? null : amounts.last;
    if (amounts.length == 1) {
      amount = amounts.first;
    } else if (amounts.length >= 2) {
      final money = amounts.sublist(0, amounts.length - 1);
      if (markerCr) {
        // Credit rows: withdrawal column is empty ('0.00' or absent) — the
        // amount is the last non-zero before the balance.
        amount = money.reversed.firstWhere((v) => v > 0, orElse: () => 0);
      } else {
        amount = money.first;
      }
    }

    final vpa = _extractVpa(raw);

    // Reference: prefer the pattern immediately after the VPA / after UPI-xxx.
    final ref = _extractRef(raw, vpa);

    final payee = _extractPayee(stripped, vpa, ref);
    final note = _extractNote(stripped, vpa, ref);

    final unparsed = date == null ||
        amount == null ||
        amount <= 0 ||
        direction == null ||
        direction == 'unknown';

    return StatementRow(
      date: date ?? '',
      narration: raw,
      ref: ref,
      vpa: vpa,
      amount: amount ?? 0,
      direction: direction ?? 'unknown',
      balanceAfter: balance,
      payee: payee,
      note: note,
      labelType: labelType,
      unparsed: unparsed,
    );
  }

  /// Direction tokens like "DR"/"CR" appear glued to prefixes
  /// ("UPI-DR-...", "NEFT-CR/...") — match them anywhere as words.
  static bool _hasWord(String text, List<String> words) {
    final lower = text.toLowerCase();
    for (final w in words) {
      final escaped = RegExp.escape(w);
      if (RegExp('(^|[^a-z])$escaped(\$|[^a-z])').hasMatch(lower)) return true;
    }
    return false;
  }

  /// Extracts the VPA from a narration.
  ///
  /// Fast path: the VPA directly after the "UPI-DR-" / "UPI-CR-" / slash
  /// markers ("UPI-DR-swiggy@ybl-…" → "swiggy@ybl"). A plain backward walk
  /// from '@' can't do this: '-' is a legal VPA local-part character, so it
  /// crosses the prefix and returns "UPI-DR-swiggy@ybl".
  ///
  /// Fallback: any VPA-looking token at a word boundary ("to x@ybl via UPI").
  static String? _extractVpa(String text) {
    final marker = RegExp(
      r'(?:UPI[-/](?:DR|CR)[-/])([A-Za-z0-9._-]+@[A-Za-z0-9.]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (marker != null) return marker.group(1);
    return RegExp(r'\b([A-Za-z0-9._-]+@[A-Za-z0-9.]+)\b').firstMatch(text)?.group(1);
  }

  static String? _extractRef(String raw, String? vpa) {
    // UPI-TRN directly follows the VPA segment in HDFC narrations.
    if (vpa != null) {
      final afterVpa = raw.substring(raw.toLowerCase().indexOf(vpa.toLowerCase()) + vpa.length);
      final m = RegExp(r'[\-/_,;:\s](\d{10,12})').firstMatch(afterVpa);
      if (m != null) return m.group(1);
    }
    // NEFT/RTGS/IMPS/NACH: the 16-22 char UTR/ref token.
    final utr = _utrRe.firstMatch(raw);
    if (utr != null) return utr.group(1);
    final ref = _refRe.firstMatch(raw);
    if (ref != null) return ref.group(1);
    return null;
  }

  static String? _extractPayee(String raw, String? vpa, String? ref) {
    var rest = raw;
    if (vpa != null) {
      final idx = raw.toLowerCase().indexOf(vpa.toLowerCase());
      if (idx >= 0) rest = raw.substring(idx + vpa.length);
    }
    if (ref != null) {
      final idx = rest.indexOf(ref);
      if (idx >= 0) rest = rest.substring(idx + ref.length);
    }
    // Remove leftover prefix tokens, numbers and separators; take the first
    // meaningful word run.
    final cleaned = rest
        .replaceAll(RegExp(r'[0-9]+[.,]?[0-9]*'), ' ')
        .replaceAll(RegExp(r'[/\-_,;:()]'), ' ')
        .replaceAll(RegExp(r'\b(upi|dr|cr|neft|imps|rtgs|nach|chq|ref|msg|to|from)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return null;
    final words = cleaned.split(' ');
    // A one-or-two word name is our best payee guess; longer trailing strings
    // are usually the user's note, not the payee.
    return words.take(2).join(' ');
  }

  /// The user-authored GPay note rides at the end of a UPI narration after the
  /// ref. Keep it only when it looks like human words, not bank noise. [raw]
  /// must already have its trailing amount columns stripped.
  static String? _extractNote(String raw, String? vpa, String? ref) {
    if (vpa == null || ref == null) return null;
    final refIdx = raw.lastIndexOf(ref);
    if (refIdx < 0) return null;
    var tail = raw.substring(refIdx + ref.length);
    tail = tail.replaceAll(RegExp(r'[/\-_:;,.]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    tail = tail
        .replaceAll(RegExp(r'\b(upi|dr|cr|ref|msg)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (tail.isEmpty || tail.length > 60) return null;
    if (RegExp(r'\d').hasMatch(tail)) return null;
    return tail;
  }

  String? _toIsoDate(RegExpMatch m) {
    final day = int.tryParse(m.group(1)!);
    final month = int.tryParse(m.group(2)!);
    var year = int.tryParse(m.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (day < 1 || day > 31 || month < 1 || month > 12) return null;
    if (year < 100) year += 2000;
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  static double _amount(String raw) =>
      double.parse(raw.replaceAll(',', '').replaceAll(RegExp(r'[^\d.]'), ''));
}
