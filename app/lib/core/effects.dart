import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

// ── Confetti ─────────────────────────────────────────────────────────────────

class ConfettiController extends ChangeNotifier {
  int _shots = 0;
  Offset _origin = const Offset(0.5, 0.35);

  /// Fire a burst from [origin] (fractions of the confetti area).
  void fire({Offset origin = const Offset(0.5, 0.35)}) {
    _origin = origin;
    _shots++;
    notifyListeners();
  }
}

/// Overlays [child] with a confetti + feather burst whenever the controller fires.
class Confetti extends StatefulWidget {
  final ConfettiController controller;
  final Widget child;
  const Confetti({super.key, required this.controller, required this.child});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _Piece {
  final Offset velocity;
  final Color color;
  final double size, spin;
  final bool feather;
  _Piece(this.velocity, this.color, this.size, this.spin, this.feather);
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  final _rand = math.Random();
  List<_Piece> _pieces = const [];
  int _seen = 0;

  static const _colors = [
    VD.yellow,
    VD.orange,
    VD.teal,
    VD.solid,
    Color(0xFFFF9EC4),
    Color(0xFF8B5CF6),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onFire);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFire);
    _c.dispose();
    super.dispose();
  }

  void _onFire() {
    if (widget.controller._shots == _seen) return;
    _seen = widget.controller._shots;
    _pieces = List.generate(70, (i) {
      final a = -math.pi / 2 + (_rand.nextDouble() - 0.5) * math.pi * 1.1;
      final v = 380 + _rand.nextDouble() * 520;
      return _Piece(
        Offset(math.cos(a) * v, math.sin(a) * v),
        _colors[i % _colors.length],
        5 + _rand.nextDouble() * 6,
        (_rand.nextDouble() - 0.5) * 14,
        i % 7 == 0,
      );
    });
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => _c.isAnimating
                  ? CustomPaint(
                      painter: _ConfettiPainter(
                        _pieces,
                        _c.value,
                        widget.controller._origin,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  final Offset origin;
  _ConfettiPainter(this.pieces, this.t, this.origin);

  @override
  void paint(Canvas canvas, Size size) {
    final secs = t * 2.2;
    final o = Offset(origin.dx * size.width, origin.dy * size.height);
    final fade = t > 0.7 ? 1 - (t - 0.7) / 0.3 : 1.0;
    for (final p in pieces) {
      final drag = p.feather ? 0.35 : 1.0;
      final pos =
          o +
          Offset(
            p.velocity.dx * secs * 0.6 * drag +
                math.sin(secs * 4 + p.spin) * (p.feather ? 18 : 4),
            p.velocity.dy * secs * drag + 0.5 * 900 * secs * secs * drag,
          );
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(secs * p.spin);
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      if (p.feather) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size * 1.2,
            height: p.size * 3,
          ),
          paint..color = VD.yellow.withValues(alpha: fade),
        );
        canvas.drawLine(
          Offset(0, -p.size * 1.4),
          Offset(0, p.size * 1.4),
          Paint()
            ..color = const Color(0xFFE09A12).withValues(alpha: fade)
            ..strokeWidth = 1,
        );
      } else {
        // Flip in 3D by squashing one axis over time.
        canvas.scale(1, math.cos(secs * p.spin * 0.8).abs() + 0.15);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter o) => true;
}

// ── Count-up number ──────────────────────────────────────────────────────────

/// Animates a number from 0 (or [from]) to [value] when first shown.
class CountUp extends StatelessWidget {
  final num value;
  final num from;
  final String prefix, suffix;
  final int decimals;
  final TextStyle? style;
  final Duration duration;

  const CountUp(
    this.value, {
    super.key,
    this.from = 0,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.style,
    this.duration = const Duration(milliseconds: 1300),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from.toDouble(), end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) =>
          Text('$prefix${v.toStringAsFixed(decimals)}$suffix', style: style),
    );
  }
}

// ── Shine sweep ──────────────────────────────────────────────────────────────

/// Marks a primary button. It used to sweep a highlight across the button;
/// that read as decoration rather than function, so it now renders [child]
/// as is. Kept so call sites stay unchanged.
class Shine extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Duration every;
  const Shine({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.every = const Duration(milliseconds: 3200),
  });

  @override
  Widget build(BuildContext context) => child;
}

// ── Shake ────────────────────────────────────────────────────────────────────

/// Shakes [child] side to side whenever [signal] changes (e.g. on a wrong password).
class Shake extends StatefulWidget {
  final int signal;
  final Widget child;
  const Shake({super.key, required this.signal, required this.child});

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didUpdateWidget(covariant Shake old) {
    super.didUpdateWidget(old);
    if (old.signal != widget.signal) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          math.sin(_c.value * math.pi * 8) * 12 * (1 - _c.value),
          0,
        ),
        child: child,
      ),
    );
  }
}

// ── Bob ──────────────────────────────────────────────────────────────────────

/// Gently floats [child] up and down (and tilts it) like it's on water.
class Bob extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final double tilt;
  final Duration period;
  const Bob({
    super.key,
    required this.child,
    this.amplitude = 6,
    this.tilt = 0.006,
    this.period = const Duration(milliseconds: 4200),
  });

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final t = _c.value * math.pi * 2;
        return Transform.translate(
          offset: Offset(0, math.sin(t) * widget.amplitude),
          child: Transform.rotate(
            angle: math.sin(t + 1) * widget.tilt,
            child: child,
          ),
        );
      },
    );
  }
}
