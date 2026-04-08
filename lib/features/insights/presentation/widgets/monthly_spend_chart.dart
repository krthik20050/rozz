import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';

class MonthlySpendChart extends StatelessWidget {
  /// Each entry: {'month': int, 'year': int, 'debit': double, 'credit': double}
  final List<Map<String, dynamic>> monthlyData;

  const MonthlySpendChart({super.key, required this.monthlyData});

  @override
  Widget build(BuildContext context) {
    final maxDebit = monthlyData.fold<double>(
      0.0,
      (m, e) => (e['debit'] as double) > m ? e['debit'] as double : m,
    );
    final maxY = maxDebit > 0 ? maxDebit * 1.25 : 10000.0;

    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONTHLY SPEND',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: RozzColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        RozzColors.s3.withValues(alpha: 0.95),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final entry = monthlyData[group.x.toInt()];
                      final amount = entry['debit'] as double;
                      return BarTooltipItem(
                        '₹${NumberFormat('#,##,###').format(amount.round())}',
                        GoogleFonts.dmMono(
                          fontSize: 12,
                          color: RozzColors.expense,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= monthlyData.length) {
                          return const SizedBox.shrink();
                        }
                        final month = monthlyData[idx]['month'] as int;
                        final year = monthlyData[idx]['year'] as int;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('MMM')
                                .format(DateTime(year, month)),
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: RozzColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: monthlyData.asMap().entries.map((e) {
                  final debit = e.value['debit'] as double;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: debit,
                        color: debit > 0
                            ? RozzColors.expense.withValues(alpha: 0.85)
                            : RozzColors.s3,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
