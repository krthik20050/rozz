class SmsParser {
  static final _amountRe = RegExp(r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)');
  static final _debitRe = RegExp(r'\b(?:debited|spent|withdrawn|sent)\b|Payment\s+of', caseSensitive: false);
  static final _creditRe = RegExp(r'\b(?:credited|received)\b', caseSensitive: false);
  static final _accountRe = RegExp(r'a\/?c\b', caseSensitive: false);

  /// Matches "to X" / "from X" / "at X" party mentions, stopping at newlines
  /// and punctuation. The old version used `\s+` inside the capture, which
  /// crosses newlines and swallowed the WHOLE SMS as the recipient name
  /// ("HDFC Bank A/c 4736\nTo SPOTIFY\n08/08/26") — breaking subscriptions
  /// and sender identity. Spaces/tabs only, and the lookahead terminates on
  /// `\n`.
  static final _partyRe = RegExp(
    r'\b(to|from|at)\s+'
    r'(?:VPA\s+)?'
    r'([A-Za-z0-9&@.+\/\-]+?(?:[ \t]+[A-Za-z0-9&@\/\-]+)*?)'
    r'(?=\n|\.|,|(?:\s*\()|(?:\s+(?:via|by|at|ref|upi|imps|neft|from|to)\b)|(?:\s+on\s+\d)|$)',
    caseSensitive: false,
  );
  static final _refRe = RegExp(r'\bRef(?!und)\b\s*:?\s*([A-Za-z0-9]+)');
  static final _balanceRe = RegExp(
    r'\b(?:Avl\s*bal|Bal|balance)\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );
  static final _dateRe = RegExp(r'\bon\s+(\d{1,2})-(\d{1,2})-(\d{2,4})');
  /// HDFC's balance advice formats: "as on yesterday:14-AUG-26", "as on
  /// yesterday 14-AUG-26", "as on 14-AUG-26". Transaction SMS use plain "on"
  /// (dd-mm-yy), never "as on" — the distinction is reliable.
  static final _asOnDateRe = RegExp(
    r'\bas on\s+(?:yesterday\s*:?\s*)?\d{1,2}-[a-z]{3}-\d{2,4}\b',
    caseSensitive: false,
  );

  Map<String, dynamic>? parse(String body) {
    try {
      // Non-transaction alerts: HDFC's daily balance advice ("Available Bal ...
      // as on yesterday ... is INR X") is a balance snapshot, not a transaction.
      // Capture the reported balance so the app's balance stays current.
      final low = body.toLowerCase();
      if (low.startsWith('available bal') ||
          low.contains('gone below minimum limit') ||
          _asOnDateRe.hasMatch(low)) {
        final balMatch = RegExp(
          r'is\s+INR\s*([\d,]+(?:\.\d+)?)',
          caseSensitive: false,
        ).firstMatch(body);
        if (balMatch != null) {
          return {
            'label_type': 'balance_snapshot',
            'balance': _parseAmount(balMatch.group(1)),
            'date': _asOfDate(body),
            'raw_sms': body,
          };
        }
        return null;
      }

      final amountMatch = _amountRe.firstMatch(body);
      if (amountMatch == null) {
        return {'label_type': 'unknown', 'raw_sms': body};
      }

      final direction = _creditRe.hasMatch(body)
          ? 'credit'
          : (_debitRe.hasMatch(body) ? 'debit' : 'unknown');

      final recipientName = _extractParty(body, direction);
      final refMatch = _refRe.firstMatch(body);
      final balanceMatch = _balanceRe.firstMatch(body);
      final dateMatch = _dateRe.firstMatch(body);

      String? date;
      if (dateMatch != null) {
        final day = int.parse(dateMatch.group(1)!);
        final month = int.parse(dateMatch.group(2)!);
        final year = int.parse(dateMatch.group(3)!);
        date = DateTime.utc(year < 100 ? 2000 + year : year, month, day).toIso8601String();
      }

      return {
        'amount': _parseAmount(amountMatch.group(1)),
        'direction': direction,
        'recipient_name': recipientName,
        'upi_ref_number': refMatch?.group(1),
        'balance_after': balanceMatch != null ? _parseAmount(balanceMatch.group(1)) : null,
        'label_type': _labelType(body),
        'date': date,
        'raw_sms': body,
      };
    } catch (_) {
      return {'label_type': 'unknown', 'raw_sms': body};
    }
  }

  /// Direction-aware party extraction. The bank's SMS names the OWN account
  /// first ("credited to HDFC Bank A/c XX4736") — for credits the sender is
  /// the "from" party, for debits the merchant is the "to" party. Own-account
  /// mentions are never the answer.
  static String? _extractParty(String body, String direction) {
    final matches = _partyRe.allMatches(body).toList();
    if (matches.isEmpty) return null;

    final preferred = direction == 'credit' ? 'from' : 'to';
    String? preferredMatch;
    String? anyMatch;
    for (final m in matches) {
      final keyword = m.group(1)!.toLowerCase();
      final candidate = m.group(2)!.trim();
      if (candidate.isEmpty) continue;
      if (candidate.length > 40) continue; // sanity: never swallow a whole SMS
      if (_accountRe.hasMatch(candidate)) continue; // own account, not a party
      anyMatch ??= candidate;
      if (keyword == preferred) {
        preferredMatch ??= candidate;
      }
    }
    return preferredMatch ?? anyMatch;
  }

  /// "as on yesterday:14-AUG-26" / "as on 14-AUG-26" -> 2026-08-14 (the
  /// balance's as-of date).
  static String? _asOfDate(String body) {
    final m = RegExp(
      r'as on\s+(?:yesterday\s*:?\s*)?(\d{1,2})-([A-Za-z]{3})-([0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(body);
    if (m == null) return null;
    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final day = int.parse(m.group(1)!);
    final month = months[m.group(2)!.toLowerCase()];
    final year = int.parse(m.group(3)!);
    if (month == null || day < 1 || day > 31) return null;
    final fullYear = year < 100 ? 2000 + year : year;
    return '${fullYear.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  static double _parseAmount(String? amountStr) {
    if (amountStr == null) return 0;
    return double.parse(amountStr.replaceAll(',', ''));
  }

  String _labelType(String body) {
    final b = body.toLowerCase();
    if (b.contains('upi')) return 'upi';
    if (b.contains('atm')) return 'atm';
    if (b.contains('neft')) return 'neft';
    if (b.contains('imps')) return 'imps';
    if (b.contains('spent') || b.contains('card')) return 'card';
    if (b.contains('average balance') || b.contains('non-maintenance')) return 'fine';
    return 'bank_sms';
  }
}