import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/auth_screen.dart' show WaveText;
import '../core/duck.dart';
import '../core/pond.dart';
import '../core/theme.dart';
import 'home_screen.dart';

/// Opening scene: the pond fills, the duck drops in with a splash, the
/// name bounces in, then we glide to the home page. Tap anywhere to skip.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();
  final _pond = PondController();
  bool _landed = false;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_tick);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _go();
    });
  }

  void _tick() {
    if (!_landed && _c.value >= 0.42) {
      _landed = true;
      for (var i = 0; i < 3; i++) {
        _pond.ripple(0.5 + (i - 1) * 0.04, y: 0.05, strength: 1.6 - i * 0.3);
      }
      setState(() {});
    }
  }

  void _go() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    _pond.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final duckSize = math.min(size.width * 0.45, 220.0);
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Water rises over the first 40%.
            final water =
                0.08 +
                Curves.easeOutCubic.transform((t / 0.4).clamp(0, 1)) * 0.34;
            // Duck falls from above and bobs into the water at ~42%.
            final fall = Curves.bounceOut.transform(
              ((t - 0.12) / 0.38).clamp(0, 1),
            );
            final restY = size.height * (1 - water) - duckSize * 0.84;
            final duckY = -duckSize + (restY + duckSize) * fall;
            final textIn = ((t - 0.5) / 0.2).clamp(0.0, 1.0);
            return Stack(
              children: [
                Positioned.fill(
                  child: PondBackground(waterLevel: water, controller: _pond),
                ),
                Positioned(
                  left: (size.width - duckSize) / 2,
                  top: duckY,
                  child: Transform.rotate(
                    angle: (1 - fall) * -0.6,
                    child: Duck(
                      size: duckSize,
                      mood: _landed ? DuckMood.happy : DuckMood.curious,
                      ripples: _landed,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: size.height * 0.16,
                  child: Opacity(
                    opacity: textIn,
                    child: Column(
                      children: [
                        WaveText(
                          'VivDuck',
                          progress: ((t - 0.45) / 0.35).clamp(0.0, 1.0),
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                fontSize: math.min(size.width * 0.14, 84),
                                color: context.ink,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Transform.translate(
                          offset: Offset(0, (1 - textIn) * 12),
                          child: Text(
                            'Explain it to the duck.',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: context.inkSoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Tap to skip',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
