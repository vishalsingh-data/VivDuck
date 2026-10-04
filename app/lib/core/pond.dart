import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Lets screens drop ripples onto the pond (e.g. on every keystroke).
class PondController extends ChangeNotifier {
  final List<_Ripple> _ripples = [];

  /// Add a ripple at [x] (0..1 across the width). Optional [y] is 0..1 within
  /// the water band (0 = surface). Defaults to the surface.
  void ripple(double x, {double y = 0, double strength = 1}) {
    _ripples.add(_Ripple(x, y, strength, DateTime.now()));
    if (_ripples.length > 24) _ripples.removeAt(0);
    notifyListeners();
  }
}

class _Ripple {
  final double x, y, strength;
  final DateTime born;
  _Ripple(this.x, this.y, this.strength, this.born);
}

/// A living pond backdrop: sky (sun + clouds by day, moon + stars at night),
/// layered waves, rising bubbles, bobbing lily pads and tap ripples.
class PondBackground extends StatefulWidget {
  /// Fraction of the height covered by water, measured from the bottom.
  final double waterLevel;

  /// Fixed water depth in pixels; overrides [waterLevel] when set.
  final double? waterHeight;
  final PondController? controller;
  final bool showSky;
  final Widget? child;

  const PondBackground({
    super.key,
    this.waterLevel = 0.3,
    this.waterHeight,
    this.controller,
    this.showSky = true,
    this.child,
  });

  @override
  State<PondBackground> createState() => _PondBackgroundState();
}

class _PondBackgroundState extends State<PondBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();
  late final PondController _ctrl = widget.controller ?? PondController();
  final _seed = math.Random(7);
  late final List<_Bubble> _bubbles = List.generate(
    16,
    (_) => _Bubble(
      _seed.nextDouble(),
      _seed.nextDouble(),
      0.4 + _seed.nextDouble() * 0.8,
      1.5 + _seed.nextDouble() * 3,
    ),
  );
  late final List<Offset> _stars = List.generate(
    40,
    (_) => Offset(_seed.nextDouble(), _seed.nextDouble()),
  );

  @override
  void dispose() {
    _clock.dispose();
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return LayoutBuilder(
      builder: (context, box) {
        final level = widget.waterHeight == null
            ? widget.waterLevel
            : (widget.waterHeight! / box.maxHeight).clamp(0.0, 1.0);
        final surfaceY = box.maxHeight * (1 - level);
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            if (e.localPosition.dy > surfaceY - 10) {
              _ctrl.ripple(
                e.localPosition.dx / box.maxWidth,
                y:
                    ((e.localPosition.dy - surfaceY) /
                            (box.maxHeight - surfaceY))
                        .clamp(0, 1),
              );
            }
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PondPainter(
                      clock: _clock,
                      controller: _ctrl,
                      waterLevel: level,
                      dark: dark,
                      showSky: widget.showSky,
                      bubbles: _bubbles,
                      stars: _stars,
                    ),
                  ),
                ),
              ),
              if (widget.child != null) Positioned.fill(child: widget.child!),
            ],
          ),
        );
      },
    );
  }
}

class _Bubble {
  final double x, offset, speed, radius;
  _Bubble(this.x, this.offset, this.speed, this.radius);
}

class _PondPainter extends CustomPainter {
  final AnimationController clock;
  final PondController controller;
  final double waterLevel;
  final bool dark, showSky;
  final List<_Bubble> bubbles;
  final List<Offset> stars;

  _PondPainter({
    required this.clock,
    required this.controller,
    required this.waterLevel,
    required this.dark,
    required this.showSky,
    required this.bubbles,
    required this.stars,
  }) : super(repaint: Listenable.merge([clock, controller]));

  double get _t => clock.value * 60; // seconds

  /// Height of the water surface at x for a wave layer.
  double _wave(
    double x,
    double w,
    double base,
    double amp,
    double speed,
    double k,
  ) =>
      base +
      math.sin(x / w * math.pi * 2 * k + _t * speed) * amp +
      math.sin(x / w * math.pi * 2 * k * 2.3 - _t * speed * 0.7) * amp * 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    final surface = size.height * (1 - waterLevel);

    if (showSky) _paintSky(canvas, size, surface);

    // Lily pads sit on the back wave
    _paintWaveLayer(
      canvas,
      size,
      base: surface - 6,
      amp: 6,
      speed: 0.6,
      k: 1.2,
      colors: dark
          ? [const Color(0xFF1C4A55), const Color(0xFF12313B)]
          : [const Color(0xFF9FE0DA), const Color(0xFF6CCBC4)],
    );
    _paintLilyPads(canvas, size, surface);
    _paintWaveLayer(
      canvas,
      size,
      base: surface + 10,
      amp: 8,
      speed: -0.9,
      k: 0.9,
      colors: dark
          ? [
              const Color(0xFF17404B).withValues(alpha: 0.95),
              const Color(0xFF0E2830),
            ]
          : [
              const Color(0xFF6FD0C8).withValues(alpha: 0.95),
              const Color(0xFF3FB5AE),
            ],
    );
    _paintBubbles(canvas, size, surface);
    _paintWaveLayer(
      canvas,
      size,
      base: surface + 30,
      amp: 10,
      speed: 1.2,
      k: 0.7,
      colors: dark
          ? [
              const Color(0xFF123540).withValues(alpha: 0.95),
              const Color(0xFF0A1F27),
            ]
          : [VD.teal.withValues(alpha: 0.9), const Color(0xFF168C88)],
      glints: true,
    );
    _paintRipples(canvas, size, surface);
  }

  void _paintSky(Canvas canvas, Size size, double surface) {
    final w = size.width;
    final rect = Offset.zero & Size(w, surface + 20);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [
                  const Color(0xFF0B1022),
                  const Color(0xFF162040),
                  const Color(0xFF1B2C48),
                ]
              : [
                  const Color(0xFFFFF6DE),
                  const Color(0xFFFFFBF2),
                  const Color(0xFFE9F7F4),
                ],
        ).createShader(rect),
    );

    // Sun or moon with a soft breathing glow
    final orb = Offset(w * 0.82, surface * 0.22);
    final glow = 1 + math.sin(_t * 0.8) * 0.06;
    canvas.drawCircle(
      orb,
      90 * glow,
      Paint()
        ..shader = RadialGradient(
          colors: dark
              ? [
                  const Color(0xFFDDE6FF).withValues(alpha: 0.18),
                  Colors.transparent,
                ]
              : [VD.yellow.withValues(alpha: 0.45), Colors.transparent],
        ).createShader(Rect.fromCircle(center: orb, radius: 90 * glow)),
    );
    canvas.drawCircle(
      orb,
      28,
      Paint()..color = dark ? const Color(0xFFF1F4FF) : const Color(0xFFFFD45C),
    );
    if (dark) {
      // Crescent bite
      canvas.drawCircle(
        orb.translate(10, -6),
        24,
        Paint()..color = const Color(0xFF111833),
      );
      for (final s in stars) {
        final tw = (math.sin(_t * 1.5 + s.dx * 40) + 1) / 2;
        canvas.drawCircle(
          Offset(s.dx * w, s.dy * surface * 0.85),
          0.6 + tw * 1.2,
          Paint()..color = Colors.white.withValues(alpha: 0.25 + tw * 0.6),
        );
      }
    } else {
      // Drifting clouds
      for (var i = 0; i < 3; i++) {
        final speed = 6.0 + i * 3;
        final x = ((_t * speed + i * 420) % (w + 300)) - 150;
        final y = surface * (0.18 + i * 0.16);
        _cloud(canvas, Offset(x, y), 0.8 + i * 0.25);
      }
    }
  }

  void _cloud(Canvas canvas, Offset c, double scale) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (final (dx, dy, r) in const [
      (0.0, 0.0, 22.0),
      (24.0, -8.0, 26.0),
      (50.0, 0.0, 20.0),
      (24.0, 8.0, 20.0),
    ]) {
      canvas.drawCircle(c + Offset(dx * scale, dy * scale), r * scale, p);
    }
  }

  void _paintWaveLayer(
    Canvas canvas,
    Size size, {
    required double base,
    required double amp,
    required double speed,
    required double k,
    required List<Color> colors,
    bool glints = false,
  }) {
    final w = size.width, h = size.height;
    final path = Path()..moveTo(0, h);
    for (double x = 0; x <= w + 8; x += 8) {
      path.lineTo(x, _wave(x, w, base, amp, speed, k));
    }
    path
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(Rect.fromLTWH(0, base - amp, w, h - base + amp)),
    );
    // Foam line on the crest
    final crest = Path();
    for (double x = 0; x <= w + 8; x += 8) {
      final y = _wave(x, w, base, amp, speed, k);
      x == 0 ? crest.moveTo(x, y) : crest.lineTo(x, y);
    }
    canvas.drawPath(
      crest,
      Paint()
        ..color = Colors.white.withValues(alpha: dark ? 0.08 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (glints) {
      for (var i = 0; i < 10; i++) {
        final x = (i * 0.11 + 0.03) * w;
        final a = (math.sin(_t * 2 + i * 1.7) + 1) / 2;
        final y = _wave(x, w, base, amp, speed, k) + 14 + (i % 3) * 16;
        canvas.drawLine(
          Offset(x - 8 * a, y),
          Offset(x + 8 * a, y),
          Paint()
            ..color = Colors.white.withValues(alpha: a * (dark ? 0.15 : 0.35))
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _paintLilyPads(Canvas canvas, Size size, double surface) {
    final w = size.width;
    for (final (fx, r, flower) in const [
      (0.12, 22.0, true),
      (0.38, 15.0, false),
      (0.66, 19.0, false),
      (0.9, 25.0, true),
    ]) {
      final drift = math.sin(_t * 0.3 + fx * 10) * 12;
      final x = fx * w + drift;
      final y = _wave(x, w, surface - 6, 6, 0.6, 1.2) + 2;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(_t * 0.4 + fx * 7) * 0.15);
      canvas.scale(1, 0.38);
      final pad = Path()
        ..moveTo(0, 0)
        ..arcTo(
          Rect.fromCircle(center: Offset.zero, radius: r),
          -1.2,
          math.pi * 2 - 0.5,
          false,
        )
        ..close();
      canvas.drawPath(
        pad,
        Paint()
          ..color = dark ? const Color(0xFF2E6B47) : const Color(0xFF5DBB63),
      );
      canvas.drawPath(
        pad,
        Paint()
          ..color = dark ? const Color(0xFF3F8A5C) : const Color(0xFF7FD083)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.restore();
      if (flower) {
        final fp = Paint()..color = const Color(0xFFFF9EC4);
        for (var i = 0; i < 5; i++) {
          final a = i / 5 * math.pi * 2 + _t * 0.2;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x + math.cos(a) * 5, y - 5 + math.sin(a) * 2.2),
              width: 7,
              height: 5,
            ),
            fp,
          );
        }
        canvas.drawCircle(Offset(x, y - 5), 2.6, Paint()..color = VD.yellow);
      }
    }
  }

  void _paintBubbles(Canvas canvas, Size size, double surface) {
    final w = size.width, h = size.height;
    final depth = h - surface;
    if (depth < 30) return;
    for (final b in bubbles) {
      final p = (b.offset + _t * 0.06 * b.speed) % 1.0; // 0 bottom → 1 surface
      final y = h - p * (depth - 16);
      final x = b.x * w + math.sin(_t * 1.3 + b.offset * 12) * 6;
      final fade = p > 0.85 ? (1 - p) / 0.15 : (p < 0.1 ? p / 0.1 : 1.0);
      canvas.drawCircle(
        Offset(x, y),
        b.radius,
        Paint()
          ..color = Colors.white.withValues(alpha: (dark ? 0.18 : 0.45) * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.drawCircle(
        Offset(x - b.radius * 0.35, y - b.radius * 0.35),
        b.radius * 0.25,
        Paint()
          ..color = Colors.white.withValues(alpha: (dark ? 0.25 : 0.6) * fade),
      );
    }
  }

  void _paintRipples(Canvas canvas, Size size, double surface) {
    final now = DateTime.now();
    final depth = size.height - surface;
    controller._ripples.removeWhere(
      (r) => now.difference(r.born).inMilliseconds > 1800,
    );
    for (final r in controller._ripples) {
      final age = now.difference(r.born).inMilliseconds / 1800;
      final center = Offset(r.x * size.width, surface + 8 + r.y * (depth - 8));
      for (var i = 0; i < 3; i++) {
        final a = age - i * 0.12;
        if (a <= 0) continue;
        final radius = 6 + a * 70 * r.strength;
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: radius * 2,
            height: radius * 0.7,
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: (1 - a).clamp(0, 1) * 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * (1 - a).clamp(0.2, 1),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PondPainter o) =>
      o.dark != dark || o.waterLevel != waterLevel || o.showSky != showSky;
}
