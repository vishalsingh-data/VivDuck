import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/auth.dart';
import '../core/duck.dart';
import '../core/effects.dart';
import '../core/pond.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

enum AuthMode { login, register }

/// Opens [page] if the user is signed in (and has [role], when given);
/// otherwise sends them through the auth screen first.
Future<void> openGated(
  BuildContext context, {
  required Widget page,
  UserRole? role,
}) async {
  final user = Auth.instance.user;
  if (user == null) {
    await Navigator.of(
      context,
    ).push(vdRoute(AuthScreen(requiredRole: role, next: page)));
    return;
  }
  if (role == UserRole.teacher && !user.isTeacher) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The class dashboard is for teacher accounts.'),
      ),
    );
    return;
  }
  await Navigator.of(context).push(vdRoute(page));
}

/// Login / register, staged as a living pond: the duck floats on animated
/// water, watches you type, hides its eyes for passwords, shakes its head at
/// mistakes and leaps with a splash when you get in.
class AuthScreen extends StatefulWidget {
  final AuthMode initialMode;

  /// Pre-selects this role on register, and is enforced before opening [next].
  final UserRole? requiredRole;

  /// Where to go after signing in. If null, the screen just pops.
  final Widget? next;

  const AuthScreen({
    super.key,
    this.initialMode = AuthMode.login,
    this.requiredRole,
    this.next,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Field { none, name, email, password }

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _pond = PondController();
  final _confetti = ConfettiController();
  final _rand = math.Random();

  late AuthMode _mode = widget.initialMode;
  late UserRole _role = widget.requiredRole ?? UserRole.student;
  bool _obscure = true;
  bool _busy = false;
  bool _success = false;
  bool _attempted = false;
  String? _error;
  int _shake = 0;
  int _jump = 0;
  int _modeHop = 0;

  @override
  void initState() {
    super.initState();
    for (final f in [_nameFocus, _emailFocus, _passwordFocus]) {
      f.addListener(() => setState(() {}));
    }
    for (final c in [_name, _email, _password]) {
      c.addListener(_onType);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password]) {
      c.dispose();
    }
    for (final f in [_nameFocus, _emailFocus, _passwordFocus]) {
      f.dispose();
    }
    _pond.dispose();
    _confetti.dispose();
    super.dispose();
  }

  int _lastLen = 0;

  /// Every keystroke drops a ripple near the duck and nudges its gaze.
  void _onType() {
    final len = _name.text.length + _email.text.length + _password.text.length;
    if (len != _lastLen) {
      _lastLen = len;
      final x = context.width >= 960
          ? 0.2 + _rand.nextDouble() * 0.12
          : 0.15 + _rand.nextDouble() * 0.7;
      _pond.ripple(x, y: _rand.nextDouble() * 0.4, strength: 0.45);
      setState(() {});
    }
  }

  bool get _register => _mode == AuthMode.register;

  _Field get _focused {
    if (_nameFocus.hasFocus) return _Field.name;
    if (_emailFocus.hasFocus) return _Field.email;
    if (_passwordFocus.hasFocus) return _Field.password;
    return _Field.none;
  }

  DuckMood get _mood {
    if (_success) return DuckMood.happy;
    if (_busy) return DuckMood.thinking;
    if (_focused == _Field.password) {
      return _obscure ? DuckMood.shy : DuckMood.curious;
    }
    if (_error != null) return DuckMood.sly;
    return DuckMood.idle;
  }

  /// Eyes follow the caret while typing a name or email.
  Offset? _gaze(bool beside) {
    final c = switch (_focused) {
      _Field.name => _name,
      _Field.email => _email,
      _ => null,
    };
    if (c == null) return null;
    final p = (c.text.length / 28).clamp(0.0, 1.0);
    return beside
        ? Offset(0.55 + p * 0.45, 0.15 + p * 0.5)
        : Offset(-0.8 + p * 1.6, 0.95);
  }

  String get _line {
    if (_success) return "You're in! Quack quack!";
    if (_busy) return 'Checking the pond…';
    if (_error != null) return 'Hmm, that didn\'t work. Try again?';
    switch (_focused) {
      case _Field.name:
        final first = _name.text.trim().split(' ').first;
        return first.isEmpty
            ? 'What should I call you?'
            : 'Nice to meet you, $first!';
      case _Field.email:
        return _email.text.contains('@')
            ? 'Looking good…'
            : "What's your email?";
      case _Field.password:
        return _obscure
            ? "I'm not peeking, promise!"
            : 'Ooh, now I can see it…';
      case _Field.none:
        return _register
            ? 'A new friend! Let\'s set you up.'
            : 'Hey, welcome back!';
    }
  }

  void _switchMode(AuthMode m) {
    if (m == _mode) return;
    setState(() {
      _mode = m;
      _error = null;
      _attempted = false;
      _modeHop++;
    });
    _form.currentState?.reset();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _attempted = true);
    if (!_form.currentState!.validate()) {
      setState(() => _shake++);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = _register
          ? await Auth.instance.register(
              name: _name.text,
              email: _email.text,
              password: _password.text,
              role: _role,
            )
          : await Auth.instance.login(_email.text, _password.text);
      TextInput.finishAutofillContext();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = true;
        _jump++;
      });
      _confetti.fire(origin: Offset(context.width >= 960 ? 0.22 : 0.5, 0.45));
      for (var i = 0; i < 4; i++) {
        _pond.ripple(0.15 + i * 0.22, strength: 1.4);
      }
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      _continue(user);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _shake++;
        _error = e is ApiException
            ? e.message
            : 'Something went wrong. Please try again.';
      });
    }
  }

  void _continue(AppUser user) {
    final nav = Navigator.of(context);
    final next = widget.next;
    if (next == null) {
      nav.pop(true);
      return;
    }
    if (widget.requiredRole == UserRole.teacher && !user.isTeacher) {
      nav.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome, ${user.firstName}! The class dashboard is for teacher accounts.',
          ),
        ),
      );
      return;
    }
    nav.pushReplacement(vdRoute(next));
  }

  Future<void> _useDemo(String email, String password) async {
    _switchMode(AuthMode.login);
    setState(() {
      _email.text = email;
      _password.text = password;
    });
    await _submit();
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.width >= 960;
    final card = Shake(
      signal: _shake,
      child: _GlassCard(
        child: _FormBody(
          formKey: _form,
          autovalidate: _attempted,
          mode: _mode,
          modeHop: _modeHop,
          role: _role,
          lockedRole: widget.requiredRole,
          name: _name,
          email: _email,
          password: _password,
          nameFocus: _nameFocus,
          emailFocus: _emailFocus,
          passwordFocus: _passwordFocus,
          obscure: _obscure,
          busy: _busy,
          success: _success,
          error: _error,
          onMode: _switchMode,
          onRole: (r) => setState(() => _role = r),
          onToggleObscure: () => setState(() => _obscure = !_obscure),
          onSubmit: _submit,
          onDemo: _useDemo,
        ),
      ),
    );

    final duck = Duck(
      size: wide ? 300 : 150,
      mood: _mood,
      gaze: _gaze(wide),
      shakeSignal: _shake,
      jumpSignal: _jump,
      ripples: !wide,
    );

    return Scaffold(
      body: Confetti(
        controller: _confetti,
        child: PondBackground(
          waterLevel: wide ? 0.3 : 0.16,
          controller: _pond,
          child: SafeArea(
            child: wide
                ? _WideLayout(
                    register: _register,
                    line: _line,
                    duck: duck,
                    card: card,
                  )
                : _NarrowLayout(line: _line, duck: duck, card: card),
          ),
        ),
      ),
    );
  }
}

// ── Layouts ──────────────────────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  final bool register;
  final String line;
  final Widget duck, card;
  const _WideLayout({
    required this.register,
    required this.line,
    required this.duck,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Seat the duck so its belly sits on the water surface (30% from the bottom).
        final surfaceFromBottom = box.maxHeight * 0.3;
        return Stack(
          children: [
            Positioned(
              left: 32,
              top: 12,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  const Logo(size: 44),
                ],
              ),
            ),
            const Positioned(right: 24, top: 16, child: ThemeToggle()),
            // Left: headline in the sky, duck on the water
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: box.maxWidth * 0.48,
              child: Column(
                children: [
                  SizedBox(height: box.maxHeight * 0.13),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WaveText(
                          register ? 'Join the pond.' : 'Welcome back!',
                          style: context.text.displayMedium?.copyWith(
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            register
                                ? 'Practise vivas, keep every report and see exactly what to review next.'
                                : 'Pick up where you left off. The duck has questions.',
                            key: ValueKey(register),
                            style: context.text.titleMedium?.copyWith(
                              color: context.inkSoft,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SpeechBubble(text: line),
                  const SizedBox(height: 6),
                  duck,
                  SizedBox(height: surfaceFromBottom - 300 * 0.16),
                ],
              ),
            ),
            // Right: the floating card
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: box.maxWidth * 0.52,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 72, 48, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Bob(amplitude: 5, child: card),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  final String line;
  final Widget duck, card;
  const _NarrowLayout({
    required this.line,
    required this.duck,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: PageBody(
        maxWidth: 520,
        child: Column(
          children: [
            VDTopBar(
              showBack: true,
              showAccount: false,
              actions: const [ThemeToggle()],
            ),
            SpeechBubble(text: line, compact: true),
            duck,
            const SizedBox(height: 4),
            Bob(amplitude: 3, child: card),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

/// Frosted glass panel that lets the pond show through.
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : const Color(0xFF2A7F7A)).withValues(
              alpha: dark ? 0.4 : 0.18,
            ),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: (dark ? VD.darkSurface : Colors.white).withValues(
                alpha: dark ? 0.72 : 0.78,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.08 : 0.7),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Speech bubble that pops when its text changes.
class SpeechBubble extends StatelessWidget {
  final String text;
  final bool compact;
  const SpeechBubble({super.key, required this.text, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 52 : 64,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.elasticOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (c, a) => ScaleTransition(
          scale: Tween(begin: 0.6, end: 1.0).animate(a),
          alignment: Alignment.bottomCenter,
          child: FadeTransition(opacity: a, child: c),
        ),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.bottomCenter,
          children: [...previous, ?current],
        ),
        child: Container(
          key: ValueKey(text),
          padding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: compact ? 10 : 13,
          ),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
            ),
            border: Border.all(color: context.line, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            text,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Letters drop in one by one (with a little bounce) whenever [text] changes.
class WaveText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  /// Drive the animation from outside (0..1) instead of the built-in timer.
  final double? progress;
  const WaveText(this.text, {super.key, this.style, this.progress});

  @override
  State<WaveText> createState() => _WaveTextState();
}

class _WaveTextState extends State<WaveText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void didUpdateWidget(covariant WaveText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chars = widget.text.characters.toList();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Wrap(
        children: [
          for (var i = 0; i < chars.length; i++)
            Builder(
              builder: (context) {
                final start = i / chars.length * 0.5;
                final v = widget.progress ?? _c.value;
                final p = ((v - start) / 0.5).clamp(0.0, 1.0);
                final e = Curves.elasticOut.transform(p);
                return Opacity(
                  opacity: p.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, (1 - e) * -28),
                    child: Text(
                      chars[i],
                      style: widget.style?.copyWith(
                        color: chars[i] == '.' || chars[i] == '!'
                            ? VD.orange
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool autovalidate;
  final AuthMode mode;
  final int modeHop;
  final UserRole role;
  final UserRole? lockedRole;
  final TextEditingController name, email, password;
  final FocusNode nameFocus, emailFocus, passwordFocus;
  final bool obscure, busy, success;
  final String? error;
  final ValueChanged<AuthMode> onMode;
  final ValueChanged<UserRole> onRole;
  final VoidCallback onToggleObscure, onSubmit;
  final Future<void> Function(String email, String password) onDemo;

  const _FormBody({
    required this.formKey,
    required this.autovalidate,
    required this.mode,
    required this.modeHop,
    required this.role,
    required this.lockedRole,
    required this.name,
    required this.email,
    required this.password,
    required this.nameFocus,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscure,
    required this.busy,
    required this.success,
    required this.error,
    required this.onMode,
    required this.onRole,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onDemo,
  });

  bool get _register => mode == AuthMode.register;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      autovalidateMode: autovalidate
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DuckTabs(
              mode: mode,
              hop: modeHop,
              onChanged: busy ? null : onMode,
            ),
            const SizedBox(height: 22),
            AnimatedSize(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _register
                  ? FadeSlideIn(
                      key: const ValueKey('reg'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Label('I am a'),
                          const SizedBox(height: 8),
                          _RolePicker(
                            role: role,
                            locked: lockedRole,
                            onChanged: busy ? null : onRole,
                          ),
                          const SizedBox(height: 16),
                          const _Label('Full name'),
                          const SizedBox(height: 8),
                          _GlowField(
                            focus: nameFocus,
                            icon: Icons.person_outline_rounded,
                            child: TextFormField(
                              controller: name,
                              focusNode: nameFocus,
                              enabled: !busy,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                hintText: 'e.g. Alice Nguyen',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Tell the duck your name'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const _Label('Email'),
            const SizedBox(height: 8),
            _GlowField(
              focus: emailFocus,
              icon: Icons.alternate_email_rounded,
              child: TextFormField(
                controller: email,
                focusNode: emailFocus,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(hintText: 'you@school.edu'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Enter your email';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                    return "That doesn't look like an email";
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Password'),
            const SizedBox(height: 8),
            _GlowField(
              focus: passwordFocus,
              icon: Icons.lock_outline_rounded,
              child: TextFormField(
                controller: password,
                focusNode: passwordFocus,
                enabled: !busy,
                obscureText: obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onSubmit(),
                autofillHints: [
                  _register
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                decoration: InputDecoration(
                  hintText: _register
                      ? 'At least 8 characters'
                      : 'Your password',
                  suffixIcon: IconButton(
                    tooltip: obscure ? 'Show password' : 'Hide password',
                    onPressed: onToggleObscure,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (c, a) =>
                          ScaleTransition(scale: a, child: c),
                      child: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        key: ValueKey(obscure),
                      ),
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your password';
                  if (_register && v.length < 8) {
                    return 'Use at least 8 characters';
                  }
                  return null;
                },
              ),
            ),
            if (_register) ...[
              const SizedBox(height: 10),
              _StrengthMeter(controller: password),
            ],
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              child: error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _ErrorBanner(message: error!),
                    ),
            ),
            const SizedBox(height: 22),
            _SubmitButton(
              label: _register ? 'Create account' : 'Log in',
              busy: busy,
              success: success,
              onPressed: onSubmit,
            ),
            const SizedBox(height: 10),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _register ? 'Already have an account?' : 'New to VivDuck?',
                    style: TextStyle(color: context.inkSoft),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => onMode(
                            _register ? AuthMode.login : AuthMode.register,
                          ),
                    child: Text(_register ? 'Log in' : 'Create an account'),
                  ),
                ],
              ),
            ),
            if (Auth.instance.isDemo) _DemoAccounts(busy: busy, onDemo: onDemo),
          ],
        ),
      ),
    );
  }
}

/// Log in / Register switch where a little duck swims to the selected side.
class _DuckTabs extends StatelessWidget {
  final AuthMode mode;
  final int hop;
  final ValueChanged<AuthMode>? onChanged;
  const _DuckTabs({
    required this.mode,
    required this.hop,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final right = mode == AuthMode.register;
    return SizedBox(
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 54,
            child: Container(
              decoration: BoxDecoration(
                color: context.isDark
                    ? VD.darkBg.withValues(alpha: 0.7)
                    : VD.tealSoft.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          // Sliding pill + its rider duck
          AnimatedAlign(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOutCubic,
            alignment: right ? Alignment.bottomRight : Alignment.bottomLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: SizedBox(
                height: 76,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 5,
                      right: 5,
                      bottom: 5,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD95C), VD.yellow],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: VD.orange.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: -2,
                      child: Transform.flip(
                        // Face the direction it's swimming.
                        flipX: right,
                        child: Duck(
                          size: 44,
                          mood: DuckMood.happy,
                          jumpSignal: hop,
                          quackOnTap: false,
                          followPointer: false,
                          ripples: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 54,
            child: Row(
              children: [
                for (final (m, label) in const [
                  (AuthMode.login, 'Log in'),
                  (AuthMode.register, 'Register'),
                ])
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: mode == m,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onChanged == null ? null : () => onChanged!(m),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: mode == m ? 16 : 15,
                              color: mode == m ? VD.ink : context.inkSoft,
                            ),
                            child: Text(label),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a field so it glows and its icon bobs while focused.
class _GlowField extends StatelessWidget {
  final FocusNode focus;
  final IconData icon;
  final Widget child;
  const _GlowField({
    required this.focus,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final on = focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (on)
            BoxShadow(
              color: VD.orange.withValues(alpha: 0.25),
              blurRadius: 18,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Stack(
        children: [
          _PrefixPad(child: child),
          Positioned(
            left: 14,
            top: 17,
            child: IgnorePointer(
              child: AnimatedScale(
                scale: on ? 1.2 : 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                child: Icon(
                  icon,
                  size: 22,
                  color: on ? VD.orange : context.inkSoft,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefixPad extends StatelessWidget {
  final Widget child;
  const _PrefixPad({required this.child});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).inputDecorationTheme;
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: base.copyWith(
          contentPadding: const EdgeInsets.fromLTRB(50, 16, 16, 16),
        ),
      ),
      child: child,
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final bool busy, success;
  final VoidCallback onPressed;
  const _SubmitButton({
    required this.label,
    required this.busy,
    required this.success,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final button = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 56,
      child: FilledButton(
        onPressed: busy || success ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: VD.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: success
              ? VD.solid
              : VD.orange.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (c, a) => ScaleTransition(
            scale: a,
            child: FadeTransition(opacity: a, child: c),
          ),
          child: success
              ? const Row(
                  key: ValueKey('ok'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded),
                    SizedBox(width: 8),
                    Text("You're in!"),
                  ],
                )
              : busy
              ? const SizedBox(
                  key: ValueKey('busy'),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    color: Colors.white,
                  ),
                )
              : Row(
                  key: ValueKey(label),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
        ),
      ),
    );
    return busy || success ? button : Shine(child: button);
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 12,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w800,
      color: context.inkSoft,
    ),
  );
}

/// Pill-style tab switcher with a sliding highlight.
class _RolePicker extends StatelessWidget {
  final UserRole role;
  final UserRole? locked;
  final ValueChanged<UserRole>? onChanged;
  const _RolePicker({
    required this.role,
    required this.locked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget option(
      UserRole r,
      IconData icon,
      String title,
      String sub,
      Color c,
    ) {
      final selected = role == r;
      final disabled = locked != null && locked != r;
      return Expanded(
        child: Opacity(
          opacity: disabled ? 0.45 : 1,
          child: Material(
            color: selected ? c.withValues(alpha: 0.12) : context.bg,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: disabled || onChanged == null ? null : () => onChanged!(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? c : context.line,
                    width: selected ? 2 : 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: selected ? c : context.inkSoft),
                        const Spacer(),
                        AnimatedScale(
                          scale: selected ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: c,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(fontSize: 12, color: context.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(
          UserRole.student,
          Icons.school_rounded,
          'Student',
          'Practise vivas',
          VD.orange,
        ),
        const SizedBox(width: 10),
        option(
          UserRole.teacher,
          Icons.co_present_rounded,
          'Teacher',
          'See class insights',
          VD.teal,
        ),
      ],
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  final TextEditingController controller;
  const _StrengthMeter({required this.controller});

  static int _score(String p) {
    if (p.isEmpty) return 0;
    var s = 0;
    if (p.length >= 8) s++;
    if (p.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return (s * 4 / 5).ceil().clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, v, _) {
        final score = _score(v.text);
        final (label, color) = switch (score) {
          0 => ('', context.line),
          1 => ('Too weak', VD.missing),
          2 => ('Okay', VD.partial),
          3 => ('Good', VD.teal),
          _ => ('Strong', VD.solid),
        };
        return Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < score ? color : context.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            SizedBox(
              width: 64,
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VD.missing.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: VD.missing, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoAccounts extends StatefulWidget {
  final bool busy;
  final Future<void> Function(String email, String password) onDemo;
  const _DemoAccounts({required this.busy, required this.onDemo});

  @override
  State<_DemoAccounts> createState() => _DemoAccountsState();
}

class _DemoAccountsState extends State<_DemoAccounts> {
  late final _future = Auth.instance.demoAccounts();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        final accounts = snap.data ?? const [];
        if (accounts.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Divider(color: context.line)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or try a demo account',
                      style: TextStyle(color: context.inkSoft, fontSize: 13),
                    ),
                  ),
                  Expanded(child: Divider(color: context.line)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final a in accounts)
                    OutlinedButton.icon(
                      onPressed: widget.busy
                          ? null
                          : () => widget.onDemo(a.email, a.password),
                      icon: Icon(
                        a.role == UserRole.teacher
                            ? Icons.co_present_rounded
                            : Icons.school_rounded,
                        color: a.role == UserRole.teacher ? VD.teal : VD.orange,
                      ),
                      label: Text(
                        a.role == UserRole.teacher
                            ? 'Demo teacher'
                            : 'Demo student',
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
