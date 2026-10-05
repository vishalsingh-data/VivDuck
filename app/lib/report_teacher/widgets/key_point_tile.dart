import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Tile displaying a single [KeyPoint]:
/// - Status icon:
///   - Solid: filled blue circle with a tick
///   - Partial: half-filled circle
///   - Missing: dashed grey ring
/// - The statement text
/// - A status label pill ("Solid", "Partial", "Missing")
/// - Student quote: `'You said: "<quote>"'` (or "Not explained yet" if missing)
///
/// Status is fully readable without colour via distinct icon shapes and labels.
class KeyPointTile extends StatelessWidget {
  final KeyPoint keyPoint;

  const KeyPointTile(
    this.keyPoint, {
    super.key,
  });

  const KeyPointTile.named({
    super.key,
    required this.keyPoint,
  });

  KeyPoint get kp => keyPoint;

  @override
  Widget build(BuildContext context) {
    final blueColor =
        context.isDark ? const Color(0xFF93AAFF) : const Color(0xFF2450E0);
    final greyColor =
        context.isDark ? const Color(0xFF7E8BAA) : context.inkSoft;

    final isMissing = keyPoint.status == KeyPointStatus.missing;
    final hasQuote = keyPoint.evidenceQuote != null &&
        keyPoint.evidenceQuote!.trim().isNotEmpty;

    final String quoteText;
    if (isMissing || !hasQuote) {
      quoteText = 'Not explained yet';
    } else {
      quoteText = 'You said: "${keyPoint.evidenceQuote}"';
    }

    final String label;
    final Color badgeColor;
    switch (keyPoint.status) {
      case KeyPointStatus.solid:
        label = 'Solid';
        badgeColor = blueColor;
        break;
      case KeyPointStatus.partial:
        label = 'Partial';
        badgeColor = blueColor;
        break;
      case KeyPointStatus.missing:
        label = 'Missing';
        badgeColor = greyColor;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusIcon(
                status: keyPoint.status,
                blueColor: blueColor,
                greyColor: greyColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  keyPoint.statement,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.ink,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Pill(label, color: badgeColor),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: isMissing ? greyColor : blueColor,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                quoteText,
                style: TextStyle(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  color: context.inkSoft,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Accessible status icon with distinct shapes:
/// - solid: filled blue circle with a tick
/// - partial: half-filled circle
/// - missing or wrong: dashed grey ring
class _StatusIcon extends StatelessWidget {
  final KeyPointStatus status;
  final Color blueColor;
  final Color greyColor;

  const _StatusIcon({
    required this.status,
    required this.blueColor,
    required this.greyColor,
  });

  @override
  Widget build(BuildContext context) {
    const size = 24.0;
    switch (status) {
      case KeyPointStatus.solid:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: blueColor,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 16,
          ),
        );

      case KeyPointStatus.partial:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _HalfFilledCirclePainter(color: blueColor),
          ),
        );

      case KeyPointStatus.missing:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DashedRingPainter(color: greyColor),
          ),
        );
    }
  }
}

class _HalfFilledCirclePainter extends CustomPainter {
  final Color color;

  _HalfFilledCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Left half filled
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawArc(rect, -math.pi / 2, math.pi, true, fillPaint);

    // Outer stroke around the whole circle
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _HalfFilledCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DashedRingPainter extends CustomPainter {
  final Color color;

  _DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    const dashCount = 8;
    const step = (2 * math.pi) / dashCount;
    const sweep = step * 0.55;

    for (var i = 0; i < dashCount; i++) {
      final start = i * step;
      canvas.drawArc(rect, start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
