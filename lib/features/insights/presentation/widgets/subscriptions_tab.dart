import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/insights/domain/entities/subscription.dart';
import 'package:rozz/shared/utils/merchant_brand_resolver.dart';

/// Every detected subscription, ranked by monthly cost, with a total header.
/// Each row offers a dismiss action (monthly haircut / local merchant →
/// not-a-subscription).
class SubscriptionsTab extends StatelessWidget {
  final List<Subscription> subscriptions;
  final ValueChanged<String>? onDismiss;

  const SubscriptionsTab({super.key, required this.subscriptions, this.onDismiss});

  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final totalMonthly =
        subscriptions.fold(0.0, (sum, sub) => sum + sub.monthlyAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTotalHeader(totalMonthly),
        const SizedBox(height: 16),
        if (subscriptions.isEmpty)
          _buildEmptyState()
        else
          ...subscriptions.map(_buildSubscriptionRow),
      ],
    );
  }

  Widget _buildTotalHeader(double totalMonthly) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RozzColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${subscriptions.length} subscription${subscriptions.length == 1 ? '' : 's'} detected',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: RozzColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_currency.format(totalMonthly)}/month',
                  style: GoogleFonts.dmMono(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_currency.format(totalMonthly * 12)}/year',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: RozzColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: RozzColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.subscriptions_outlined, color: RozzColors.accent, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionRow(Subscription sub) {
    final brand = MerchantBrandResolver.resolve(sub.merchant, 'upi', 'debit');
    final last = sub.lastOccurrence;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RozzColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: brand.backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(brand.icon, color: brand.iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.merchant.isEmpty ? 'Unknown' : sub.merchant,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _occurrenceLine(sub.occurrences, last),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: RozzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            sub.amountVaries
                ? '${_currency.format(sub.minAmount)}–${_currency.format(sub.maxAmount)}/mo'
                : '${_currency.format(sub.monthlyAmount)}/mo',
            style: GoogleFonts.dmMono(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: RozzColors.textPrimary,
            ),
          ),
          if (onDismiss != null && sub.key.isNotEmpty) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: () => onDismiss?.call(sub.key),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: RozzColors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _occurrenceLine(int occurrences, DateTime? last) {
    final charged = occurrences == 1 ? 'charged once' : 'charged $occurrences times';
    if (last == null) return charged;
    final month = DateFormat('MMM yyyy').format(last);
    return '$charged · last $month';
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RozzColors.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.subscriptions_outlined, color: RozzColors.textSecondary, size: 32),
          const SizedBox(height: 12),
          Text(
            'no subscriptions detected yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: RozzColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'recurring charges are spotted from your transaction history — nothing hardcoded.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: RozzColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
