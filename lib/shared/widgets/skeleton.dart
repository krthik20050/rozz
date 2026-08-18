import 'package:flutter/material.dart';
import 'package:rozz/core/theme/colors.dart';

/// Skeleton placeholder colors — slightly lighter than the card surface so
/// the blocks read as "waiting content" against `s1` cards.
const Color skeletonBase = Color(0xFF1E1E2C);
const Color skeletonHighlight = Color(0xFF2A2A3E);

/// Wraps skeleton blocks in a slow, left-to-right shimmer sweep. Research
/// (UX Collective, 2018) found slow steady shimmer reads faster than pulses.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Sweep from left to right across the child's bounds.
        final begin = Alignment(-2.0 + 4.0 * t, -0.5);
        final end = Alignment(-1.0 + 4.0 * t, 0.5);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: begin,
            end: end,
            colors: const [
              skeletonBase,
              skeletonHighlight,
              skeletonBase,
            ],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A rounded placeholder block.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: skeletonBase,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// A circular placeholder (avatars, brand marks).
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: skeletonBase,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A text-line placeholder.
class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonLine({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(height / 2),
    );
  }
}

/// A full-bleed skeleton card matching the app's standard card chrome, so
/// placeholders look like the content that is coming.
class SkeletonCard extends StatelessWidget {
  final EdgeInsets padding;
  final Widget child;

  const SkeletonCard({
    super.key,
    this.padding = const EdgeInsets.all(20),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: RozzColors.s1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RozzColors.cardBorder),
      ),
      child: child,
    );
  }
}
