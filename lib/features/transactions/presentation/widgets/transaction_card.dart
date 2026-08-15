import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionCard({super.key, required this.transaction, this.onTap});

  static final _phoneLikeRe = RegExp(r'^[\d+\s\-]{6,}$');
  static final _accountMaskRe = RegExp(r'[*\*]');
  static final _merchantRe = RegExp(
    r'\b(?:at|to)\s+([A-Za-z0-9&@.\/\-]+(?:\s+[A-Za-z0-9&@.\/\-]+)*?)'
    r'(?=\.|,|$|\s+(?:on|via|by|for|ref)\b)',
    caseSensitive: false,
  );

  String _formatLabelType(String labelType) {
    switch (labelType) {
      case 'upi':
        return 'UPI Payment';
      case 'atm':
        return 'ATM Withdrawal';
      case 'neft':
        return 'NEFT Transfer';
      case 'imps':
        return 'IMPS Transfer';
      case 'card':
        return 'Card Payment';
      case 'fine':
        return 'MAB Fine';
      case 'bank_sms':
        return 'Bank SMS';
      case 'unknown':
        return 'Bank SMS';
      default:
        return labelType
            .split('_')
            .map((word) => word.isEmpty
                ? ''
                : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
            .join(' ');
    }
  }

  /// The name a human can read: the merchant / recipient. Falls back to
  /// extracting "At ..." / "To ..." from the raw SMS, then to the transaction
  /// type. Filters junk the parser sometimes grabs (phone numbers, masked
  /// account strings, "clearing").
  String _displayTitle(Transaction transaction) {
    final raw = transaction.rawSms ?? '';
    final name = transaction.recipientName?.trim() ?? '';
    if (name.isNotEmpty &&
        !_phoneLikeRe.hasMatch(name) &&
        !_accountMaskRe.hasMatch(name) &&
        name.toLowerCase() != 'clearing') {
      return name;
    }

    final merchant = _merchantRe.firstMatch(raw);
    if (merchant != null) {
      final m = merchant.group(1)!.trim();
      if (m.isNotEmpty && !_phoneLikeRe.hasMatch(m)) return m;
    }

    if (transaction.direction == 'credit' && raw.toLowerCase().contains('deposited')) {
      return 'Cash Deposit';
    }
    return _formatLabelType(transaction.labelType);
  }

  IconData _getIcon(String labelType, String direction) {
    if (direction == 'credit') return Icons.south_west;
    switch (labelType) {
      case 'atm':
        return Icons.atm_outlined;
      case 'neft':
      case 'imps':
        return Icons.swap_horiz_outlined;
      case 'fine':
        return Icons.warning_amber_outlined;
      case 'card':
        return Icons.credit_card_outlined;
      default:
        return Icons.north_east;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction.direction == 'debit';
    final amountColor = isDebit ? RozzColors.expense : RozzColors.income;
    final amountPrefix = isDebit ? '-' : '+';
    final amount = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9').format(transaction.amount);

    final dateTime = DateTime.parse(transaction.date).toLocal();
    final timeStr = DateFormat('hh:mm a').format(dateTime);

    final title = _displayTitle(transaction);
    final subtitle = transaction.category ?? _formatLabelType(transaction.labelType);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 72,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: RozzColors.s1,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: RozzColors.textSecondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIcon(transaction.labelType, transaction.direction),
                size: 20,
                color: isDebit ? RozzColors.expense : RozzColors.income,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: RozzColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: RozzColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$amountPrefix$amount',
                  style: GoogleFonts.dmMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: RozzColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: RozzColors.textSecondary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
