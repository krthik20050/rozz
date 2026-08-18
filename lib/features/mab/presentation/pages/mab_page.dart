import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/mab/domain/entities/mab_status.dart';
import 'package:rozz/features/mab/domain/usecases/estimate_mab_fine.dart';
import 'package:rozz/features/mab/presentation/bloc/mab_bloc.dart';
import 'package:rozz/features/mab/presentation/widgets/mab_zone_banner.dart';
import 'package:rozz/features/mab/presentation/widgets/mab_stats_row.dart';
import 'package:rozz/features/mab/presentation/widgets/mab_chart.dart';
import 'package:rozz/features/monthly_review/presentation/pages/monthly_review_page.dart';
import 'package:rozz/shared/widgets/month_picker.dart';
import 'package:rozz/shared/widgets/state_message.dart';

class MabPage extends StatefulWidget {
  const MabPage({super.key});

  @override
  State<MabPage> createState() => _MabPageState();
}

class _MabPageState extends State<MabPage> {
  /// The month shown in the pill. Real, selected by the user — never a
  /// hardcoded label. Defaults to the current month.
  late int _month = DateTime.now().month;
  late int _year = DateTime.now().year;

  Future<void> _editRequiredMin() async {
    final blocState = context.read<MabBloc>().state;
    final current = blocState is MabLoaded ? blocState.status.requiredMin : 5000.0;
    final controller = TextEditingController(
      text: current.round().toString(),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: RozzColors.s2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'required minimum balance',
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: RozzColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'the monthly average your bank asks you to keep (e.g. 5000).',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: RozzColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: RozzColors.textPrimary),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: RozzColors.s3,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('cancel', style: TextStyle(color: RozzColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                if (value != null && value > 0) {
                  Navigator.of(dialogContext).pop(value);
                }
              },
              child: const Text('save',
                  style: TextStyle(color: RozzColors.gold, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    if (result != null && mounted) {
      context.read<MabBloc>().add(
            SetRequiredMin(amount: result, month: _month, year: _year),
          );
    }
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
    final now = DateTime.now();
    context.read<MabBloc>().add(
          LoadMabStatus(month: _month, year: _year, now: now),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Text(
              'mab forecast',
              style: GoogleFonts.syne(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: RozzColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _pickMonth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: RozzColors.s1,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RozzColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Text(
                      DateFormat('MMMM yyyy')
                          .format(DateTime(_year, _month))
                          .toLowerCase(),
                      style: GoogleFonts.dmSans(fontSize: 12, color: RozzColors.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 14, color: RozzColors.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _editRequiredMin,
            icon: const Icon(Icons.settings_outlined, color: RozzColors.textSecondary),
            tooltip: 'Required minimum balance',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MonthlyReviewPage()),
              );
            },
            icon: const Icon(Icons.assessment_outlined, color: RozzColors.gold),
            tooltip: 'Monthly Review',
          ),
        ],
      ),
      body: BlocBuilder<MabBloc, MabState>(
        builder: (context, state) {
          if (state is MabInitial || state is MabLoading) {
            return _buildLoading();
          } else if (state is MabLoaded) {
            // Sync the pill to the state's month (in case a reload happened
            // elsewhere with a different month).
            if (state.month != 0 && (state.month != _month || state.year != _year)) {
              _month = state.month;
              _year = state.year;
            }
            return _buildLoaded(context, state);
          } else if (state is MabError) {
            return StateMessage.error(
              title: 'couldn\'t load your MAB forecast',
              message: 'Something went wrong while calculating your minimum balance. Try again.',
              onRetry: () {
                final now = DateTime.now();
                context.read<MabBloc>().add(
                      LoadMabStatus(month: _month, year: _year, now: now),
                    );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: RozzColors.gold),
    );
  }

  Widget _buildLoaded(BuildContext context, MabLoaded state) {
    final status = state.status;
    final records = state.records;

    return SingleChildScrollView(
      child: Column(
        children: [
          MabZoneBanner(zone: status.zone),
          MabStatsRow(status: status),
          MabChart(
            records: records,
            threshold: status.requiredMin,
            month: state.month == 0 ? _month : state.month,
            year: state.year == 0 ? _year : state.year,
          ),

          // Daily allowance card — computed from real MAB math, never
          // hardcoded amounts.
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RozzColors.s1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RozzColors.gold.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  status.isSafe ? Icons.check_circle_outline : Icons.lightbulb,
                  color: status.isSafe ? RozzColors.income : RozzColors.gold,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.isSafe
                            ? 'MAB secured this month'
                            : 'to maintain a safe MAB',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: status.isSafe ? RozzColors.income : RozzColors.gold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _allowanceLine(status),
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: RozzColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _buildFineCard(state),
        ],
      ),
    );
  }

  /// Likely MAB penalty for the selected month, from the HDFC-style schedule.
  /// Current month = estimate (month still running); past month = final.
  Widget _buildFineCard(MabLoaded state) {
    final status = state.status;
    final estimate = EstimateMabFine()(
      mab: status.currentMab,
      requiredMin: status.requiredMin,
    );
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final now = DateTime.now();
    final isCurrentMonth = now.month == state.month && now.year == state.year;

    final Color accent =
        estimate.hasShortfall ? RozzColors.expense : RozzColors.income;
    final String title = estimate.hasShortfall
        ? 'estimated penalty: ${currency.format(estimate.fine)}'
        : 'no penalty expected';
    final String subtitle = estimate.hasShortfall
        ? 'your monthly average is ${currency.format(estimate.mab)} — '
            '${estimate.shortfallPercent.toStringAsFixed(0)}% below the '
            '${currency.format(estimate.requiredMin)} minimum. '
            '${isCurrentMonth ? 'still estimating — the month isn\'t over yet.' : 'final for this month.'} '
            '${estimate.fine > 0 ? 'banks add 18% GST on top.' : ''}'
        : 'your monthly average ${currency.format(estimate.mab)} stays above the '
            '${currency.format(estimate.requiredMin)} minimum.';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            estimate.hasShortfall ? Icons.warning_amber_rounded : Icons.verified_outlined,
            color: accent,
            size: 22,
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
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.4,
                    color: RozzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _allowanceLine(MabStatus status) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    if (status.isSafe) {
      return 'your average ${currency.format(status.currentMab)} is above the ${currency.format(status.requiredMin)} minimum.';
    }
    if (status.remainingDays <= 0) {
      return 'today is the last day — end it above ${currency.format(status.requiredMin)}.';
    }
    return 'keep ${currency.format(status.minDailyNeeded)} in the account each day for the next ${status.remainingDays} days to reach the ${currency.format(status.requiredMin)} monthly average.';
  }
}
