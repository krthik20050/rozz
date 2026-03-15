import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class RozzTypography {
  static TextTheme get textTheme {
    return TextTheme(
      displayLarge: GoogleFonts.syne(
        fontSize: 56,
        fontWeight: FontWeight.bold,
        color: RozzColors.textPrimary,
      ),
      displayMedium: GoogleFonts.syne(
        fontSize: 32,
        fontWeight: FontWeight.bold,
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
      labelLarge: GoogleFonts.dmMono(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: RozzColors.textPrimary,
      ),
    );
  }

  static TextStyle get financialNumber => GoogleFonts.dmMono(
    color: RozzColors.textPrimary,
  );
}
