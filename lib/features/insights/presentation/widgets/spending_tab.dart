import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/insights/domain/entities/monthly_summary.dart';
import 'package:rozz/features/insights/presentation/widgets/insights_shared.dart';

/// Full spend breakdown for the month: total spent vs prior, then every
/// category ranked with its share and prior-month comparison.
class SpendingTab extends StatelessWidget {
  final MonthlySummary summary;

  const SpendingTab({super.key, required this.summary});

  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMonthPill(),
        const SizedBox(height: 12),
        _buildTotalHeader(),
        const SizedBox(height: 16),
        if (summary.categories.isEmpty)
          _buildEmptyState()
        else
          ...summary.categories.map(_buildCategoryRow),
      ],
    );
  }

  Widget _buildMonthPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RozzColors.cardBorder),
      ),
      child: Text(
        monthLabel(summary.month, summary.year),
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: RozzColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTotalHeader() {
    final change = summary.priorSpent > 0
        ? ((summary.spent - summary.priorSpent) / summary.priorSpent) * 100
        : null;
    final changeLabel = switch (change) {
      null => 'no spending last month to compare against',
      final c when c.abs() < 0.5 => 'about the same as last month',
      final c => c > 0
          ? '+${c.round()}% vs last month'
          : '−${c.abs().round()}% vs last month',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RozzColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'you spent',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: RozzColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currency.format(summary.spent),
                  style: GoogleFonts.dmMono(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.expense,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  changeLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: change != null && change > 0.5
                        ? RozzColors.expense
                        : RozzColors.income,
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
              color: RozzColors.expense.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.trending_down, color: RozzColors.expense, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(CategorySpend spend) {
    final share = summary.spent > 0 ? (spend.amount / summary.spent) * 100 : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RozzColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(categoryIcon(spend.category), color: RozzColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  spend.category,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.textPrimary,
                  ),
                ),
              ),
              Text(
                _currency.format(spend.amount),
                style: GoogleFonts.dmMono(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: RozzColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (share / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: RozzColors.s3,
              valueColor: const AlwaysStoppedAnimation<Color>(RozzColors.gold),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${share.toStringAsFixed(1)}% of spend',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: RozzColors.textMuted,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  changeLine(spend, _currency),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: (spend.changePercent ?? 0) >= 0
                        ? RozzColors.expense
                        : RozzColors.income,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
          const Icon(Icons.receipt_long_outlined, color: RozzColors.textSecondary, size: 32),
          const SizedBox(height: 12),
          Text(
            'no spending recorded this month yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: RozzColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'your category breakdown will appear here as transactions come in.',
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
