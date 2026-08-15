import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Full details for one transaction: parsed fields + the original bank SMS.
class TransactionDetailsSheet extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailsSheet({super.key, required this.transaction});

  static void show(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: RozzColors.s2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TransactionDetailsSheet(transaction: transaction),
    );
  }

  String _directionLabel() {
    switch (transaction.direction) {
      case 'debit':
        return 'Debited';
      case 'credit':
        return 'Credited';
      default:
        return 'Transaction';
    }
  }

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
      default:
        return labelType
            .split('_')
            .map((word) => word.isEmpty
                ? ''
                : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
            .join(' ');
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: RozzColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: RozzColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction.direction == 'debit';
    final color = isDebit ? RozzColors.expense : RozzColors.income;
    final amount = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9').format(transaction.amount);
    final dateTime = DateTime.parse(transaction.date).toLocal();
    final dateStr = DateFormat('EEEE, d MMM yyyy').format(dateTime);
    final timeStr = DateFormat('hh:mm a').format(dateTime);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: RozzColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _directionLabel(),
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: GoogleFonts.dmMono(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: RozzColors.textPrimary,
            ),
          ),
          if (transaction.recipientName != null) ...[
            const SizedBox(height: 4),
            Text(
              transaction.recipientName!,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: RozzColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Divider(color: RozzColors.textSecondary.withValues(alpha: 0.15)),
          const SizedBox(height: 8),
          _row('Date', dateStr),
          _row('Time', timeStr),
          _row('Type', _formatLabelType(transaction.labelType)),
          if (transaction.category != null) _row('Category', transaction.category!),
          if (transaction.upiRefNumber != null) _row('UPI Ref', transaction.upiRefNumber!),
          if (transaction.upiId != null) _row('UPI ID', transaction.upiId!),
          if (transaction.balanceAfter != null)
            _row('Balance after',
                NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9').format(transaction.balanceAfter!)),
          if (transaction.rawSms != null) ...[
            const SizedBox(height: 16),
            Text(
              'Original SMS',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: RozzColors.textSecondary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: RozzColors.s3,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                transaction.rawSms!,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  height: 1.5,
                  color: RozzColors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
