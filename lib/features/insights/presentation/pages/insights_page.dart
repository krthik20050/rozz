import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/insights/presentation/widgets/category_breakdown.dart';
import 'package:rozz/features/insights/presentation/widgets/monthly_spend_chart.dart';
import 'package:rozz/features/transactions/domain/entities/transaction.dart';
import 'package:rozz/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:rozz/shared/widgets/empty_state.dart';
import 'package:rozz/shared/widgets/error_state.dart';
import 'package:rozz/shared/widgets/shimmer_card.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  // ── Analytics helpers ────────────────────────────────────────────────────

  double _sumAmounts(List<Transaction> txs, String direction) =>
      txs.where((t) => t.direction == direction).fold(0.0, (s, t) => s + t.amount);

  List<Map<String, dynamic>> _buildMonthlyData(List<Transaction> txs) {
    final now = DateTime.now();
    return List.generate(6, (i) {
      int month = now.month - (5 - i);
      int year = now.year;
      if (month <= 0) {
        month += 12;
        year -= 1;
      }
      final monthTxs = txs.where((t) {
        final d = DateTime.parse(t.date).toLocal();
        return d.month == month && d.year == year;
      }).toList();
      return {
        'month': month,
        'year': year,
        'debit': _sumAmounts(monthTxs, 'debit'),
        'credit': _sumAmounts(monthTxs, 'credit'),
      };
    });
  }

  Map<String, double> _buildCategoryMap(List<Transaction> txs) {
    final now = DateTime.now();
    final thisMonth = txs.where((t) {
      final d = DateTime.parse(t.date).toLocal();
      return d.month == now.month && d.year == now.year && t.direction == 'debit';
    });
    final Map<String, double> map = {};
    for (final tx in thisMonth) {
      String cat;
      if (tx.category != null && tx.category!.isNotEmpty) {
        cat = tx.category!.toUpperCase();
      } else {
        cat = tx.labelType.replaceAll('_', ' ').toUpperCase();
      }
      map[cat] = (map[cat] ?? 0.0) + tx.amount;
    }
    return map;
  }

  Map<String, double> _buildPayeeMap(List<Transaction> txs) {
    final now = DateTime.now();
    final thisMonth = txs.where((t) {
      final d = DateTime.parse(t.date).toLocal();
      return d.month == now.month &&
          d.year == now.year &&
          t.direction == 'debit' &&
          t.recipientName != null;
    });
    final Map<String, double> map = {};
    for (final tx in thisMonth) {
      final name = tx.recipientName!;
      map[name] = (map[name] ?? 0.0) + tx.amount;
    }
    return map;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RozzColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'INSIGHTS',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: RozzColors.textPrimary,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          if (state is TransactionInitial || state is TransactionLoading) {
            return _buildLoading();
          } else if (state is TransactionError) {
            return ErrorState(message: state.message);
          } else if (state is TransactionLoaded) {
            if (state.transactions.isEmpty) {
              return const EmptyState();
            }
            return _buildLoaded(state.transactions);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: 4,
      itemBuilder: (_, __) => const ShimmerCard(),
    );
  }

  Widget _buildLoaded(List<Transaction> transactions) {
    final now = DateTime.now();
    final fmt = NumberFormat('#,##,###');

    // This month summary
    final thisMonthTxs = transactions.where((t) {
      final d = DateTime.parse(t.date).toLocal();
      return d.month == now.month && d.year == now.year;
    }).toList();

    final debit = thisMonthTxs
        .where((t) => t.direction == 'debit')
        .fold(0.0, (s, t) => s + t.amount);
    final credit = thisMonthTxs
        .where((t) => t.direction == 'credit')
        .fold(0.0, (s, t) => s + t.amount);
    final net = credit - debit;

    // Monthly chart data
    final monthlyData = _buildMonthlyData(transactions);

    // Category breakdown
    final catMap = _buildCategoryMap(transactions);
    final categories = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Top payees
    final payeeMap = _buildPayeeMap(transactions);
    final topPayees = (payeeMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();

    // Average daily spend this month
    final daysElapsed = now.day;
    final avgDaily = daysElapsed > 0 ? debit / daysElapsed : 0.0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── This month summary ───────────────────────────────────────────
          _buildSectionLabel('THIS MONTH'),
          _buildSummaryCard(
            debit: debit,
            credit: credit,
            net: net,
            avgDaily: avgDaily,
            fmt: fmt,
          ),

          // ── Monthly trend ─────────────────────────────────────────────────
          _buildSectionLabel('SPENDING TREND'),
          MonthlySpendChart(monthlyData: monthlyData),

          // ── Category breakdown ─────────────────────────────────────────────
          _buildSectionLabel('CATEGORIES'),
          CategoryBreakdown(
            categories: categories,
            totalSpend: debit,
          ),

          // ── Top payees ─────────────────────────────────────────────────────
          if (topPayees.isNotEmpty) ...[
            _buildSectionLabel('TOP PAYEES'),
            _buildTopPayees(topPayees, fmt),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: RozzColors.textSecondary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required double debit,
    required double credit,
    required double net,
    required double avgDaily,
    required NumberFormat fmt,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  label: 'SPENT',
                  value: '₹${fmt.format(debit.round())}',
                  color: RozzColors.expense,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatTile(
                  label: 'RECEIVED',
                  value: '₹${fmt.format(credit.round())}',
                  color: RozzColors.income,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  label: 'NET',
                  value:
                      '${net >= 0 ? '+' : '−'}₹${fmt.format(net.abs().round())}',
                  color: net >= 0 ? RozzColors.income : RozzColors.expense,
                  icon: net >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatTile(
                  label: 'AVG / DAY',
                  value: '₹${fmt.format(avgDaily.round())}',
                  color: RozzColors.insight,
                  icon: Icons.calendar_today_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: RozzColors.textSecondary,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.dmMono(
              fontSize: 15,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTopPayees(
    List<MapEntry<String, double>> payees,
    NumberFormat fmt,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: payees.asMap().entries.map((entry) {
          final idx = entry.key;
          final name = entry.value.key;
          final amount = entry.value.value;
          return Padding(
            padding: EdgeInsets.only(bottom: idx < payees.length - 1 ? 14 : 0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: RozzColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${idx + 1}',
                    style: GoogleFonts.dmMono(
                      fontSize: 13,
                      color: RozzColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: RozzColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${fmt.format(amount.round())}',
                  style: GoogleFonts.dmMono(
                    fontSize: 14,
                    color: RozzColors.expense,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
