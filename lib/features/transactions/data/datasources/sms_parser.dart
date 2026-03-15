class SmsParser {
  Map<String, dynamic>? parse(String body) {
    try {
      // Clean amount: Rs.42,340.00 -> 42340.0
      double parseAmount(String amountStr) {
        return double.parse(amountStr.replaceAll(',', ''));
      }

      // Pattern A: UPI Debit
      // Rs.340.00 debited from A/c XX1234 on 04-03-26 to SWIGGY via UPI Ref 421874651243. Avl bal:Rs.42,340.00
      final patternA = RegExp(r'Rs\.([\d,.]+)\s+debited\s+from.*to\s+(.+)\s+via\s+UPI\s+Ref\s+(\d+)\.\s+Avl\s+bal:Rs\.([\d,.]+)');
      if (patternA.hasMatch(body)) {
        final match = patternA.firstMatch(body)!;
        return {
          'amount': parseAmount(match.group(1)!),
          'direction': 'debit',
          'recipient_name': match.group(2)!.trim(),
          'upi_ref_number': match.group(3),
          'balance_after': parseAmount(match.group(4)!),
          'label_type': 'upi_debit',
          'raw_sms': body,
        };
      }

      // Pattern B: UPI Credit
      // Rs.1500.00 credited to A/c XX1234 on 04-03-26 via UPI from JOHN. Ref 521874651244. Bal:Rs.43,840.00
      final patternB = RegExp(r'Rs\.([\d,.]+)\s+credited\s+to.*via\s+UPI\s+from\s+(.+)\.\s+Ref\s+(\d+)\.\s+Bal:Rs\.([\d,.]+)');
      if (patternB.hasMatch(body)) {
        final match = patternB.firstMatch(body)!;
        return {
          'amount': parseAmount(match.group(1)!),
          'direction': 'credit',
          'recipient_name': match.group(2)!.trim(),
          'upi_ref_number': match.group(3),
          'balance_after': parseAmount(match.group(4)!),
          'label_type': 'upi_credit',
          'raw_sms': body,
        };
      }

      // Pattern C: ATM Withdrawal
      // Rs.2000.00 withdrawn from A/c XX1234 at ATM on 04-03-26. Avl Bal:Rs.41,840.00
      final patternC = RegExp(r'Rs\.([\d,.]+)\s+withdrawn\s+from.*at\s+ATM.*Avl\s+Bal:Rs\.([\d,.]+)');
      if (patternC.hasMatch(body)) {
        final match = patternC.firstMatch(body)!;
        return {
          'amount': parseAmount(match.group(1)!),
          'direction': 'debit',
          'label_type': 'atm',
          'balance_after': parseAmount(match.group(2)!),
          'raw_sms': body,
        };
      }

      // Pattern D: NEFT Credit
      // Rs.45000.00 credited to A/c XX1234 on 04-03-26 by NEFT from EMPLOYER. Ref:N042611234. Bal:Rs.86,840.00
      final patternD = RegExp(r'Rs\.([\d,.]+)\s+credited\s+to.*by\s+NEFT\s+from\s+(.+)\.\s+Ref:(.+)\.\s+Bal:Rs\.([\d,.]+)');
      if (patternD.hasMatch(body)) {
        final match = patternD.firstMatch(body)!;
        return {
          'amount': parseAmount(match.group(1)!),
          'direction': 'credit',
          'recipient_name': match.group(2)!.trim(),
          'upi_ref_number': match.group(3)!.trim(),
          'balance_after': parseAmount(match.group(4)!),
          'label_type': 'neft',
          'raw_sms': body,
        };
      }

      // Pattern E: MAB Fine
      // Rs.413.00 debited from A/c XX1234 on 01-03-26 for non-maintenance of Average Balance.
      final patternE = RegExp(r'Rs\.([\d,.]+)\s+debited\s+from.*non-maintenance\s+of\s+Average\s+Balance');
      if (patternE.hasMatch(body)) {
        final match = patternE.firstMatch(body)!;
        return {
          'amount': parseAmount(match.group(1)!),
          'direction': 'debit',
          'label_type': 'fine',
          'raw_sms': body,
        };
      }

      // Unknown Format
      return {
        'label_type': 'unknown',
        'raw_sms': body,
      };
    } catch (_) {
      return {
        'label_type': 'unknown',
        'raw_sms': body,
      };
    }
  }
}
