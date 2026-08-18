import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a widget with a subtle scale-down on press and optional haptic
/// feedback. Micro-interaction research: press states + haptics make cards
/// feel responsive and build perceived quality in money apps.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;

  /// Scale applied while pressed (research: subtle beats dramatic).
  final double pressedScale;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.haptic = true,
    this.pressedScale = 0.97,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _pressed = true);
    if (widget.haptic) {
      HapticFeedback.selectionClick();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _pressed = false);
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : _handleTapDown,
      onTapUp: widget.onTap == null ? null : _handleTapUp,
      onTapCancel: widget.onTap == null ? null : _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
