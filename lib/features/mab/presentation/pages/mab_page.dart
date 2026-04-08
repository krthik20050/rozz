import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/mab/domain/entities/mab_status.dart';
import 'package:rozz/features/mab/presentation/bloc/mab_bloc.dart';
import 'package:rozz/features/mab/presentation/widgets/mab_zone_banner.dart';
import 'package:rozz/features/mab/presentation/widgets/mab_stats_row.dart';
import 'package:rozz/features/mab/presentation/widgets/mab_instruction_card.dart';
import 'package:rozz/features/mab/presentation/widgets/mab_chart.dart';
import 'package:rozz/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:rozz/shared/widgets/error_state.dart';
import 'package:google_fonts/google_fonts.dart';

class MabPage extends StatelessWidget {
  const MabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'MAB INTELLIGENCE',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: RozzColors.textPrimary,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<MabBloc, MabState>(
        builder: (context, state) {
          if (state is MabInitial || state is MabLoading) {
            return _buildLoading();
          } else if (state is MabLoaded) {
            return _buildLoaded(context, state);
          } else if (state is MabError) {
            return ErrorState(message: state.message);
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleRecordNow(context),
        label: Text('Record now', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        icon: const Icon(Icons.history),
        backgroundColor: RozzColors.accent,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _handleRecordNow(BuildContext context) {
    final txState = context.read<TransactionBloc>().state;
    if (txState is TransactionLoaded) {
      final balance = txState.currentBalance;
      if (balance != null) {
        context.read<MabBloc>().add(RecordEodBalance(balance));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recent balance found to record.')),
        );
      }
    }
  }

  Widget _buildLoading() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(height: 56, color: RozzColors.s1.withValues(alpha: 0.1)),
          const SizedBox(height: 32),
          Container(height: 80, width: 240, color: RozzColors.s1.withValues(alpha: 0.1)),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(height: 100, decoration: BoxDecoration(color: RozzColors.s1.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16))),
          ),
        ],
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, MabState state) {
    final status = (state as MabLoaded).status;
    final records = state.records;
    final dailyBalances = records.map((r) => r.endOfDayBalance).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          MabZoneBanner(zone: status.zone),
          MabStatsRow(status: status),
          MabInstructionCard(instruction: status.instruction),
          MabChart(
            dailyBalances: dailyBalances.isEmpty
                ? [status.currentMab > 0 ? status.currentMab : 0]
                : dailyBalances,
            threshold: status.requiredMin,
          ),
          const SizedBox(height: 24),
          _buildPredictionRow(status),
          const SizedBox(height: 100), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildPredictionRow(MabStatus status) {
    String text;
    IconData icon;
    Color color;

    switch (status.zone) {
      case MabZone.safe:
        text = 'You are safe for the rest of this month';
        icon = Icons.check_circle_outline;
        color = RozzColors.income;
        break;
      case MabZone.fine:
        text = 'Fine is very likely \u2014 top up immediately';
        icon = Icons.error_outline;
        color = RozzColors.expense;
        break;
      default:
        text = 'Minimum needed: \u20B9${status.minDailyNeeded.round()}/day for ${status.remainingDays} days';
        icon = Icons.info_outline;
        color = RozzColors.insight;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: RozzColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

