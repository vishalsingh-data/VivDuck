import 'package:flutter/material.dart';

import '../core/ambient.dart';
import '../core/api.dart';
import '../core/auth.dart';
import '../core/recent.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// The signed-in user's account: who they are, what they've done on this
/// device, and a way to change their name or password (contract 11).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Ambient(
        child: SafeArea(
          child: Column(
            children: [
              const PageBody(child: VDTopBar(showBack: true)),
              Expanded(
                child: ValueListenableBuilder<AppUser?>(
                  valueListenable: Auth.instance,
                  builder: (context, user, _) {
                    if (user == null) {
                      return Center(
                        child: Text(
                          'You are signed out.',
                          style: TextStyle(color: context.inkSoft),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: PageBody(
                        maxWidth: 720,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Header(user: user),
                            const SizedBox(height: 16),
                            const _Activity(),
                            const SizedBox(height: 16),
                            if (user.isDemoAccount)
                              VDCard(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      color: VD.teal,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "This is a shared demo account, so its name and password can't be changed. Register your own account to edit your profile.",
                                        style: TextStyle(
                                          color: context.inkSoft,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              _NameForm(user: user),
                              const SizedBox(height: 16),
                              const _PasswordForm(),
                            ],
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => signOut(context),
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Sign out'),
                              ),
                            ),
                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Signs out, returns to the first screen and says so.
Future<void> signOut(BuildContext context) async {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await Auth.instance.logout();
  nav.popUntil((r) => r.isFirst);
  messenger.showSnackBar(
    const SnackBar(content: Text('You have been signed out.')),
  );
}

class _Header extends StatelessWidget {
  final AppUser user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final color = user.isTeacher ? VD.teal : VD.orange;
    return VDCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Text(
              user.initials,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: context.isDark ? Colors.white : VD.ink,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: context.text.headlineSmall),
                const SizedBox(height: 2),
                Text(user.email, style: TextStyle(color: context.inkSoft)),
                const SizedBox(height: 8),
                Pill(user.isTeacher ? 'Teacher' : 'Student', color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Finished vivas on this device (the same list as the sidebar's Recent).
class _Activity extends StatelessWidget {
  const _Activity();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RecentViva>>(
      valueListenable: RecentVivas.instance,
      builder: (context, vivas, _) {
        final n = vivas.length;
        int avg(int Function(RecentViva) f) =>
            n == 0 ? 0 : (vivas.map(f).reduce((a, b) => a + b) / n).round();
        final best = n == 0
            ? 0
            : vivas.map((v) => v.scoreAfter).reduce((a, b) => a > b ? a : b);
        return VDCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your activity', style: context.text.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Vivas finished on this device.',
                style: TextStyle(color: context.inkSoft, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (n == 0)
                Text(
                  'None yet. Answer a question to see your progress here.',
                  style: TextStyle(color: context.inkSoft),
                )
              else
                Wrap(
                  spacing: 32,
                  runSpacing: 16,
                  children: [
                    _Stat(label: 'Vivas finished', value: '$n'),
                    _Stat(
                      label: 'Average score',
                      value: '${avg((v) => v.scoreAfter)}',
                      detail: '${avg((v) => v.scoreBefore)} before follow-ups',
                    ),
                    _Stat(label: 'Best score', value: '$best'),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final String? detail;
  const _Stat({required this.label, required this.value, this.detail});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: context.text.headlineMedium),
      Text(label, style: TextStyle(color: context.inkSoft, fontSize: 13)),
      if (detail != null)
        Text(detail!, style: TextStyle(color: context.inkSoft, fontSize: 12)),
    ],
  );
}

class _NameForm extends StatefulWidget {
  final AppUser user;
  const _NameForm({required this.user});

  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  late final _name = TextEditingController(text: widget.user.name)
    ..addListener(() => setState(() {}));
  bool _busy = false;
  String? _message;
  bool _ok = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _changed =>
      _name.text.trim().isNotEmpty && _name.text.trim() != widget.user.name;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Auth.instance.updateName(_name.text);
      if (mounted) {
        setState(() {
          _ok = true;
          _message = 'Name saved.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _ok = false;
          _message = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your name', style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Shown to your teacher on every answer you submit.',
            style: TextStyle(color: context.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: 'Your name',
            child: TextField(
              controller: _name,
              maxLength: 100,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(counterText: ''),
              onSubmitted: (_) => _changed && !_busy ? _save() : null,
            ),
          ),
          const SizedBox(height: 12),
          _FormFooter(
            busy: _busy,
            enabled: _changed,
            label: 'Save name',
            message: _message,
            ok: _ok,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _PasswordForm extends StatefulWidget {
  const _PasswordForm();

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_current, _next, _confirm]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? get _problem {
    if (_next.text.isNotEmpty && _next.text.length < 8) {
      return 'The new password needs at least 8 characters.';
    }
    if (_confirm.text.isNotEmpty && _confirm.text != _next.text) {
      return "The new passwords don't match.";
    }
    return null;
  }

  bool get _ready =>
      _current.text.isNotEmpty &&
      _next.text.length >= 8 &&
      _confirm.text == _next.text;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Auth.instance.changePassword(_current.text, _next.text);
      if (mounted) {
        _current.clear();
        _next.clear();
        _confirm.clear();
        setState(() {
          _ok = true;
          _message = 'Password changed. Other devices have been signed out.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _ok = false;
          _message = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, List<String> hints) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Semantics(
          label: label,
          child: TextField(
            controller: c,
            obscureText: true,
            autofillHints: hints,
            decoration: InputDecoration(hintText: label),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return VDCard(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Change password', style: context.text.titleLarge),
            const SizedBox(height: 14),
            _field(_current, 'Current password', const [
              AutofillHints.password,
            ]),
            _field(_next, 'New password (at least 8 characters)', const [
              AutofillHints.newPassword,
            ]),
            _field(_confirm, 'Repeat the new password', const [
              AutofillHints.newPassword,
            ]),
            const SizedBox(height: 2),
            _FormFooter(
              busy: _busy,
              enabled: _ready,
              label: 'Change password',
              message: problem ?? _message,
              ok: problem == null && _ok,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormFooter extends StatelessWidget {
  final bool busy, enabled, ok;
  final String label;
  final String? message;
  final VoidCallback onPressed;

  const _FormFooter({
    required this.busy,
    required this.enabled,
    required this.label,
    required this.message,
    required this.ok,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton(
          onPressed: enabled && !busy ? onPressed : null,
          child: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : Text(label),
        ),
        if (message != null)
          Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: TextStyle(
                color: ok ? VD.solid : VD.missing,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
