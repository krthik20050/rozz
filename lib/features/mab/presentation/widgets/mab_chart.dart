import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class MabChart extends StatelessWidget {
  final List<double> dailyBalances;
  final double threshold;

  const MabChart({
    super.key,
    required this.dailyBalances,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '30 DAY HISTORY',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: RozzColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: dailyBalances.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value);
                    }).toList(),
                    isCurved: true,
                    color: RozzColors.accent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          RozzColors.accent.withValues(alpha: 0.3),
                          RozzColors.accent.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: threshold,
                      color: RozzColors.textSecondary.withValues(alpha: 0.3),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                        style: GoogleFonts.dmMono(
                          fontSize: 10,
                          color: RozzColors.textSecondary,
                        ),
                        labelResolver: (line) => 'MIN \u20B9${threshold.toInt()}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

