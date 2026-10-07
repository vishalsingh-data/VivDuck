import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'charts.dart';

/// Every rubric point with its weight, status, the grader's comment and the
/// student's own words that earned it. Nothing is hidden behind a tap: the
/// evidence is the point of the grade.
class RubricPointsCard extends StatelessWidget {
  final List<KeyPoint> points;
  final String title;
  final String? subtitle;

  const RubricPointsCard({
    super.key,
    required this.points,
    this.title = 'Rubric',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    int count(KeyPointStatus s) => points.where((k) => k.status == s).length;
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: context.text.titleLarge)),
              Text(
                '${points.length} points · weighted ×1 to ×3',
                style: TextStyle(color: context.inkSoft, fontSize: 13),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(color: context.inkSoft)),
          ],
          const SizedBox(height: 14),
          StatusBar(
            solid: count(KeyPointStatus.solid),
            partial: count(KeyPointStatus.partial),
            missing: count(KeyPointStatus.missing),
          ),
          const SizedBox(height: 10),
          for (final p in points) RubricPointTile(point: p),
        ],
      ),
    );
  }
}

class RubricPointTile extends StatelessWidget {
  final KeyPoint point;
  const RubricPointTile({super.key, required this.point});

  @override
  Widget build(BuildContext context) {
    final p = point;
    final c = statusColor(p.status);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(statusIcon(p.status), color: c, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        p.statement,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      label: 'Weight ${p.weight}',
                      child: Text(
                        '×${p.weight}',
                        style: TextStyle(
                          color: context.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Pill(statusLabel(p.status), color: c),
                    if (p.comment != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.comment!,
                          style: TextStyle(
                            color: context.inkSoft,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (p.evidenceQuote != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: context.isDark ? 0.08 : 0.05),
                      border: Border(left: BorderSide(color: c, width: 3)),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Your words: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: context.inkSoft,
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                          TextSpan(text: '“${p.evidenceQuote}”'),
                        ],
                      ),
                      style: TextStyle(
                        color: context.ink,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Needs teacher review" with the reasons beside it.
class ReviewBanner extends StatelessWidget {
  final Review review;
  final bool forTeacher;
  const ReviewBanner({
    super.key,
    required this.review,
    this.forTeacher = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!review.needsReview) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VD.partial.withValues(alpha: context.isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(VD.radius),
        border: Border.all(color: VD.partial.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_rounded, color: VD.partial, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forTeacher
                      ? 'Needs review'
                      : 'Flagged for your teacher to check',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                for (final r in review.reasons)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      r.message,
                      style: TextStyle(color: context.inkSoft, height: 1.45),
                    ),
                  ),
                if (!forTeacher) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Your score stands for now. Your teacher may adjust it.',
                    style: TextStyle(color: context.inkSoft, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Graded twice: 74 and 78" — the consistency check, stated plainly.
class GradingRunsNote extends StatelessWidget {
  final List<int> runs;
  const GradingRunsNote({super.key, required this.runs});

  @override
  Widget build(BuildContext context) {
    if (runs.length < 2) return const SizedBox.shrink();
    final diff = (runs[0] - runs[1]).abs();
    final ok = diff <= 10;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.done_all_rounded : Icons.compare_arrows_rounded,
          size: 16,
          color: ok ? VD.solid : VD.partial,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Graded twice: ${runs[0]} and ${runs[1]}'
            '${ok ? ' (consistent)' : ' ($diff apart)'}',
            style: TextStyle(color: context.inkSoft, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
