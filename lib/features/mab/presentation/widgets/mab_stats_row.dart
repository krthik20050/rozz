import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/mab/domain/entities/mab_status.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MabStatsRow extends StatelessWidget {
  final MabStatus status;
  const MabStatsRow({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
    final zoneColor = _getZoneColor(status.zone);
    final gap = status.currentMab - status.requiredMin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Text(
            currencyFormat.format(status.currentMab),
            style: GoogleFonts.dmMono(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: zoneColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Required ${currencyFormat.format(status.requiredMin)}',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: RozzColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 4, height: 4, decoration: const BoxDecoration(color: RozzColors.textSecondary, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Text(
                '${gap >= 0 ? '+' : ''}${currencyFormat.format(gap)}',
                style: GoogleFonts.dmMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: zoneColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getZoneColor(MabZone zone) {
    switch (zone) {
      case MabZone.safe: return RozzColors.income;
      case MabZone.middle: return RozzColors.insight;
      case MabZone.danger: return const Color(0xFFF0923A);
      case MabZone.fine: return RozzColors.expense;
    }
  }
}
