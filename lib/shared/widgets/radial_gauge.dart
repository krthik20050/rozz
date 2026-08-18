import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rozz/core/theme/colors.dart';

class RadialGauge extends StatelessWidget {
  final double percentage; // 0 to 100
  final String statusText;
  final Color statusColor;

  const RadialGauge({
    super.key,
    required this.percentage,
    this.statusText = "you're safe",
    this.statusColor = RozzColors.income,
  });

  @override
  Widget build(BuildContext context) {
    final clampedPct = percentage.clamp(0.0, 100.0);

    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: clampedPct / 100),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (context, progress, child) {
              return CustomPaint(
                size: const Size(130, 130),
                painter: _RadialGaugePainter(progress: progress),
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${clampedPct.round()}%',
                style: GoogleFonts.syne(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: RozzColors.textPrimary,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: RozzColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadialGaugePainter extends CustomPainter {
  final double progress;

  _RadialGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 10.0;

    // Start angle from 135 deg to 405 deg (270 deg sweep)
    const startAngle = 135 * (pi / 180);
    const totalSweep = 270 * (pi / 180);

    // 1. Background Arc Track
    final bgPaint = Paint()
      ..color = RozzColors.s2
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      bgPaint,
    );

    if (progress <= 0) return;

    // 2. Active Progress Arc with Gradient & Glow
    final activeSweep = totalSweep * progress;

    final glowPaint = Paint()
      ..shader = SweepGradient(
        colors: const [RozzColors.accent, RozzColors.gold, RozzColors.goldLight],
        startAngle: startAngle,
        endAngle: startAngle + activeSweep,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..shader = SweepGradient(
        colors: const [RozzColors.accent, RozzColors.gold, RozzColors.goldLight],
        startAngle: startAngle,
        endAngle: startAngle + activeSweep,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      activeSweep,
      false,
      glowPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      activeSweep,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
