import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';

/// Ring gauge showing the score before (faint) and after (bold) the viva,
/// animating from zero on first build.
class ScoreRing extends StatelessWidget {
  final int before, after;
  final double size;
  const ScoreRing({
    super.key,
    required this.before,
    required this.after,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final shownBefore = before * math.min(1, t * 1.6);
        final shownAfter = after * t;
        return SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              before: shownBefore / 100,
              after: shownAfter / 100,
              track: context.line,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shownAfter.round().toString(),
                    style: context.text.displayMedium?.copyWith(
                      fontSize: size * 0.27,
                      height: 1,
                    ),
                  ),
                  Text(
                    'out of 100',
                    style: TextStyle(
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

class _RingPainter extends CustomPainter {
  final double before, after;
  final Color track;
  _RingPainter({
    required this.before,
    required this.after,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2 + 2);
    const start = -math.pi / 2;
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(r, 0, math.pi * 2, false, p(track));
    canvas.drawArc(
      r,
      start,
      math.pi * 2 * after,
      false,
      p(VD.solid)
        ..shader = const SweepGradient(
          colors: [VD.yellow, VD.orange, VD.solid, VD.yellow],
          stops: [0, 0.35, 0.8, 1],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(r),
    );
    // Marker where the "before" score sat
    final a = start + math.pi * 2 * before;
    final c = r.center + Offset(math.cos(a), math.sin(a)) * (r.width / 2);
    canvas.drawCircle(c, stroke * 0.42, Paint()..color = Colors.white);
    canvas.drawCircle(c, stroke * 0.28, Paint()..color = VD.inkSoft);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) =>
      o.before != before || o.after != after || o.track != track;
}

/// Vertical Bloom's taxonomy ladder with the reached level highlighted.
class BloomLadder extends StatelessWidget {
  final String reached;
  const BloomLadder({super.key, required this.reached});

  @override
  Widget build(BuildContext context) {
    final idx = bloomIndex(reached);
    return Column(
      children: [
        for (var i = bloomLevels.length - 1; i >= 0; i--)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: i <= idx ? 1 : 0),
            duration: Duration(milliseconds: 400 + i * 140),
            curve: Curves.easeOutBack,
            builder: (context, t, _) {
              final on = i <= idx;
              final current = i == idx;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: on
                      ? Color.lerp(
                          context.bg,
                          VD.teal.withValues(alpha: 0.16 + i * 0.06),
                          t,
                        )
                      : context.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: current ? Border.all(color: VD.teal, width: 2) : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: on
                              ? VD.teal
                              : context.inkSoft.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        bloomLevels[i],
                        style: TextStyle(
                          fontWeight: current
                              ? FontWeight.w700
                              : FontWeight.w700,
                          color: on
                              ? context.ink
                              : context.inkSoft.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    if (current)
                      Transform.scale(
                        scale: t.clamp(0, 1.2),
                        child: const Icon(
                          Icons.flag_rounded,
                          color: VD.teal,
                          size: 18,
                        ),
                      )
                    else if (on)
                      const Icon(Icons.check_rounded, color: VD.teal, size: 16),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Horizontal stacked bar of solid / partial / missing counts.
class StatusBar extends StatelessWidget {
  final int solid, partial, missing;
  const StatusBar({
    super.key,
    required this.solid,
    required this.partial,
    required this.missing,
  });

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, solid + partial + missing);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: 12,
          child: Row(
            children: [
              for (final (n, c) in [
                (solid, VD.solid),
                (partial, VD.partial),
                (missing, VD.missing),
              ])
                if (n > 0)
                  Expanded(
                    flex: (n * 1000 * t).round() + 1,
                    child: Container(color: c),
                  ),
              Expanded(
                flex: ((1 - t) * total * 1000).round() + 1,
                child: Container(color: context.line),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled horizontal bar that grows to [value] (0..1).
class GrowBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  final Duration delay;

  /// Track colour; defaults to the theme line colour. Pass transparent to overlay bars.
  final Color? track;
  const GrowBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 10,
    this.delay = Duration.zero,
    this.track,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 900) + delay,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: track ?? context.line,
          color: color,
        ),
      ),
    );
  }
}

Color statusColor(KeyPointStatus s) => switch (s) {
  KeyPointStatus.solid => VD.solid,
  KeyPointStatus.partial => VD.partial,
  KeyPointStatus.missing => VD.missing,
};

IconData statusIcon(KeyPointStatus s) => switch (s) {
  KeyPointStatus.solid => Icons.check_circle_rounded,
  KeyPointStatus.partial => Icons.adjust_rounded,
  KeyPointStatus.missing => Icons.radio_button_unchecked_rounded,
};

String statusLabel(KeyPointStatus s) => switch (s) {
  KeyPointStatus.solid => 'Solid',
  KeyPointStatus.partial => 'Partial',
  KeyPointStatus.missing => 'Missing',
};
