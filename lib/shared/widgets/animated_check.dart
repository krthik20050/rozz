import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';

/// A springy, scale-in green checkmark for success moments (e.g. a sender
/// label saved). Research: an animated confirmation builds trust in money apps.
class AnimatedCheck extends StatefulWidget {
  final double size;
  final Color color;

  const AnimatedCheck({
    super.key,
    this.size = 18,
    this.color = RozzColors.income,
  });

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _scale =
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.size + 8,
          height: widget.size + 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: widget.size, color: widget.color),
        ),
      ),
    );
  }
}
