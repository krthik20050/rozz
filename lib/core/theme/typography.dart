import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class RozzTypography {
  static TextTheme get textTheme {
    return TextTheme(
      displayLarge: GoogleFonts.syne(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: RozzColors.textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.syne(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: RozzColors.textPrimary,
        letterSpacing: -0.5,
      ),
      titleLarge: GoogleFonts.syne(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: RozzColors.textPrimary,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: RozzColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: RozzColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: RozzColors.textSecondary,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: RozzColors.textSecondary,
      ),
      labelLarge: GoogleFonts.dmMono(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: RozzColors.textPrimary,
      ),
    );
  }

  static TextStyle financialNumber({
    double fontSize = 48,
    FontWeight fontWeight = FontWeight.bold,
    Color color = RozzColors.textPrimary,
  }) {
    return GoogleFonts.dmMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -1.0,
    );
  }

  static TextStyle sectionHeader({Color color = RozzColors.textSecondary}) {
    return GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: color,
      letterSpacing: 1.5,
    );
  }
}
