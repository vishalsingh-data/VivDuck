import 'package:flutter/material.dart';

import '../auth/auth_screen.dart';
import '../core/auth.dart';
import '../core/duck.dart';
import '../core/effects.dart';
import '../core/pond.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../report_teacher/teacher_screen.dart';
import '../viva/submit_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PondHero(),
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: phone ? 24 : 40),
                  const FadeSlideIn(
                    delay: Duration(milliseconds: 350),
                    child: _RoleCards(),
                  ),
                  SizedBox(height: phone ? 40 : 72),
                  const _HowItWorks(),
                  const SizedBox(height: 48),
                  Center(
                    child: Text(
                      'Rubber-duck debugging, but the duck asks back.',
                      style: context.text.bodySmall?.copyWith(
                        color: context.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width hero staged as a pond: copy in the sky, the duck afloat.
class _PondHero extends StatefulWidget {
  const _PondHero();

  @override
  State<_PondHero> createState() => _PondHeroState();
}

class _PondHeroState extends State<_PondHero> {
  final _pond = PondController();

  @override
  void dispose() {
    _pond.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final water = phone ? 110.0 : 160.0;
    return Stack(
      children: [
        Positioned.fill(
          child: PondBackground(waterHeight: water, controller: _pond),
        ),
        // Fade the deep water into the page background like a shoreline.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 56,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [context.bg.withValues(alpha: 0), context.bg],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const VDTopBar(actions: [ThemeToggle()]),
                SizedBox(height: phone ? 8 : 24),
                _Hero(water: water, pond: _pond),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final double water;
  final PondController pond;
  const _Hero({required this.water, required this.pond});

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final copy = Column(
      crossAxisAlignment: phone
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        const FadeSlideIn(
          child: Pill(
            '',
            color: VD.orange,
          ),
        ),
        const SizedBox(height: 18),
        FadeSlideIn(
          delay: const Duration(milliseconds: 80),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Explain it to the duck.\n'),
                TextSpan(
                  text: 'Prove you ',
                  style: TextStyle(color: context.ink),
                ),
                const TextSpan(
                  text: 'really',
                  style: TextStyle(color: VD.orange),
                ),
                const TextSpan(text: ' get it.'),
              ],
            ),
            textAlign: phone ? TextAlign.center : TextAlign.start,
            style:
                (phone ? context.text.displaySmall : context.text.displayMedium)
                    ?.copyWith(height: 1.1),
          ),
        ),
        const SizedBox(height: 18),
        FadeSlideIn(
          delay: const Duration(milliseconds: 160),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Hand in your code or essay, then talk it through. VivDuck asks follow-up '
              'questions, slips in a trap, and shows you exactly which ideas are solid '
              'and which need another look.',
              textAlign: phone ? TextAlign.center : TextAlign.start,
              style: context.text.titleMedium?.copyWith(
                color: context.inkSoft,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        FadeSlideIn(
          delay: const Duration(milliseconds: 240),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              Shine(
                child: FilledButton.icon(
                  onPressed: () =>
                      openGated(context, page: const SubmitScreen()),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start a viva'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => openGated(
                  context,
                  page: const TeacherScreen(),
                  role: UserRole.teacher,
                ),
                icon: const Icon(Icons.insights_rounded),
                label: const Text("I'm a teacher"),
              ),
            ],
          ),
        ),
      ],
    );

    final size = phone ? 170.0 : 280.0;
    // The duck's waterline sits ~14% up from the bottom of its box.
    final duck = Column(
      children: [
        _HeroDuck(size: size, pond: pond, x: phone ? 0.5 : 0.72),
        SizedBox(height: water - size * 0.14),
      ],
    );
    if (phone) {
      return Column(children: [copy, const SizedBox(height: 16), duck]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 6,
          child: Padding(
            padding: EdgeInsets.only(bottom: water + 56),
            child: copy,
          ),
        ),
        const SizedBox(width: 32),
        Expanded(flex: 5, child: duck),
      ],
    );
  }
}

class _HeroDuck extends StatefulWidget {
  final double size;
  final PondController pond;

  /// Duck position across the pond (0..1), for placing ripples.
  final double x;
  const _HeroDuck({required this.size, required this.pond, required this.x});

  @override
  State<_HeroDuck> createState() => _HeroDuckState();
}

class _HeroDuckState extends State<_HeroDuck> {
  static const _lines = [
    (
      'So… what does your loop do when the target is missing?',
      DuckMood.curious,
    ),
    ('Hmm, let me think about that answer.', DuckMood.thinking),
    ('What if the list were not sorted?', DuckMood.sly),
    ('Nice! You nailed that one.', DuckMood.happy),
  ];
  int _i = 0;
  bool _alive = true;

  @override
  void initState() {
    super.initState();
    _cycle();
  }

  Future<void> _cycle() async {
    while (_alive) {
      await Future.delayed(const Duration(milliseconds: 3200));
      if (!_alive || !mounted) return;
      setState(() => _i = (_i + 1) % _lines.length);
      widget.pond.ripple(widget.x, strength: 0.9);
    }
  }

  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (line, mood) = _lines[_i];
    final size = widget.size;
    return Column(
      children: [
        SizedBox(
          height: 84,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.bottomCenter,
              children: [...previous, ?current],
            ),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.0).animate(a),
                child: c,
              ),
            ),
            child: _SpeechBubble(key: ValueKey(_i), text: line),
          ),
        ),
        const SizedBox(height: 4),
        Duck(size: size, mood: mood),
      ],
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;
  const _SpeechBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320, minHeight: 56),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(6),
          ),
          border: Border.all(color: context.line, width: 1.5),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoleCards extends StatelessWidget {
  const _RoleCards();

  @override
  Widget build(BuildContext context) {
    final cards = [
      _RoleCard(
        icon: Icons.record_voice_over_rounded,
        color: VD.orange,
        title: 'For students',
        body:
            'Practise defending your work before the real viva. '
            'Get a score, a Bloom level and a personal review list.',
        cta: 'Start a viva',
        onTap: () => openGated(context, page: const SubmitScreen()),
      ),
      _RoleCard(
        icon: Icons.groups_rounded,
        color: VD.teal,
        title: 'For teachers',
        body:
            'See where the whole class is stuck. Spot shared weak concepts '
            'and who fell for the trap question.',
        cta: 'Open dashboard',
        onTap: () => openGated(
          context,
          page: const TeacherScreen(),
          role: UserRole.teacher,
        ),
      ),
    ];
    if (context.isPhone) {
      return Column(children: [cards[0], const SizedBox(height: 16), cards[1]]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 20),
          Expanded(child: cards[1]),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, body, cta;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return VDCard(
      onTap: onTap,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title, style: context.text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            body,
            style: context.text.bodyLarge?.copyWith(
              color: context.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                cta,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, color: color, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (
      Icons.upload_file_rounded,
      'Hand it in',
      'Paste your code or essay, or try one of the samples.',
    ),
    (
      Icons.forum_rounded,
      'Talk it through',
      'Answer a probe, a what-if and a sneaky trap question, in your own words.',
    ),
    (
      Icons.auto_graph_rounded,
      'See what stuck',
      'Get your before/after score, Bloom level and a list of what to review next.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final items = [
      for (var i = 0; i < _steps.length; i++)
        FadeSlideIn(
          delay: Duration(milliseconds: 500 + 120 * i),
          child: _Step(
            n: i + 1,
            icon: _steps[i].$1,
            title: _steps[i].$2,
            body: _steps[i].$3,
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How it works', style: context.text.headlineMedium),
        const SizedBox(height: 20),
        if (phone)
          ...items.expand((w) => [w, const SizedBox(height: 12)])
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 20),
                  Expanded(child: items[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final IconData icon;
  final String title, body;
  const _Step({
    required this.n,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return VDCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: VD.yellow,
            child: Text(
              '$n',
              style: const TextStyle(
                color: VD.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: context.inkSoft),
                    const SizedBox(width: 6),
                    Text(title, style: context.text.titleMedium),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(color: context.inkSoft, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
