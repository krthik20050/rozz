import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionCard({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction.direction == 'debit';
    final amountColor = isDebit ? RozzColors.expense : RozzColors.income;
    final amountPrefix = isDebit ? '-' : '+';
    final amount = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9').format(transaction.amount);

    final dateTime = DateTime.parse(transaction.date).toLocal();
    final timeStr = DateFormat('hh:mm a').format(dateTime);

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
              child: const Icon(Icons.compare_arrows, size: 20, color: RozzColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.recipientName ?? transaction.labelType.toUpperCase(),
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
                    'Narration coming tonight \u2727',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
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
          ],
        ),
      ),
    );
  }
}

