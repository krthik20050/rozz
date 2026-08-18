import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/mab/domain/entities/mab_record.dart';

/// Daily balance check for the selected month — a readable replacement for the
/// old line chart. Answers the two questions people actually ask:
///   • how many days was I above the minimum?
///   • what was each day's closing balance?
class MabChart extends StatelessWidget {
  final List<MabRecord> records;
  final double threshold;
  final int month;
  final int year;

  const MabChart({
    super.key,
    required this.records,
    required this.threshold,
    required this.month,
    required this.year,
  });

  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: RozzColors.s1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: RozzColors.cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fact_check_outlined, color: RozzColors.textMuted, size: 32),
            const SizedBox(height: 12),
            Text(
              'no balance records for this month yet',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: RozzColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'your daily balances build from real SMS snapshots.',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: RozzColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final sorted = [...records]
      ..sort((a, b) => a.date.compareTo(b.date));
    final daysAbove = sorted
        .where((r) => r.endOfDayBalance >= threshold)
        .length;
    final progress = daysAbove / sorted.length;
    final lastDays = sorted.length > 8 ? sorted.sublist(sorted.length - 8) : sorted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                'DAILY BALANCE CHECK',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: RozzColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                DateFormat('MMMM').format(DateTime(year, month)).toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: RozzColors.gold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$daysAbove of ${sorted.length} days above ${_currency.format(threshold)}',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: daysAbove == 0
                  ? RozzColors.expense
                  : (progress >= 0.5 ? RozzColors.income : RozzColors.gold),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: RozzColors.s3,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 0.5 ? RozzColors.income : RozzColors.expense,
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final record in lastDays) _buildDayRow(record),
        ],
      ),
    );
  }

  Widget _buildDayRow(MabRecord record) {
    final above = record.endOfDayBalance >= threshold;
    final date = DateTime.tryParse(record.date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            above ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: above ? RozzColors.income : RozzColors.expense,
          ),
          const SizedBox(width: 10),
          Text(
            date == null
                ? record.date
                : DateFormat('d MMM').format(date),
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: RozzColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            _currency.format(record.endOfDayBalance),
            style: GoogleFonts.dmMono(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: above ? RozzColors.textPrimary : RozzColors.expense,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            above ? 'ok' : 'low',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: above ? RozzColors.income : RozzColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}
