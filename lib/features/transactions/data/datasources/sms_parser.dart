class SmsParser {
  static final _amountRe = RegExp(r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)');
  static final _debitRe = RegExp(r'\b(?:debited|spent|withdrawn|sent)\b|Payment\s+of', caseSensitive: false);
  static final _creditRe = RegExp(r'\b(?:credited|received)\b', caseSensitive: false);
  static final _recipientRe = RegExp(
    r'\b(?:to|from|at)\s+(?!A\/?c\b|a\/?c\b)(?:VPA\s+)?'
    r'([A-Za-z0-9&@.\/\-]+?(?:\s+[A-Za-z0-9&@\/\-]+)*?)'
    r'(?=\.|,|(?:\s+(?:via|by|at|Ref|UPI|IMPS|NEFT|from)\b)|(?:\s+on\s+\d)|$)',
  );
  static final _refRe = RegExp(r'\bRef(?!und)\b\s*:?\s*([A-Za-z0-9]+)');
  static final _balanceRe = RegExp(
    r'\b(?:Avl\s*bal|Bal|balance)\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );
  static final _dateRe = RegExp(r'\bon\s+(\d{1,2})-(\d{1,2})-(\d{2,4})');

  Map<String, dynamic>? parse(String body) {
    try {
      double parseAmount(String? amountStr) {
        if (amountStr == null) return 0;
        return double.parse(amountStr.replaceAll(',', ''));
      }

      final amountMatch = _amountRe.firstMatch(body);
      if (amountMatch == null) {
        return {'label_type': 'unknown', 'raw_sms': body};
      }

      final direction = _creditRe.hasMatch(body)
          ? 'credit'
          : (_debitRe.hasMatch(body) ? 'debit' : 'unknown');

      final recipientMatch = _recipientRe.firstMatch(body);
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
        'amount': parseAmount(amountMatch.group(1)),
        'direction': direction,
        'recipient_name': recipientMatch?.group(1)?.trim(),
        'upi_ref_number': refMatch?.group(1),
        'balance_after': balanceMatch != null ? parseAmount(balanceMatch.group(1)) : null,
        'label_type': _labelType(body),
        'date': date,
        'raw_sms': body,
      };
    } catch (_) {
      return {'label_type': 'unknown', 'raw_sms': body};
    }
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