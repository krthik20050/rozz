import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rozz/core/theme/colors.dart';

/// A segmented control where a gold pill *slides* behind the selected label
/// instead of each chip merely recoloring. Positions are measured from the
/// chips themselves, so it stays correct inside a horizontally scrollable row
/// and works with labels of any width.
class SlidingPillBar extends StatefulWidget {
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool haptic;

  const SlidingPillBar({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.haptic = true,
  });

  @override
  State<SlidingPillBar> createState() => _SlidingPillBarState();
}

class _SlidingPillBarState extends State<SlidingPillBar> {
  final Map<String, GlobalKey> _keys = {};
  final Map<String, double> _widths = {};

  double _pillLeft = 0;
  double _pillWidth = 0;

  @override
  void initState() {
    super.initState();
    for (final label in widget.labels) {
      _keys[label] = GlobalKey();
      _widths[label] = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(SlidingPillBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-measure on selection change so the pill glides to the new label.
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  void _measure() {
    if (!mounted) return;
    double running = 0;
    var found = false;
    for (final label in widget.labels) {
      final box = _keys[label]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      if (label == widget.selected) {
        _pillLeft = running;
        _pillWidth = box.size.width;
        found = true;
      }
      running += box.size.width + _gap;
    }
    if (found && mounted) {
      setState(() {});
    }
  }

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Stack(
        children: [
          // The sliding pill sits behind the chips.
          Positioned(
            left: _pillLeft,
            top: 2,
            bottom: 2,
            width: _pillWidth,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: RozzColors.gold,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: RozzColors.gold.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              for (final label in widget.labels) ...[
                _buildChip(label),
                if (label != widget.labels.last) const SizedBox(width: _gap),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    final isSelected = widget.selected == label;
    return GestureDetector(
      key: _keys[label],
      onTap: () {
        if (widget.haptic) HapticFeedback.selectionClick();
        widget.onChanged(label);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : RozzColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
