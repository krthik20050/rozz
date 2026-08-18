import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/shared/widgets/pressable.dart';

/// Plain bottom navigation bar — no glass, no floats. A fixed-height surface
/// pinned to the scaffold's bottom slot, so the body auto-insets above it.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTapTab;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTapTab,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: RozzColors.s1,
        border: Border(
          top: BorderSide(color: RozzColors.cardBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'home'),
          _buildNavItem(1, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'activity'),
          _buildNavItem(2, Icons.forum_rounded, Icons.forum_outlined, 'rozz'),
          _buildNavItem(3, Icons.insights_rounded, Icons.insights_outlined, 'insights'),
          _buildNavItem(4, Icons.shield_rounded, Icons.shield_outlined, 'mab'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = currentIndex == index;
    return Expanded(
      child: Semantics(
        selected: isSelected,
        label: label,
        child: PressableScale(
          onTap: () {
            if (!isSelected) HapticFeedback.selectionClick();
            onTapTab(index);
          },
          pressedScale: 0.9,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : inactiveIcon,
                size: 22,
                color: isSelected ? RozzColors.gold : RozzColors.textSecondary,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? RozzColors.gold : RozzColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? RozzColors.gold : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}