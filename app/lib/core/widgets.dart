import 'package:flutter/material.dart';

import '../auth/auth_screen.dart';
import 'api.dart';
import 'auth.dart';
import 'duck.dart';
import 'theme.dart';

/// Breakpoints shared across screens.
class Breakpoints {
  static const tablet = 720.0;
  static const desktop = 1080.0;
}

extension Responsive on BuildContext {
  double get width => MediaQuery.sizeOf(this).width;
  bool get isPhone => width < Breakpoints.tablet;
  bool get isDesktop => width >= Breakpoints.desktop;
  double get gutter => isPhone ? 16 : 32;
}

/// Centres content with a max width and responsive side padding.
class PageBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = 1160,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: context.gutter),
          child: child,
        ),
      ),
    );
  }
}

class VDCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

  const VDCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.surface,
        borderRadius: BorderRadius.circular(VD.radius),
        border: Border.all(color: context.line, width: 1.5),
        boxShadow: [
          if (!context.isDark)
            BoxShadow(
              color: const Color(0xFFB08A2E).withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return _Hoverable(onTap: onTap!, child: card);
  }
}

class _Hoverable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Hoverable({required this.child, required this.onTap});

  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _hover = false;
  bool _down = false;
  Offset _tilt = Offset.zero; // -1..1 from the card centre

  @override
  Widget build(BuildContext context) {
    final scale = _down ? 0.98 : (_hover ? 1.02 : 1.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _tilt = Offset.zero;
      }),
      onHover: (e) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final s = box.size;
        setState(
          () => _tilt = Offset(
            (e.localPosition.dx / s.width) * 2 - 1,
            (e.localPosition.dy / s.height) * 2 - 1,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(end: _tilt),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          builder: (context, t, child) => Transform(
            alignment: Alignment.center,
            // Lean toward the cursor in 3D.
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(-t.dy * 0.07)
              ..rotateY(t.dx * 0.07),
            child: child,
          ),
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  const Pill(
    this.label, {
    super.key,
    required this.color,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? color
            : color.withValues(alpha: context.isDark ? 0.22 : 0.13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: filled ? Colors.white : color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: filled ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// App bar row with the logo, used on every screen.
class VDTopBar extends StatelessWidget {
  final List<Widget> actions;
  final bool showBack;
  final bool showAccount;

  const VDTopBar({
    super.key,
    this.actions = const [],
    this.showBack = false,
    this.showAccount = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.isPhone ? 10 : 18),
      child: Row(
        children: [
          if (showBack)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
          GestureDetector(
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Logo(),
          ),
          const Spacer(),
          if (VivaApi.instance.isMock && !context.isPhone)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Tooltip(
                message:
                    'Running on bundled sample data. Set API_BASE_URL to use the backend.',
                child: Pill(
                  'Demo mode',
                  color: VD.teal,
                  icon: Icons.science_outlined,
                ),
              ),
            ),
          ...actions,
          if (showAccount) const AccountButton(),
        ],
      ),
    );
  }
}

/// "Log in" when signed out; an avatar with an account menu when signed in.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: Auth.instance,
      builder: (context, user, _) {
        if (user == null) {
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).push(vdRoute(const AuthScreen())),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Log in'),
            ),
          );
        }
        final initials = user.name
            .split(' ')
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p[0].toUpperCase())
            .join();
        final color = user.isTeacher ? VD.teal : VD.orange;
        return PopupMenuButton<String>(
          tooltip: 'Account',
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (v) async {
            if (v == 'logout') {
              await Auth.instance.logout();
              if (!context.mounted) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed out. See you soon!')),
              );
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: context.ink,
                    ),
                  ),
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 12, color: context.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  Pill(user.isTeacher ? 'Teacher' : 'Student', color: color),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Sign out'),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Text(
                initials,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: context.isDark ? Colors.white : VD.ink,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Duck(size: size, float: false),
          const SizedBox(width: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Viv',
                  style: TextStyle(color: context.ink),
                ),
                const TextSpan(
                  text: 'Duck',
                  style: TextStyle(color: VD.orange),
                ),
              ],
            ),
            style: context.text.titleLarge?.copyWith(fontSize: size * 0.55),
          ),
        ],
      ),
    );
  }
}

/// Full-area friendly error with a retry button.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Duck(size: 110, mood: DuckMood.curious),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades and slides a child in, optionally after a delay. Good for staggering.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Offset from;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.from = const Offset(0, 0.08),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: SlideTransition(
        position: Tween(begin: widget.from, end: Offset.zero).animate(_a),
        child: widget.child,
      ),
    );
  }
}

/// Small theme toggle shared by top bars.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: themeMode,
      builder: (context, mode, _) {
        final dark = context.isDark;
        return IconButton(
          tooltip: dark ? 'Light mode' : 'Dark mode',
          onPressed: () =>
              themeMode.value = dark ? ThemeMode.light : ThemeMode.dark,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => RotationTransition(turns: a, child: c),
            child: Icon(
              dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(dark),
            ),
          ),
        );
      },
    );
  }
}

final themeMode = ValueNotifier(ThemeMode.system);

/// Route with a gentle fade + rise transition.
Route<T> vdRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 380),
  reverseTransitionDuration: const Duration(milliseconds: 260),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, child) {
    final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: c,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(c),
        child: child,
      ),
    );
  },
);
