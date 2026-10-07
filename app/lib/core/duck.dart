import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// [shy] covers its eyes with a wing — used while a password is being typed.
/// [playful] is for trickier questions: bright eyes, a raised brow and a
/// twinkle, so a hard question feels like a game rather than a threat.
enum DuckMood { idle, thinking, curious, playful, happy, shy }

/// Last known pointer position in global coordinates. Updated by a Listener at
/// the app root so every duck on screen can watch the cursor.
final pointerPosition = ValueNotifier<Offset?>(null);

/// The VivDuck mascot — a rubber duck drawn in code.
///
/// It bobs, blinks and watches the cursor. Moods change its face; bump
/// [shakeSignal] to make it shake its head, [jumpSignal] to make it leap with
/// a splash. Tapping it makes it quack.
class Duck extends StatefulWidget {
  final double size;
  final DuckMood mood;
  final bool float;

  /// Where the eyes look, each axis in -1..1. Null = follow the pointer.
  final Offset? gaze;
  final bool followPointer;
  final int shakeSignal;
  final int jumpSignal;
  final bool quackOnTap;

  /// Draw the little water rings under the duck.
  final bool ripples;

  const Duck({
    super.key,
    this.size = 120,
    this.mood = DuckMood.idle,
    this.float = true,
    this.gaze,
    this.followPointer = true,
    this.shakeSignal = 0,
    this.jumpSignal = 0,
    this.quackOnTap = true,
    this.ripples = true,
  });

  @override
  State<Duck> createState() => _DuckState();
}

class _DuckState extends State<Duck> with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final AnimationController _jump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _quack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  double _jumpHeight = 1;
  Offset _gaze = Offset.zero;
  bool _alive = true;

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  @override
  void didUpdateWidget(covariant Duck old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood && widget.mood == DuckMood.happy) {
      _leap(0.7);
    }
    if (old.shakeSignal != widget.shakeSignal) _shake.forward(from: 0);
    if (old.jumpSignal != widget.jumpSignal) _leap(1.4);
  }

  void _leap(double height) {
    _jumpHeight = height;
    _jump.forward(from: 0);
  }

  Future<void> _scheduleBlink() async {
    final r = math.Random();
    while (_alive) {
      await Future.delayed(Duration(milliseconds: 1800 + r.nextInt(2600)));
      if (!_alive) return;
      await _blink.forward();
      if (!_alive) return;
      await _blink.reverse();
    }
  }

  @override
  void dispose() {
    _alive = false;
    _bob.dispose();
    _blink.dispose();
    _jump.dispose();
    _shake.dispose();
    _quack.dispose();
    super.dispose();
  }

  void _poke() {
    _leap(0.8);
    if (widget.quackOnTap && widget.size >= 60) _quack.forward(from: 0);
  }

  /// Target gaze from the explicit value, the pointer, or straight ahead.
  Offset _targetGaze() {
    if (widget.gaze != null) return widget.gaze!;
    final p = pointerPosition.value;
    if (!widget.followPointer || p == null) return Offset.zero;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return Offset.zero;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final d = p - center;
    final reach = math.max(d.distance, 160.0);
    return Offset(d.dx / reach, d.dy / reach);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'VivDuck mascot',
      child: GestureDetector(
        onTap: _poke,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedBuilder(
            animation: Listenable.merge([_bob, _blink, _jump, _shake, _quack]),
            builder: (context, _) {
              // Ease the eyes toward their target so they glide, not snap.
              _gaze = Offset.lerp(_gaze, _targetGaze(), 0.18)!;
              final t = _bob.value * 2 * math.pi;
              return CustomPaint(
                size: Size.square(widget.size),
                painter: _DuckPainter(
                  bob: widget.float ? math.sin(t) : 0,
                  phase: t,
                  blink: _blink.value,
                  jump: _jump.value,
                  jumpHeight: _jumpHeight,
                  shake: _shake.isAnimating ? _shake.value : 0,
                  quack: _quack.isAnimating ? _quack.value : 0,
                  gaze: _gaze,
                  mood: widget.mood,
                  dark: context.isDark,
                  ripples: widget.ripples,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DuckPainter extends CustomPainter {
  final double bob, phase, blink, jump, jumpHeight, shake, quack;
  final Offset gaze;
  final DuckMood mood;
  final bool dark, ripples;

  _DuckPainter({
    required this.bob,
    required this.phase,
    required this.blink,
    required this.jump,
    required this.jumpHeight,
    required this.shake,
    required this.quack,
    required this.gaze,
    required this.mood,
    required this.dark,
    required this.ripples,
  });

  static const _bodyLight = Color(0xFFFFD95C);
  static const _bodyDeep = Color(0xFFF5B21B);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);

    final air = math.sin(jump * math.pi); // 0 → 1 → 0 across the jump
    if (ripples) _paintRipples(canvas, air);
    _paintSplash(canvas);

    final lift = bob * 2.2 - air * 22 * jumpHeight;
    // Squash on take-off/landing, stretch in the air.
    final squash = jump == 0
        ? 1.0
        : 1 + (jump < 0.15 || jump > 0.85 ? -0.08 : 0.06) * jumpHeight;
    final headTilt =
        switch (mood) {
          DuckMood.curious => -0.12 + math.sin(phase * 2) * 0.02,
          DuckMood.thinking => math.sin(phase * 2) * 0.05,
          // Chin up and a little bounce: perky, not stern.
          DuckMood.playful => -0.06 + math.sin(phase * 2) * 0.03,
          _ => bob * 0.025,
        } +
        math.sin(shake * math.pi * 6) * 0.28 * (1 - shake);

    canvas.save(); // body transform
    canvas.translate(0, lift);
    canvas.translate(50, 86);
    canvas.scale(2 - squash, squash);
    canvas.rotate(bob * 0.03 + air * 0.08);
    canvas.translate(-50, -86);

    // Contact shadow (fades while airborne)
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 85), width: 60, height: 7),
      Paint()..color = Colors.black.withValues(alpha: 0.06 * (1 - air)),
    );

    _paintBody(canvas);

    canvas.save();
    canvas.translate(34, 44);
    canvas.rotate(headTilt);
    canvas.translate(-34, -44);
    _paintHead(canvas);
    canvas.restore();

    if (mood == DuckMood.shy) _paintCoverWing(canvas);
    canvas.restore(); // body transform

    _paintThoughts(canvas);
    if (quack > 0) _paintQuack(canvas);
    canvas.restore();
  }

  void _paintRipples(Canvas canvas, double air) {
    final ripple = Paint()
      ..color = VD.teal.withValues(
        alpha: (dark ? 0.35 : 0.22) * (1 - air * 0.6),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final w = 34.0 + i * 12 + math.sin(phase + i) * 2 + air * 10;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(50, 88 + i * 4.0),
          width: w * 2,
          height: 8,
        ),
        0.15,
        math.pi - 0.3,
        false,
        ripple,
      );
    }
  }

  /// Water droplets flung out on take-off and again on landing.
  void _paintSplash(Canvas canvas) {
    if (jump == 0) return;
    void burst(double p, double spread) {
      if (p <= 0 || p >= 1) return;
      final paint = Paint()
        ..color = (dark ? const Color(0xFF7FD8D3) : VD.teal).withValues(
          alpha: (1 - p) * 0.9,
        );
      for (var k = 0; k < 8; k++) {
        final dir = (k < 4 ? -1 : 1) * (0.5 + (k % 4) * 0.35);
        final x = 50 + dir * (14 + p * 22 * spread);
        final y = 86 - (math.sin(p * math.pi) * (10 + (k % 3) * 5) * spread);
        canvas.drawCircle(Offset(x, y), 1.8 * (1 - p * 0.5), paint);
      }
    }

    burst(jump / 0.35, 0.8 * jumpHeight);
    burst((jump - 0.82) / 0.18 * 0.9, 1.1 * jumpHeight);
  }

  void _paintBody(Canvas canvas) {
    final bodyRect = Rect.fromLTWH(14, 46, 72, 40);
    final body = Path()
      ..moveTo(18, 62)
      ..cubicTo(14, 82, 34, 88, 52, 88)
      ..cubicTo(74, 88, 90, 80, 88, 62)
      ..cubicTo(90, 56, 94, 50, 92, 44)
      ..cubicTo(86, 50, 80, 52, 70, 52)
      ..cubicTo(52, 52, 22, 48, 18, 62)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bodyLight, VD.yellow, _bodyDeep],
        ).createShader(bodyRect),
    );
    // Wing flaps a little while airborne
    final flap = math.sin(jump * math.pi * 4) * 4 * (jump > 0 ? 1 : 0);
    final wing = Path()
      ..moveTo(44, 66)
      ..cubicTo(52, 58 - flap, 72, 58 - flap, 76, 66 - flap * 0.5)
      ..cubicTo(72, 76, 56, 78, 44, 66)
      ..close();
    canvas.drawPath(wing, Paint()..color = _bodyDeep);
  }

  void _paintHead(Canvas canvas) {
    const headCenter = Offset(34, 34);
    canvas.drawCircle(
      headCenter,
      20,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFE07A), VD.yellow],
        ).createShader(Rect.fromCircle(center: headCenter, radius: 20)),
    );
    canvas.drawOval(
      Rect.fromLTWH(24, 17, 9, 5.5),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    // Beak — opens wide while quacking
    final quackOpen = quack > 0
        ? math.sin(math.min(quack * 3, 1) * math.pi) * 4
        : 0;
    final beakOpen =
        (mood == DuckMood.happy
            ? 2.5
            : mood == DuckMood.thinking
            ? 0.0
            : 0.8) +
        quackOpen;
    final beakTop = Path()
      ..moveTo(14, 36)
      ..cubicTo(6, 34, 2, 37, 4, 39)
      ..cubicTo(8, 40, 13, 40, 17, 39.5)
      ..close();
    final beakBottom = Path()
      ..moveTo(15, 40 + beakOpen * 0.2)
      ..cubicTo(9, 41 + beakOpen, 6, 42 + beakOpen, 8, 43 + beakOpen)
      ..cubicTo(11, 44 + beakOpen, 15, 43, 18, 41)
      ..close();
    canvas.drawPath(beakBottom, Paint()..color = const Color(0xFFE5701F));
    canvas.drawPath(beakTop, Paint()..color = VD.orange);

    canvas.drawCircle(
      const Offset(26, 42),
      mood == DuckMood.shy ? 4 : 3.2,
      Paint()
        ..color = const Color(
          0xFFFF9C7A,
        ).withValues(alpha: mood == DuckMood.shy ? 0.8 : 0.55),
    );

    _paintEye(canvas, const Offset(30, 29));

    canvas.drawPath(
      Path()
        ..moveTo(34, 15)
        ..quadraticBezierTo(35, 9 + math.sin(phase * 2) * 0.8, 40, 9),
      Paint()
        ..color = _bodyDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintEye(Canvas canvas, Offset eye) {
    final inkStroke = Paint()
      ..color = VD.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    if (mood == DuckMood.shy) {
      canvas.drawArc(
        Rect.fromCenter(center: eye.translate(0, -0.5), width: 7, height: 5),
        0.2,
        math.pi - 0.4,
        false,
        inkStroke,
      );
      return;
    }
    if (mood == DuckMood.happy) {
      canvas.drawArc(
        Rect.fromCenter(center: eye.translate(0, 2), width: 8, height: 7),
        math.pi + 0.3,
        math.pi - 0.6,
        false,
        inkStroke..strokeWidth = 2.4,
      );
      return;
    }

    final open = (1 - blink).clamp(0.06, 1.0);
    canvas.save();
    canvas.translate(eye.dx, eye.dy);
    canvas.scale(1, open);
    // Sclera
    final sclera = Rect.fromCenter(center: Offset.zero, width: 9.5, height: 11);
    canvas.drawOval(sclera, Paint()..color = Colors.white);
    canvas.drawOval(
      sclera,
      Paint()
        ..color = VD.ink.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    // Pupil follows the gaze (thinking eyes drift upward)
    final look = mood == DuckMood.thinking
        ? Offset(math.cos(phase * 2) * 1.2, -2.2)
        : Offset(gaze.dx.clamp(-1, 1) * 2.0, gaze.dy.clamp(-1, 1) * 2.4);
    canvas.drawCircle(look, 3.1, Paint()..color = VD.ink);
    canvas.drawCircle(
      look.translate(-1, -1.2),
      1.1,
      Paint()..color = Colors.white,
    );
    canvas.restore();

    if (mood == DuckMood.playful || mood == DuckMood.curious) {
      final brow = Paint()
        ..color = VD.ink
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (mood == DuckMood.playful) {
        // A high, rounded brow reads as "ooh, try this one!" A low, flat
        // brow over a squint read as suspicious, so avoid both.
        canvas.drawArc(
          Rect.fromCenter(center: eye.translate(0, -8.5), width: 9, height: 5),
          math.pi + 0.35,
          math.pi - 0.7,
          false,
          brow,
        );
      } else {
        canvas.drawLine(eye.translate(-4, -8), eye.translate(4, -9.5), brow);
      }
    }
  }

  void _paintCoverWing(Canvas canvas) {
    final wiggle = math.sin(phase * 3) * 0.6;
    final cover = Path()
      ..moveTo(46, 62)
      ..cubicTo(44, 46, 34, 30 + wiggle, 22, 25 + wiggle)
      ..cubicTo(17, 24, 17, 32, 22, 34)
      ..cubicTo(30, 38, 38, 50, 40, 64)
      ..close();
    canvas.drawPath(cover, Paint()..color = _bodyDeep);
    canvas.drawPath(
      cover,
      Paint()
        ..color = const Color(0xFFE09A12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final w = r * 0.28;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintThoughts(Canvas canvas) {
    if (mood == DuckMood.thinking) {
      for (var i = 0; i < 3; i++) {
        final a = (math.sin(phase * 3 - i * 0.9) + 1) / 2;
        canvas.drawCircle(
          Offset(62 + i * 9.0, 22 - a * 4),
          2.6 + a,
          Paint()..color = VD.teal.withValues(alpha: 0.4 + a * 0.6),
        );
      }
    } else if (mood == DuckMood.curious) {
      final tp = TextPainter(
        text: TextSpan(
          text: '?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: VD.teal.withValues(alpha: 0.85),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(62, 6 + math.sin(phase * 2) * 2));
    } else if (mood == DuckMood.playful) {
      // Two twinkling sparkles: an idea worth playing with.
      for (final (c, size, offset) in const [
        (Offset(68, 14), 6.0, 0.0),
        (Offset(80, 26), 3.8, 1.6),
      ]) {
        final t = (math.sin(phase * 3 + offset) + 1) / 2;
        _sparkle(
          canvas,
          c,
          size * (0.75 + t * 0.35),
          VD.yellow.withValues(alpha: 0.6 + t * 0.4),
        );
      }
    }
  }

  void _paintQuack(Canvas canvas) {
    final pop = Curves.elasticOut.transform(math.min(quack * 2.2, 1));
    final fade = quack > 0.75 ? 1 - (quack - 0.75) / 0.25 : 1.0;
    canvas.save();
    canvas.translate(4, 8);
    canvas.scale(pop);
    final bubble = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-30, -14, 40, 16),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      bubble,
      Paint()
        ..color = (dark ? VD.darkSurface : Colors.white).withValues(
          alpha: fade,
        ),
    );
    canvas.drawRRect(
      bubble,
      Paint()
        ..color = VD.orange.withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'Quack!',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: VD.orange.withValues(alpha: fade),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-10 - tp.width / 2, -6 - tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DuckPainter o) => true;
}
