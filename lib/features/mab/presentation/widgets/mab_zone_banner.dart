import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/features/mab/domain/entities/mab_status.dart';
import 'package:google_fonts/google_fonts.dart';

class MabZoneBanner extends StatelessWidget {
  final MabZone zone;
  const MabZoneBanner({super.key, required this.zone});

  @override
  Widget build(BuildContext context) {
    final config = _getZoneConfig(zone);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(color: config.color.withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: Center(
        child: Text(
          config.label,
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: config.color,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  _ZoneConfig _getZoneConfig(MabZone zone) {
    switch (zone) {
      case MabZone.safe:
        return _ZoneConfig(RozzColors.income, 'SAFE \u2705');
      case MabZone.middle:
        return _ZoneConfig(RozzColors.insight, 'WATCH \u26A1');
      case MabZone.danger:
        return _ZoneConfig(const Color(0xFFF0923A), 'ACT NOW \u26A0');
      case MabZone.fine:
        return _ZoneConfig(RozzColors.expense, 'FINE LIKELY \ud83d\udea8');
    }
  }
}

class _ZoneConfig {
  final Color color;
  final String label;
  _ZoneConfig(this.color, this.label);
}

