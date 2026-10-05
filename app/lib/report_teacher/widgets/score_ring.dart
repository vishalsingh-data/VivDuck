import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Ring gauge with an outer blue ring for the score after,
/// a thinner grey ring inside it for the score before,
/// and the after score displayed as a big number in the centre.
///
/// When it first appears, animates the blue ring from before to after
/// over 1.2 seconds and counts the center number up with it.
class ScoreRing extends StatelessWidget {
  final int before;
  final int after;
  final double size;

  const ScoreRing({
    super.key,
    required this.before,
    required this.after,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    // Theme colors: VivDuck design blue and line/inkSoft grey.
    final blueColor =
        context.isDark ? const Color(0xFF93AAFF) : const Color(0xFF2450E0);
    final greyColor =
        context.isDark ? const Color(0xFF7E8BAA) : context.inkSoft;
    final trackColor = context.line;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: before.toDouble(), end: after.toDouble()),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, currentScore, _) {
        return SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _ScoreRingPainter(
              currentScore: currentScore,
              before: before.toDouble(),
              after: after.toDouble(),
              blueColor: blueColor,
              greyColor: greyColor,
              trackColor: trackColor,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${currentScore.round()}',
                    style: context.text.displayMedium?.copyWith(
                      fontSize: size * 0.28,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: context.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'out of 100',
                    style: TextStyle(
                      fontSize: size * 0.07,
                      color: context.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double currentScore;
  final double before;
  final double after;
  final Color blueColor;
  final Color greyColor;
  final Color trackColor;

  _ScoreRingPainter({
    required this.currentScore,
    required this.before,
    required this.after,
    required this.blueColor,
    required this.greyColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const startAngle = -math.pi / 2;

    // Stroke widths: outer blue ring is thick, inner grey ring is thinner.
    final outerStroke = size.width * 0.085;
    final innerStroke = size.width * 0.045;
    final gap = size.width * 0.025;

    final outerRadius = size.width / 2 - outerStroke / 2 - 2;
    final innerRadius =
        outerRadius - outerStroke / 2 - gap - innerStroke / 2;

    Paint strokePaint(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    // 1. Outer track (faint circular line)
    canvas.drawCircle(
      center,
      outerRadius,
      strokePaint(trackColor, outerStroke),
    );

    // 2. Outer blue ring for the score after (animates from before to after)
    final outerSweep =
        2 * math.pi * (currentScore / 100.0).clamp(0.0, 1.0);
    if (outerSweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        outerSweep,
        false,
        strokePaint(blueColor, outerStroke),
      );
    }

    // 3. Inner track (thinner faint circular line)
    canvas.drawCircle(
      center,
      innerRadius,
      strokePaint(trackColor.withValues(alpha: 0.6), innerStroke),
    );

    // 4. Thinner grey ring inside it for the score before
    final innerSweep = 2 * math.pi * (before / 100.0).clamp(0.0, 1.0);
    if (innerSweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        innerSweep,
        false,
        strokePaint(greyColor, innerStroke),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) =>
      oldDelegate.currentScore != currentScore ||
      oldDelegate.before != before ||
      oldDelegate.after != after ||
      oldDelegate.blueColor != blueColor ||
      oldDelegate.greyColor != greyColor ||
      oldDelegate.trackColor != trackColor;
}
