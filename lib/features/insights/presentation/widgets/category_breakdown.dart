import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';

/// Horizontal bar list showing spend broken down by category.
class CategoryBreakdown extends StatelessWidget {
  /// Sorted list of {name: String, amount: double} descending by amount.
  final List<MapEntry<String, double>> categories;
  final double totalSpend;

  const CategoryBreakdown({
    super.key,
    required this.categories,
    required this.totalSpend,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final fmt = NumberFormat('#,##,###');
    final top = categories.take(8).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SPEND BY CATEGORY',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: RozzColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ...top.asMap().entries.map((entry) {
            final idx = entry.key;
            final name = entry.value.key;
            final amount = entry.value.value;
            final ratio =
                totalSpend > 0 ? (amount / totalSpend).clamp(0.0, 1.0) : 0.0;
            final color = _categoryColor(idx);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: RozzColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${fmt.format(amount.round())}',
                        style: GoogleFonts.dmMono(
                          fontSize: 13,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        Container(
                          height: 4,
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: RozzColors.s3,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Container(
                          height: 4,
                          width: constraints.maxWidth * ratio,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static Color _categoryColor(int index) {
    const colors = [
      RozzColors.accent,
      RozzColors.insight,
      RozzColors.income,
      RozzColors.expense,
      Color(0xFF64B5F6),
      Color(0xFFBA68C8),
      Color(0xFF4DB6AC),
      Color(0xFFFFB74D),
    ];
    return colors[index % colors.length];
  }
}
