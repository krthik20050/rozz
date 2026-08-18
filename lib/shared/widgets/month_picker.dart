import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';

/// Bottom-sheet month picker: lists the current month plus the five before it.
/// Returns the chosen `(month, year)` or `null` if dismissed.
Future<(int, int)?> showMonthPickerSheet(
  BuildContext context, {
  required int month,
  required int year,
}) async {
  final result = await showModalBottomSheet<(int, int)>(
    context: context,
    backgroundColor: RozzColors.s2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final now = DateTime.now();
      final options = <(int, int)>[];
      for (var i = 0; i < 6; i++) {
        final d = DateTime(now.year, now.month - i, 1);
        options.add((d.month, d.year));
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: RozzColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'select month',
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: RozzColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final (m, y) in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(sheetContext).pop((m, y));
                  },
                  title: Text(
                    DateFormat('MMMM yyyy').format(DateTime(y, m)).toLowerCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: m == month && y == year ? FontWeight.bold : FontWeight.w500,
                      color: m == month && y == year
                          ? RozzColors.gold
                          : RozzColors.textPrimary,
                    ),
                  ),
                  trailing: m == month && y == year
                      ? const Icon(Icons.check_circle, size: 18, color: RozzColors.gold)
                      : const Icon(Icons.chevron_right, size: 18, color: RozzColors.textMuted),
                ),
            ],
          ),
        ),
      );
    },
  );
  return result;
}
