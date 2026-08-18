import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/insights/domain/entities/monthly_summary.dart';
import 'package:rozz/features/monthly_review/presentation/bloc/monthly_review_bloc.dart';
import 'package:rozz/shared/widgets/month_picker.dart';
import 'package:rozz/shared/widgets/state_message.dart';
import 'package:share_plus/share_plus.dart';

class MonthlyReviewPage extends StatefulWidget {
  const MonthlyReviewPage({super.key});

  @override
  State<MonthlyReviewPage> createState() => _MonthlyReviewPageState();
}

class _MonthlyReviewPageState extends State<MonthlyReviewPage> {
  late int _month = DateTime.now().month;
  late int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    context.read<MonthlyReviewBloc>().add(
          LoadMonthlyReview(month: _month, year: _year),
        );
  }

  Future<void> _pickMonth() async {
    final picked = await showMonthPickerSheet(
      context,
      month: _month,
      year: _year,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _month = picked.$1;
      _year = picked.$2;
    });
    _load();
  }

  Future<void> _shareSummary(MonthlySummary summary) async {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final top = summary.categories.isNotEmpty
        ? 'Top spend: ${summary.categories.first.category} (${currency.format(summary.categories.first.amount)}).'
        : '';
    final text = [
      'My ROZZ monthly review — ${DateFormat('MMMM yyyy').format(DateTime(_year, _month))}',
      'Received ${currency.format(summary.received)} · Spent ${currency.format(summary.spent)} · Saved ${currency.format(summary.saved)}',
      if (top.isNotEmpty) top,
    ].join('\n');
    await Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'monthly review',
          style: GoogleFonts.syne(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: RozzColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              final state = context.read<MonthlyReviewBloc>().state;
              if (state is MonthlyReviewLoaded) {
                _shareSummary(state.summary);
              }
            },
            icon: const Icon(Icons.ios_share, color: RozzColors.textPrimary),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<MonthlyReviewBloc, MonthlyReviewState>(
          builder: (context, state) {
            if (state is MonthlyReviewLoading || state is MonthlyReviewInitial) {
              return const Center(
                child: CircularProgressIndicator(color: RozzColors.gold),
              );
            } else if (state is MonthlyReviewError) {
              return StateMessage.error(
                title: 'couldn\'t build your review',
                message: 'Something went wrong while crunching the numbers. Try again.',
                onRetry: _load,
              );
            } else if (state is MonthlyReviewLoaded) {
              return _buildSummary(context, state.summary);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, MonthlySummary summary) {
    final hasActivity = summary.received > 0 || summary.spent > 0 || summary.categories.isNotEmpty;
    if (!hasActivity) {
      return const StateMessage.empty(
        title: 'no activity this month',
        message: 'once transactions come in, your monthly recap will build itself here.',
      );
    }

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Pill — tap to switch months.
          GestureDetector(
            onTap: _pickMonth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: RozzColors.s1,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RozzColors.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMMM yyyy')
                        .format(DateTime(_year, _month))
                        .toLowerCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: RozzColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: RozzColors.textSecondary),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            summary.saved >= 0
                ? 'you did great this month.'
                : 'you spent more than you received.',
            style: GoogleFonts.syne(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: summary.saved >= 0
                  ? RozzColors.textPrimary
                  : RozzColors.expense,
            ),
          ),

          const SizedBox(height: 20),

          // 3 Stat Summary Boxes
          Row(
            children: [
              Expanded(child: _buildStatBox('received', currency.format(summary.received), RozzColors.income)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatBox('spent', currency.format(summary.spent), RozzColors.expense)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatBox('saved', currency.format(summary.saved), RozzColors.gold)),
            ],
          ),

          const SizedBox(height: 24),

          if (summary.categories.isNotEmpty) ...[
            _buildHighlightCard(
              icon: Icons.restaurant,
              color: RozzColors.gold,
              title: '${summary.categories.first.category} was your biggest expense',
              subtitle: _categorySubtitle(summary.categories.first, currency),
              onTap: () => _showSpendingSheet(context, summary, currency),
            ),
            const SizedBox(height: 12),
          ],

          _buildHighlightCard(
            icon: Icons.lightbulb_outline,
            color: RozzColors.income,
            title: _savedTitle(summary),
            subtitle: _savedSubtitle(summary, currency),
            onTap: () => _showSavingsSheet(context, summary, currency),
          ),

          const SizedBox(height: 32),

          // Primary Share CTA Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => _shareSummary(summary),
              style: ElevatedButton.styleFrom(
                backgroundColor: RozzColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 4,
              ),
              child: Text(
                'share this recap',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Breakdown sheet for the biggest-expense card: every category ranked.
  void _showSpendingSheet(
    BuildContext context,
    MonthlySummary summary,
    NumberFormat currency,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RozzColors.s2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'where your money went',
                  style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                for (final category in summary.categories.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          category.category,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: RozzColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          currency.format(category.amount),
                          style: GoogleFonts.dmMono(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: RozzColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Breakdown sheet for the savings card: received vs spent vs saved.
  void _showSavingsSheet(
    BuildContext context,
    MonthlySummary summary,
    NumberFormat currency,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RozzColors.s2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        Widget row(String label, String value, Color color) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: RozzColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: GoogleFonts.dmMono(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'savings breakdown',
                  style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                row('received', currency.format(summary.received), RozzColors.income),
                row('spent', currency.format(summary.spent), RozzColors.expense),
                row('saved', currency.format(summary.saved), RozzColors.gold),
              ],
            ),
          ),
        );
      },
    );
  }

  String _categorySubtitle(CategorySpend top, NumberFormat currency) {
    final change = top.changePercent;
    if (change == null) {
      return 'New this month — nothing spent on it last month.';
    }
    final rounded = change.abs().round();
    final prior = top.priorAmount ?? 0;
    if (change.abs() < 0.5) {
      return 'About the same as last month (${currency.format(prior)}).';
    }
    final direction = change > 0 ? 'higher' : 'lower';
    return '$rounded% $direction than your usual (${currency.format(prior)}).';
  }

  String _savedTitle(MonthlySummary summary) {
    if (summary.saved < 0) return 'You spent more than you received';
    if (summary.priorSaved <= 0 && summary.saved > 0) return 'You started saving this month';
    if (summary.priorSaved == 0) return 'Your savings held steady';
    final pct = ((summary.saved - summary.priorSaved) / summary.priorSaved.abs()) * 100;
    final rounded = pct.abs().round();
    if (pct.abs() < 0.5) return 'You saved about the same as last month';
    return pct > 0
        ? 'You saved $rounded% more than last month'
        : 'You saved $rounded% less than last month';
  }

  String _savedSubtitle(MonthlySummary summary, NumberFormat currency) {
    if (summary.saved < 0) {
      return 'Outflow beat income by ${currency.format(summary.saved.abs())} this month.';
    }
    return '${currency.format(summary.saved)} saved, after receiving ${currency.format(summary.received)}.';
  }

  Widget _buildStatBox(String label, String amount, Color color) {
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
        ],
      ),
    );
  }

  Widget _buildHighlightCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RozzColors.s1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RozzColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: RozzColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
      ),
    );
  }
}
