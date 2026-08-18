import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rozz/core/theme/colors.dart';
import 'package:rozz/core/theme/typography.dart';

/// Counts up to [value] with a rolling number effect. When the value changes,
/// it rolls from the PREVIOUS value to the new one (a balance dropping from
/// ₹5000 to ₹3000 rolls down), instead of restarting from zero every time.
class AnimatedCounterText extends StatefulWidget {
  final double value;
  final double fontSize;
  final Color color;

  const AnimatedCounterText({
    super.key,
    required this.value,
    this.fontSize = 48,
    this.color = RozzColors.textPrimary,
  });

  @override
  State<AnimatedCounterText> createState() => _AnimatedCounterTextState();
}

class _AnimatedCounterTextState extends State<AnimatedCounterText> {
  double _previous = 0;
  late double _tweenEnd = widget.value;

  @override
  void didUpdateWidget(AnimatedCounterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previous = _tweenEnd;
      _tweenEnd = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _previous, end: _tweenEnd),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
        final formatted = formatter.format(animValue);

        // Split integer and decimal parts for refined visual hierarchy
        final parts = formatted.split('.');
        final mainPart = parts[0];
        final decimalPart = parts.length > 1 ? parts[1] : '00';

        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: mainPart,
                style: RozzTypography.financialNumber(
                  fontSize: widget.fontSize,
                  color: widget.color,
                ),
              ),
              TextSpan(
                text: '.$decimalPart',
                style: RozzTypography.financialNumber(
                  fontSize: widget.fontSize * 0.6,
                  color: widget.color.withOpacity(0.6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
