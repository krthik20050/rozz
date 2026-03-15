import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BalanceHero extends StatelessWidget {
  final double balance;
  const BalanceHero({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    final amount = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9').format(balance);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Text(
            'Total Balance',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: RozzColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: GoogleFonts.dmMono(
              fontSize: 52,
              fontWeight: FontWeight.bold,
              color: RozzColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.arrow_drop_down, color: RozzColors.expense, size: 16),
              Text(
                ' \u20B90 today', // Dummy for now
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: RozzColors.expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
