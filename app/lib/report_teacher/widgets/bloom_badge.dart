import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Badge displaying Bloom's taxonomy progress:
/// - Shows the level name reached.
/// - Three segments for "Understand", "Apply", and "Analyse",
///   filled up to the level reached.
class BloomBadge extends StatelessWidget {
  final String level;

  const BloomBadge(
    this.level, {
    super.key,
  });

  const BloomBadge.named({
    super.key,
    required this.level,
  });

  /// Segments represented in the badge.
  static const segments = ['Understand', 'Apply', 'Analyse'];

  /// Number of segments filled based on the reached level.
  int get filledSegments {
    final l = level.trim().toLowerCase();
    if (l == 'analyse' ||
        l == 'analyze' ||
        l == 'evaluate' ||
        l == 'create') {
      return 3;
    }
    if (l == 'apply') {
      return 2;
    }
    if (l == 'understand') {
      return 1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final blueColor =
        context.isDark ? const Color(0xFF93AAFF) : const Color(0xFF2450E0);
    final count = filledSegments;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Bloom\'s level',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.inkSoft,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Pill(
                level,
                color: blueColor,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < segments.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _SegmentItem(
                    name: segments[i],
                    isFilled: i < count,
                    color: blueColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final String name;
  final bool isFilled;
  final Color color;

  const _SegmentItem({
    required this.name,
    required this.isFilled,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: isFilled
            ? color
            : (context.isDark ? context.surface : context.bg),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFilled ? color : context.line,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isFilled) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 3),
              ],
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isFilled ? FontWeight.w800 : FontWeight.w600,
                  color: isFilled ? Colors.white : context.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
