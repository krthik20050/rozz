import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/insights/domain/entities/upcoming_charge.dart';
import 'package:rozz/shared/utils/merchant_brand_resolver.dart';

/// Upcoming recurring charges predicted from real transaction history —
/// the live replacement for the old hardcoded "COMING UP" list.
class UpcomingChargesCard extends StatelessWidget {
  final List<UpcomingCharge> charges;

  const UpcomingChargesCard({super.key, required this.charges});

  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    if (charges.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RozzColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UPCOMING CHARGES',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: RozzColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const Icon(Icons.event_repeat, size: 16, color: RozzColors.gold),
            ],
          ),
          const SizedBox(height: 16),
          ...charges.take(4).map((charge) => _buildRow(charge)),
        ],
      ),
    );
  }

  Widget _buildRow(UpcomingCharge charge) {
    final brand = MerchantBrandResolver.resolve(charge.merchant, 'upi', 'debit');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: brand.backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(brand.icon, color: brand.iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              charge.merchant,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: RozzColors.textPrimary,
              ),
            ),
          ),
          Text(
            _currency.format(charge.amount),
            style: GoogleFonts.dmMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: RozzColors.textPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            _dateLabel(charge.predictedDate),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: RozzColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = date.difference(today).inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    return DateFormat('d MMM').format(date);
  }
}
