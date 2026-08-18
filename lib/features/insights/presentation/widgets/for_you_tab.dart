import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/insights/domain/entities/balance_streak.dart';
import 'package:rozz/features/insights/domain/entities/monthly_summary.dart';
import 'package:rozz/features/insights/domain/entities/subscription.dart';
import 'package:rozz/features/insights/domain/usecases/compute_balance_streak.dart';
import 'package:rozz/features/insights/presentation/widgets/insights_shared.dart';
import 'package:rozz/features/mab/domain/entities/mab_status.dart';
import 'package:rozz/features/mab/presentation/bloc/mab_bloc.dart';
import 'package:rozz/features/monthly_review/presentation/pages/monthly_review_page.dart';
import 'package:rozz/shared/utils/merchant_brand_resolver.dart';

/// The curated "for you" dashboard: money in/out/saved, MAB health, streak,
/// top spend, and subscription watch. Pairs the insights data with MAB state.
class ForYouTab extends StatelessWidget {
  final MonthlySummary summary;
  final List<Subscription> subscriptions;

  const ForYouTab({
    super.key,
    required this.summary,
    required this.subscriptions,
  });

  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month context + received/spent/saved stat row
        _buildMonthPill(),
        const SizedBox(height: 12),
        _buildStatsRow(),
        const SizedBox(height: 16),

        // Monthly Review entry
        _buildMonthlyReviewEntry(context),
        const SizedBox(height: 16),

        // MAB-derived cards: health banner + balance streak
        BlocBuilder<MabBloc, MabState>(
          builder: (context, state) {
            if (state is MabLoaded) {
              final now = DateTime.now();
              final streak = computeBalanceStreak(
                records: state.records,
                threshold: state.status.requiredMin,
                month: now.month,
                year: now.year,
                today: now,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHealthBanner(state.status),
                  const SizedBox(height: 16),
                  _buildStreakCard(streak),
                  const SizedBox(height: 16),
                ],
              );
            }
            return const SizedBox(height: 8);
          },
        ),

        // Ledger highlights
        if (summary.categories.isNotEmpty) ...[
          _buildSpendingHighlight(summary),
          const SizedBox(height: 16),
        ],
        if (subscriptions.isNotEmpty) ...[
          _buildSubscriptionWatch(subscriptions),
          const SizedBox(height: 16),
        ],
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

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatBox(
            label: 'received',
            amount: _currency.format(summary.received),
            color: RozzColors.income,
            delta: _deltaLabel(summary.received, summary.priorReceived),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatBox(
            label: 'spent',
            amount: _currency.format(summary.spent),
            color: RozzColors.expense,
            delta: _deltaLabel(summary.spent, summary.priorSpent),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatBox(
            label: 'saved',
            amount: _currency.format(summary.saved),
            color: RozzColors.gold,
            delta: _deltaLabel(summary.saved, summary.priorSaved),
          ),
        ),
      ],
    );
  }

  /// "+12%" / "−8%" vs prior month, or nothing when there's nothing to
  /// compare against.
  String? _deltaLabel(double current, double prior) {
    if (prior <= 0) return null;
    final pct = ((current - prior) / prior) * 100;
    if (pct.abs() < 0.5) return '~ same';
    return pct > 0 ? '+${pct.round()}%' : '−${pct.abs().round()}%';
  }

  Widget _buildStatBox({
    required String label,
    required String amount,
    required Color color,
    String? delta,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RozzColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: RozzColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: GoogleFonts.dmMono(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text(
              delta,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: RozzColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyReviewEntry(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const MonthlyReviewPage(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RozzColors.s1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RozzColors.gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: RozzColors.gold, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'monthly review',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: RozzColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'received, spent & saved — from your real transactions',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: RozzColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: RozzColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthBanner(MabStatus status) {
    final (title, color, subtitle) = switch (status.zone) {
      MabZone.safe => (
          'your balance is healthy',
          RozzColors.income,
          'Your MAB stays above the ${_currency.format(status.requiredMin)} minimum at your current pace.',
        ),
      MabZone.middle => (
          'your balance needs a nudge',
          RozzColors.gold,
          'You\'re close to the MAB line — keep an eye on daily balances.',
        ),
      MabZone.danger => (
          'your balance is trending low',
          RozzColors.expense,
          'Your MAB is heading below the required minimum.',
        ),
      MabZone.fine => (
          'your balance dropped below MAB',
          RozzColors.expense,
          'A maintenance fine may apply this month.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_currency.format(status.currentMab)} MAB this month — $subtitle',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: RozzColors.textSecondary,
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
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_outlined, color: color, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(BalanceStreak streak) {
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
                Row(
                  children: [
                    const Icon(Icons.bolt, color: RozzColors.income, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'balance streak',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: RozzColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Above your required MAB on ${streak.daysAbove} of ${streak.daysRecorded} recorded days this month.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: RozzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: RozzColors.income.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: RozzColors.income, width: 2),
            ),
            child: Center(
              child: Text(
                '${streak.daysAbove}\ndays',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: RozzColors.income,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingHighlight(MonthlySummary summary) {
    final top = summary.categories.first;

    return Container(
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
            children: [
              Icon(categoryIcon(top.category), color: RozzColors.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                'spending most on ${top.category.toLowerCase()}',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: RozzColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currency.format(top.amount),
            style: GoogleFonts.dmMono(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: RozzColors.textPrimary,
            ),
          ),
          Text(
            changeLine(top, _currency),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: (top.changePercent ?? 0) >= 0 ? RozzColors.expense : RozzColors.income,
            ),
          ),
          const SizedBox(height: 16),
          _buildCategoryBars(summary.categories),
        ],
      ),
    );
  }

  Widget _buildCategoryBars(List<CategorySpend> categories) {
    final top = categories.take(4).toList();
    final maxAmount = top.first.amount;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: top.map((c) {
        final height = maxAmount <= 0 ? 12.0 : 12.0 + ((c.amount / maxAmount) * 32.0);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                Text(
                  _currency.format(c.amount),
                  style: GoogleFonts.dmMono(fontSize: 9, color: RozzColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: c == top.first ? RozzColors.gold : RozzColors.s3,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontSize: 9, color: RozzColors.textSecondary),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubscriptionWatch(List<Subscription> subscriptions) {
    final totalMonthly =
        subscriptions.fold(0.0, (sum, sub) => sum + sub.monthlyAmount);

    return Container(
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
            children: [
              const Icon(Icons.subscriptions_outlined, color: RozzColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'subscription watch',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: RozzColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re paying ${_currency.format(totalMonthly)}/month for ${subscriptions.length} subscription${subscriptions.length == 1 ? '' : 's'}.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: RozzColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ...subscriptions.take(4).map((sub) => _buildSubBadge(sub)),
              if (subscriptions.length > 4) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: RozzColors.s2,
                    shape: BoxShape.circle,
                    border: Border.all(color: RozzColors.cardBorder),
                  ),
                  child: Text(
                    '+${subscriptions.length - 4}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: RozzColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubBadge(Subscription sub) {
    final brand = MerchantBrandResolver.resolve(sub.merchant, 'upi', 'debit');
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: brand.backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            sub.merchant.isEmpty ? '?' : sub.merchant[0].toUpperCase(),
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
