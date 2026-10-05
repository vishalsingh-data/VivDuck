import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';

export 'widgets/score_ring.dart';


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
                          fontWeight: FontWeight.w900,
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
                              ? FontWeight.w900
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
