import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/duck.dart' as core_duck;

/// Moods supported by [DuckAvatar].
enum DuckMood {
  idle,
  thinking,
  asking,
  happy,
  curious,
  sly,
  shy,
}

/// A mood-reactive duck avatar widget that wraps VivDuck's mascot.
///
/// Animations:
/// - [idle]: slow breathing scale from 1.0 to 1.03, repeating every 3 seconds
/// - [thinking]: head-tilt rotation of 6 degrees each way, repeating every 0.9 seconds
/// - [asking]: one small hop of 16 px, then still
/// - [happy]: three jumps of 40 px
///
/// Uses exactly one [AnimationController] and disposes it.
/// If [MediaQuery.disableAnimations] is true, shows the still image.
class DuckAvatar extends StatefulWidget {
  final double size;
  final dynamic mood;
  final bool float;
  final Offset? gaze;
  final bool followPointer;
  final int shakeSignal;
  final int jumpSignal;
  final bool quackOnTap;
  final bool ripples;

  const DuckAvatar({
    super.key,
    this.size = 120,
    this.mood = DuckMood.idle,
    this.float = false,
    this.gaze,
    this.followPointer = true,
    this.shakeSignal = 0,
    this.jumpSignal = 0,
    this.quackOnTap = true,
    this.ripples = true,
  });

  @override
  State<DuckAvatar> createState() => _DuckAvatarState();
}

class _DuckAvatarState extends State<DuckAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  DuckMood _resolveMood(dynamic m) {
    if (m is DuckMood) return m;
    if (m is core_duck.DuckMood) {
      switch (m) {
        case core_duck.DuckMood.idle:
          return DuckMood.idle;
        case core_duck.DuckMood.thinking:
          return DuckMood.thinking;
        case core_duck.DuckMood.happy:
          return DuckMood.happy;
        case core_duck.DuckMood.curious:
          return DuckMood.asking;
        case core_duck.DuckMood.sly:
          return DuckMood.sly;
        case core_duck.DuckMood.shy:
          return DuckMood.shy;
      }
    }
    if (m is String) {
      switch (m.toLowerCase().trim()) {
        case 'idle':
          return DuckMood.idle;
        case 'thinking':
          return DuckMood.thinking;
        case 'asking':
          return DuckMood.asking;
        case 'happy':
          return DuckMood.happy;
        case 'curious':
          return DuckMood.asking;
        case 'sly':
          return DuckMood.sly;
        case 'shy':
          return DuckMood.shy;
        default:
          return DuckMood.idle;
      }
    }
    if (m != null) {
      final name = m.toString().split('.').last.toLowerCase();
      switch (name) {
        case 'idle':
          return DuckMood.idle;
        case 'thinking':
          return DuckMood.thinking;
        case 'asking':
          return DuckMood.asking;
        case 'happy':
          return DuckMood.happy;
        case 'curious':
          return DuckMood.asking;
        case 'sly':
          return DuckMood.sly;
        case 'shy':
          return DuckMood.shy;
        default:
          return DuckMood.idle;
      }
    }
    return DuckMood.idle;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _startAnimation();
  }

  @override
  void didUpdateWidget(covariant DuckAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood ||
        oldWidget.jumpSignal != widget.jumpSignal) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _controller.stop();
    _controller.reset();
    final mood = _resolveMood(widget.mood);
    switch (mood) {
      case DuckMood.idle:
        _controller.duration = const Duration(seconds: 3);
        _controller.repeat(reverse: true);
        break;
      case DuckMood.thinking:
        _controller.duration = const Duration(milliseconds: 900);
        _controller.repeat(reverse: true);
        break;
      case DuckMood.asking:
        _controller.duration = const Duration(milliseconds: 400);
        _controller.forward(from: 0);
        break;
      case DuckMood.happy:
        _controller.duration = const Duration(milliseconds: 1200);
        _controller.forward(from: 0);
        break;
      default:
        _controller.duration = const Duration(seconds: 3);
        _controller.repeat(reverse: true);
        break;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ??
        MediaQuery.of(context).disableAnimations;

    final mood = _resolveMood(widget.mood);

    final coreMood = switch (mood) {
      DuckMood.idle => core_duck.DuckMood.idle,
      DuckMood.thinking => core_duck.DuckMood.thinking,
      DuckMood.asking => core_duck.DuckMood.curious,
      DuckMood.happy => core_duck.DuckMood.happy,
      DuckMood.curious => core_duck.DuckMood.curious,
      DuckMood.sly => core_duck.DuckMood.sly,
      DuckMood.shy => core_duck.DuckMood.shy,
    };

    final stillDuck = core_duck.Duck(
      key: ValueKey(coreMood),
      size: widget.size,
      mood: coreMood,
      float: widget.float,
      gaze: widget.gaze,
      followPointer: widget.followPointer,
      shakeSignal: widget.shakeSignal,
      jumpSignal: widget.jumpSignal,
      quackOnTap: widget.quackOnTap,
      ripples: widget.ripples,
    );

    // If MediaQuery.disableAnimations is true, show the still image.
    if (disableAnimations) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: stillDuck,
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double scale = 1.0;
          double angle = 0.0;
          double dy = 0.0;

          switch (mood) {
            case DuckMood.idle:
              // idle: slow breathing scale from 1.0 to 1.03, repeating every 3 seconds
              final t = Curves.easeInOut.transform(_controller.value);
              scale = 1.0 + 0.03 * t;
              break;

            case DuckMood.thinking:
              // thinking: head-tilt rotation of 6 degrees each way, repeating every 0.9 seconds
              final t = Curves.easeInOut.transform(_controller.value);
              final degrees = -6.0 + 12.0 * t;
              angle = degrees * (math.pi / 180.0);
              break;

            case DuckMood.asking:
              // asking: one small hop of 16 px, then still
              if (_controller.isAnimating && _controller.value < 1.0) {
                dy = -16.0 * math.sin(_controller.value * math.pi);
              }
              break;

            case DuckMood.happy:
              // happy: three jumps of 40 px
              if (_controller.isAnimating && _controller.value < 1.0) {
                final jumpProgress = (_controller.value * 3.0) % 1.0;
                dy = -40.0 * math.sin(jumpProgress * math.pi);
              }
              break;

            default:
              final t = Curves.easeInOut.transform(_controller.value);
              scale = 1.0 + 0.03 * t;
              break;
          }

          Widget current = child!;
          if (scale != 1.0) {
            current = Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: current,
            );
          }
          if (angle != 0.0) {
            current = Transform.rotate(
              angle: angle,
              alignment: Alignment.center,
              child: current,
            );
          }
          if (dy != 0.0) {
            current = Transform.translate(
              offset: Offset(0, dy),
              child: current,
            );
          }

          return current;
        },
        child: stillDuck,
      ),
    );
  }
}
