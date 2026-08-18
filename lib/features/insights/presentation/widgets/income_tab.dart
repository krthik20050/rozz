import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/insights/domain/entities/income_source.dart';
import 'package:rozz/features/insights/domain/entities/monthly_summary.dart';
import 'package:rozz/features/insights/domain/entities/recurring_income.dart';
import 'package:rozz/features/insights/domain/entities/resolved_sender.dart';
import 'package:rozz/features/insights/presentation/bloc/insights_bloc.dart';
import 'package:rozz/features/insights/presentation/pages/manage_senders_page.dart';
import 'package:rozz/features/insights/presentation/widgets/insights_shared.dart';

/// Money in for the month: received vs last month, net saved, and who sent it
/// — senders resolved to labels ("father"), contact names, or raw names.
class IncomeTab extends StatelessWidget {
  final MonthlySummary summary;

  /// Senders merged by display name, largest first.
  final List<IncomeSource> incomeSources;

  /// Per-key senders, for showing who is identified and managing labels.
  final List<ResolvedSender> senders;

  /// Credits that arrive most months — with whether this month's landed.
  final List<RecurringIncome> recurringIncome;

  const IncomeTab({
    super.key,
    required this.summary,
    required this.incomeSources,
    required this.senders,
    this.recurringIncome = const [],
  });

  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    // Frequent unidentified senders get a "who is this?" prompt — research:
    // proactively asking beats a passive unidentified row.
    final frequentUnidentified = senders
        .where((s) => !s.identified && s.count >= 2)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMonthPill(),
        const SizedBox(height: 12),
        _buildReceivedHeader(),
        const SizedBox(height: 16),
        if (recurringIncome.isNotEmpty) ...[
          _buildSectionLabel('recurring income'),
          ...recurringIncome.map((r) => _buildRecurringCard(r)),
          const SizedBox(height: 8),
        ],
        if (frequentUnidentified.isNotEmpty) ...[
          ...frequentUnidentified.map((sender) => _buildPromptCard(context, sender)),
          const SizedBox(height: 8),
        ],
        if (incomeSources.isEmpty)
          _buildEmptyState()
        else ...[
          ...incomeSources.map((source) => _buildSourceRow(source)),
          const SizedBox(height: 8),
          _buildManageEntry(context),
        ],
      ],
    );
  }

  /// "8075637374 keeps sending you money — who is this?" with a one-tap name
  /// flow and a contacts re-check for phone-number senders.
  Widget _buildPromptCard(BuildContext context, ResolvedSender sender) {
    final isPhone = RegExp(r'\d{7,}').hasMatch(sender.key);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RozzColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RozzColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, size: 18, color: RozzColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${sender.rawName} keeps sending you money',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_currency.format(sender.amount)} from ${sender.count} payments this month — who is this?',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: RozzColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    onPressed: () => showSenderLabelSheet(context, sender, null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: RozzColors.gold,
                      side: const BorderSide(color: RozzColors.gold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'name them',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              if (isPhone) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed: () {
                        context.read<InsightsBloc>().add(CheckContacts());
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RozzColors.textPrimary,
                        side: const BorderSide(color: RozzColors.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'check contacts',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  /// "salary / pension / allowance — every month, from the same person."
  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: RozzColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// One card per recurring sender: how much, how often, and did it land
  /// this month (the "is my allowance/interest in yet?" question).
  Widget _buildRecurringCard(RecurringIncome recurring) {
    final monthName = DateFormat('MMMM').format(recurring.lastSeen);
    final arrived = recurring.arrivedThisMonth;
    final status = arrived
        ? 'arrived this month — ${recurring.paymentsThisMonth} payment${recurring.paymentsThisMonth == 1 ? '' : 's'} in'
        : (recurring.expectedNext != null
            ? 'not in yet — last seen $monthName, expected around ${DateFormat('d MMM').format(recurring.expectedNext!)}'
            : 'not in yet — last seen $monthName');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (arrived ? RozzColors.income : RozzColors.gold)
              .withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (arrived ? RozzColors.income : RozzColors.gold)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              arrived ? Icons.check_circle_outline : Icons.schedule,
              color: arrived ? RozzColors.income : RozzColors.gold,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_currency.format(recurring.typicalAmount)}/month from ${recurring.displayName}',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$status · seen ${recurring.monthsSeen} months',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: arrived ? RozzColors.income : RozzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildReceivedHeader() {
    final change = summary.priorReceived > 0
        ? ((summary.received - summary.priorReceived) / summary.priorReceived) * 100
        : null;
    final changeLabel = switch (change) {
      null => 'no income recorded last month to compare against',
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
        border: Border.all(color: RozzColors.income.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'you received',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: RozzColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currency.format(summary.received),
                  style: GoogleFonts.dmMono(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.income,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  changeLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: change != null && change < -0.5
                        ? RozzColors.expense
                        : RozzColors.income,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: RozzColors.income.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.trending_up, color: RozzColors.income, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                'saved ${_currency.format(summary.saved)}',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: summary.saved >= 0 ? RozzColors.income : RozzColors.expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceRow(IncomeSource source) {
    // Identify whether this merged row came from a labeled/contact-matched
    // sender (any of its underlying keys was identified).
    final identified = senders.any(
      (s) => s.displayName == source.recipient && s.identified,
    );

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
              color: identified
                  ? RozzColors.income.withValues(alpha: 0.12)
                  : RozzColors.s2,
              shape: BoxShape.circle,
            ),
            child: Icon(
              identified
                  ? Icons.person_outline
                  : Icons.account_balance_wallet_outlined,
              color: identified ? RozzColors.income : RozzColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.recipient,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: RozzColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _identificationLine(source),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: identified ? RozzColors.income : RozzColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _currency.format(source.amount),
            style: GoogleFonts.dmMono(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: RozzColors.income,
            ),
          ),
        ],
      ),
    );
  }

  /// Explains HOW a sender was identified — so contact matching is visible:
  /// labeled by the user, matched from contacts, or still raw.
  String _identificationLine(IncomeSource source) {
    final sender = senders.firstWhere(
      (s) => s.displayName == source.recipient,
      orElse: () => senders.first,
    );
    final payments =
        '${source.count == 1 ? '1 payment' : '${source.count} payments'} this month';
    return switch (sender.identification) {
      'label' => 'named by you · $payments',
      'contact' => 'matched from your contacts · $payments',
      _ => 'unidentified sender — tap to name',
    };
  }

  Widget _buildManageEntry(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ManageSendersPage()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: RozzColors.s2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RozzColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit_outlined, size: 16, color: RozzColors.gold),
            const SizedBox(width: 8),
            Text(
              'manage senders',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: RozzColors.gold,
              ),
            ),
          ],
        ),
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
          const Icon(Icons.south_west, color: RozzColors.textSecondary, size: 32),
          const SizedBox(height: 12),
          Text(
            'no income recorded this month yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: RozzColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'credits from your transactions will be grouped by sender here.',
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
