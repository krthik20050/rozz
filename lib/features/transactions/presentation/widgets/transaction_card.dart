import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/insights/presentation/bloc/insights_bloc.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/shared/utils/merchant_brand_resolver.dart';
import 'package:rozz/shared/utils/sender_label_resolver.dart';
import 'package:rozz/shared/widgets/pressable.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionCard({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction.direction == 'debit';
    final amountColor = isDebit ? RozzColors.expense : RozzColors.income;
    final amountPrefix = isDebit ? '-' : '+';
    final amount = NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(transaction.amount);

    final dateTime = DateTime.parse(transaction.date).toLocal();
    final timeStr = DateFormat('hh:mm a').format(dateTime);

    final brand = MerchantBrandResolver.resolve(
      transaction.recipientName ?? '',
      transaction.labelType,
      transaction.direction,
      rawSms: transaction.rawSms ?? '',
    );

    // A user label ("papa") for a money-in sender applies everywhere the
    // sender's account/VPA appears — home, activity, anywhere the card shows.
    final senderLabel = _senderLabel(context, transaction);
    final displayName = senderLabel ?? brand.name;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RozzColors.s1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RozzColors.cardBorder),
          ),
          child: Row(
              children: [
                // Brand Avatar Logomark
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: brand.backgroundColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: brand.backgroundColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    brand.icon,
                    size: 20,
                    color: brand.iconColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: RozzColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            transaction.category ?? brand.category,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: RozzColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: GoogleFonts.dmSans(fontSize: 10, color: RozzColors.textMuted),
                          ),
                          const SizedBox(width: 8),
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
                const SizedBox(width: 12),
                Text(
                  '$amountPrefix$amount',
                  style: GoogleFonts.dmMono(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  /// Looks up the user's label ("papa") for a credit sender — exact key, VPA
  /// local part, or shared stem ("kknair"), same rules as the income tab.
  String? _senderLabel(BuildContext context, Transaction tx) {
    if (tx.direction != 'credit') return null;
    final labels = context.select<InsightsBloc, Map<String, String>>(
      (bloc) => bloc.state is InsightsLoaded
          ? (bloc.state as InsightsLoaded).senderLabels
          : const <String, String>{},
    );
    final key = (tx.recipientName ?? '').trim().toLowerCase();
    if (key.isEmpty) return null;
    return resolveSenderLabel(key, labels);
  }
}
