import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class MabInstructionCard extends StatelessWidget {
  final String instruction;
  const MabInstructionCard({super.key, required this.instruction});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RozzColors.s2,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: RozzColors.accent, width: 4),
        ),
      ),
      child: Text(
        instruction,
        style: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: RozzColors.textPrimary,
          height: 1.4,
        ),
      ),
    );
  }
}
