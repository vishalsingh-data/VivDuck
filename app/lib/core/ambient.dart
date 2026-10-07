import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Quiet brand atmosphere for working screens: slow-drifting aurora glows in
/// duck yellow, beak orange and pond teal over a faint dot grid. Sits behind
/// [child] and never takes pointer events.
class Ambient extends StatefulWidget {
  final Widget child;
  const Ambient({super.key, required this.child});

  @override
  State<Ambient> createState() => _AmbientState();
}

class _AmbientState extends State<Ambient> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) _clock.stop();
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _AuroraPainter(
                      clock: _clock,
                      dark: context.isDark,
                      bg: context.bg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final Animation<double> clock;
  final bool dark;
  final Color bg;
  _AuroraPainter({required this.clock, required this.dark, required this.bg})
    : super(repaint: clock);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    final t = clock.value * math.pi * 2;
    final r = math.max(size.width, size.height);
    // (anchor x, anchor y, radius factor, colour, alpha, phase)
    final blobs = [
      // Barely there: enough warmth that pages aren't flat grey, no more.
      (0.12, 0.0, 0.55, VD.yellow, dark ? 0.05 : 0.08, 0.0),
      (0.92, 0.10, 0.50, VD.teal, dark ? 0.06 : 0.04, 2.1),
    ];
    for (final (ax, ay, rf, color, a, phase) in blobs) {
      final c = Offset(
        size.width * (ax + 0.05 * math.sin(t + phase)),
        size.height * (ay + 0.05 * math.cos(t * 0.8 + phase)),
      );
      final radius = r * rf;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: a),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.dark != dark || old.bg != bg;
}

/// Fades and rises [child] in the first time it scrolls into view.
class Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const Reveal({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );
  ScrollPosition? _position;
  bool _checkQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_queueCheck);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.addListener(_queueCheck);
    _queueCheck();
  }

  // Scroll listeners fire before the new frame is laid out, so measuring
  // straight away reads last frame's position and can miss the final scroll.
  // Measure once layout for the frame is done instead.
  void _queueCheck() {
    if (_checkQueued) return;
    _checkQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQueued = false;
      _check();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _check() {
    if (!mounted || _c.isAnimating || _c.isCompleted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final viewport = MediaQuery.sizeOf(context).height;
    if (top < viewport - 40) {
      _position?.removeListener(_queueCheck);
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_queueCheck);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - _a.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Small uppercase label that sits above a section heading.
class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;
  const Eyebrow(this.text, {super.key, this.color = VD.orange});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Paints [child] text with a brand gradient.
class GradientText extends StatelessWidget {
  final Widget child;
  final List<Color> colors;
  const GradientText({
    super.key,
    required this.child,
    this.colors = const [VD.orange, VD.yellow],
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(colors: colors).createShader(r),
      child: child,
    );
  }
}
