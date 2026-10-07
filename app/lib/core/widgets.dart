import 'package:flutter/material.dart';

import '../auth/auth_screen.dart';
import 'api.dart';
import 'auth.dart';
import 'duck.dart';
import 'shell_scope.dart';
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

/// The app's surface: a flat panel with a hairline border and a soft shadow.
/// Tappable cards darken their border and lift slightly on hover.
class VDCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color accent;
  final VoidCallback? onTap;

  const VDCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.accent = VD.yellow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return _CardSurface(
        padding: padding,
        color: color,
        accent: accent,
        hover: false,
        child: child,
      );
    }
    return _Hoverable(
      onTap: onTap!,
      builder: (hover) => _CardSurface(
        padding: padding,
        color: color,
        accent: accent,
        hover: hover,
        child: child,
      ),
    );
  }
}

class _CardSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color accent;
  final bool hover;

  const _CardSurface({
    required this.child,
    required this.padding,
    required this.color,
    required this.accent,
    required this.hover,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.surface,
        borderRadius: BorderRadius.circular(VD.radius),
        border: Border.all(
          color: hover
              ? (dark
                    ? accent.withValues(alpha: 0.55)
                    : context.inkSoft.withValues(alpha: 0.45))
              : context.line,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.25 : 0.04),
            blurRadius: hover ? 18 : 2,
            offset: Offset(0, hover ? 6 : 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Hoverable extends StatefulWidget {
  final Widget Function(bool hover) builder;
  final VoidCallback onTap;
  const _Hoverable({required this.builder, required this.onTap});

  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedSlide(
          offset: Offset(0, _hover ? -0.006 : 0),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: widget.builder(_hover),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled
            ? color
            : color.withValues(alpha: context.isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: filled ? Colors.white : color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : color,
              ),
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
    if (context.inShell) {
      // The sidebar carries the logo, theme and account; keep only the
      // screen's own actions and a back arrow when there's somewhere to go.
      final canBack = showBack && Navigator.of(context).canPop();
      final own = actions.where((a) => a is! ThemeToggle).toList();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              if (canBack)
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              const Spacer(),
              ...own,
            ],
          ),
        ),
      );
    }
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
                    'Demo mode: running on bundled sample data. '
                    'Set API_BASE_URL to use the backend.',
                // Icon-only so it informs without competing with the nav.
                child: Icon(Icons.science_outlined, size: 20, color: VD.teal),
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
                const SnackBar(content: Text('You have been signed out.')),
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
                      fontWeight: FontWeight.w600,
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
                  fontWeight: FontWeight.w600,
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
            style: context.text.titleLarge?.copyWith(
              fontSize: size * 0.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
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
    this.from = const Offset(0, 0.03),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
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
  transitionDuration: const Duration(milliseconds: 240),
  reverseTransitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, child) {
    final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: c,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.012),
          end: Offset.zero,
        ).animate(c),
        child: child,
      ),
    );
  },
);
