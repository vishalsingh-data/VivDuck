import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../auth/auth_screen.dart';
import '../core/ambient.dart';
import '../core/auth.dart';
import '../core/duck.dart';
import '../core/effects.dart';
import '../core/pond.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../report_teacher/teacher_screen.dart';
import '../shell/app_shell.dart';
import '../viva/submit_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Auth.instance,
      builder: (context, user, _) {
        // Phones get an app-style home, not a shrunken marketing page.
        if (context.isPhone) return const _PhoneHome();
        // Signed in on a big screen: the chat-app style workspace.
        if (user != null && context.width >= shellMinWidth) {
          return AppShell(user: user);
        }
        return _landing(context);
      },
    );
  }

  Widget _landing(BuildContext context) {
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
                  SizedBox(height: phone ? 32 : 56),
                  const Reveal(
                    child: _SectionHeader(
                      eyebrow: "Who it's for",
                      title: 'Built for students and teachers',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Reveal(
                    delay: Duration(milliseconds: 80),
                    child: _RoleCards(),
                  ),
                  SizedBox(height: phone ? 56 : 96),
                  const Reveal(
                    child: _SectionHeader(
                      eyebrow: 'How it works',
                      title: 'From answer to feedback in three steps',
                      color: VD.teal,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _HowItWorks(),
                  SizedBox(height: phone ? 56 : 96),
                  const _Footer(),
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
    // Sized so the headline holds two lines even on a narrow phone.
    final headline = phone
        ? context.text.displaySmall?.copyWith(fontSize: 31, height: 1.12)
        : context.text.displayMedium?.copyWith(height: 1.08);
    void openTeacher() =>
        openGated(context, page: const TeacherScreen(), role: UserRole.teacher);
    final copy = Column(
      crossAxisAlignment: phone
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (!phone) ...[
          const FadeSlideIn(child: _HeroBadge()),
          const SizedBox(height: 22),
        ],
        FadeSlideIn(
          delay: const Duration(milliseconds: 80),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Fair, consistent grades.\n'),
                TextSpan(
                  text: 'With the ',
                  style: TextStyle(color: context.ink),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GradientText(child: Text('evidence', style: headline)),
                ),
                const TextSpan(text: ' shown.'),
              ],
            ),
            textAlign: phone ? TextAlign.center : TextAlign.start,
            style: headline,
          ),
        ),
        SizedBox(height: phone ? 14 : 20),
        FadeSlideIn(
          delay: const Duration(milliseconds: 160),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              'VivDuck grades descriptive answers against a rubric, quotes the '
              'student\'s own words behind every mark, then asks three '
              'follow-up questions to check they understand what they wrote.',
              textAlign: phone ? TextAlign.center : TextAlign.start,
              style: context.text.titleMedium?.copyWith(
                color: context.inkSoft,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ),
        SizedBox(height: phone ? 24 : 34),
        FadeSlideIn(
          delay: const Duration(milliseconds: 240),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            direction: phone ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              Shine(
                child: FilledButton.icon(
                  onPressed: () =>
                      openGated(context, page: const SubmitScreen()),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Answer a question'),
                ),
              ),
              // A quieter secondary on phones keeps one clear call to action.
              if (phone)
                TextButton.icon(
                  onPressed: openTeacher,
                  icon: const Icon(Icons.insights_rounded),
                  label: const Text("I'm a teacher"),
                )
              else
                OutlinedButton.icon(
                  onPressed: openTeacher,
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
    ('What if the list were not sorted?', DuckMood.playful),
    ('Clear explanation. Well reasoned.', DuckMood.happy),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 84,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            // Old line leaves in the first half, new line arrives in the
            // second, so the two texts never sit on top of each other.
            switchInCurve: const Interval(0.5, 1, curve: Curves.easeOut),
            switchOutCurve: const Interval(0.5, 1, curve: Curves.easeIn),
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
        body: 'Type or photograph your answer and see why you got every mark.',
        cta: 'Answer a question',
        onTap: () => openGated(context, page: const SubmitScreen()),
      ),
      _RoleCard(
        icon: Icons.groups_rounded,
        color: VD.teal,
        title: 'For teachers',
        body:
            'Every score with comments, a review queue for unsure grades, and how often VivDuck agrees with you.',
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
      accent: color,
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleLarge),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: context.text.bodyLarge?.copyWith(
                    color: context.inkSoft,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: cta,
            child: Icon(Icons.arrow_forward_rounded, color: color),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatefulWidget {
  const _HeroBadge();

  @override
  State<_HeroBadge> createState() => _HeroBadgeState();
}

class _HeroBadgeState extends State<_HeroBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: context.isDark ? 0.55 : 0.75),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: context.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) => Stack(
                alignment: Alignment.center,
                children: [
                  // Live-signal ping expanding out of the dot.
                  Container(
                    width: 6 + 8 * _pulse.value,
                    height: 6 + 8 * _pulse.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: VD.teal.withValues(
                        alpha: 0.5 * (1 - _pulse.value),
                      ),
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: VD.teal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Rubric grading for descriptive answers',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String eyebrow, title;
  final Color color;
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    this.color = VD.orange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(eyebrow, color: color),
        const SizedBox(height: 10),
        Text(
          title,
          style: context.isPhone
              ? context.text.headlineSmall
              : context.text.headlineMedium,
        ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (
      Icons.edit_note_rounded,
      'Answer',
      'Type your answer, or photograph a handwritten page.',
      VD.orange,
    ),
    (
      Icons.fact_check_outlined,
      'Graded with evidence',
      'A score per rubric point, with a comment and the words that earned it.',
      VD.yellow,
    ),
    (
      Icons.forum_outlined,
      'Three follow-ups',
      'The duck checks you understand what you wrote, and the score updates.',
      VD.teal,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final items = [
      for (var i = 0; i < _steps.length; i++)
        Reveal(
          delay: Duration(milliseconds: 120 * i),
          child: _Step(
            n: i + 1,
            icon: _steps[i].$1,
            title: _steps[i].$2,
            body: _steps[i].$3,
            color: _steps[i].$4,
          ),
        ),
    ];
    if (phone) {
      return Column(
        children: items.expand((w) => [w, const SizedBox(height: 36)]).toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 48),
          Expanded(child: items[i]),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final IconData icon;
  final String title, body;
  final Color color;
  const _Step({
    required this.n,
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color.withValues(alpha: 0.14),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(height: 18),
        Text(
          'STEP $n',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
            color: context.inkSoft.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        Text(title, style: context.text.titleLarge),
        const SizedBox(height: 8),
        Text(
          body,
          style: TextStyle(color: context.inkSoft, height: 1.55, fontSize: 15),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final tagline = Text(
      'Rubric grading with the evidence shown, and a duck that asks back.',
      textAlign: phone ? TextAlign.center : TextAlign.end,
      style: context.text.bodyMedium?.copyWith(color: context.inkSoft),
    );
    return Column(
      children: [
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.line.withValues(alpha: 0),
                context.line,
                context.line.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: phone
              ? Column(
                  children: [
                    const Logo(size: 32),
                    const SizedBox(height: 10),
                    tagline,
                  ],
                )
              : Row(children: [const Logo(size: 32), const Spacer(), tagline]),
        ),
      ],
    );
  }
}

// ── Phone home ───────────────────────────────────────────────────────────────

/// App-style home for phones: one screen, no scrolling. The pond fills the
/// screen, the duck floats on the surface, and the actions sit in the water
/// below it. Every region is sized from the real screen height so nothing
/// can overlap, whatever the phone.
class _PhoneHome extends StatefulWidget {
  const _PhoneHome();

  @override
  State<_PhoneHome> createState() => _PhoneHomeState();
}

class _PhoneHomeState extends State<_PhoneHome> {
  final _pond = PondController();

  @override
  void dispose() {
    _pond.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          // The water band holds the two actions plus breathing room.
          final water = 188.0 + bottomInset;
          return Stack(
            children: [
              Positioned.fill(
                child: PondBackground(waterHeight: water, controller: _pond),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Logo(size: 34),
                          Spacer(),
                          ThemeToggle(),
                          AccountButton(),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const FadeSlideIn(child: _PhoneGreeting()),
                      // Whatever height is left goes to the duck, which is
                      // sized to fit it and sits exactly on the waterline.
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, zone) {
                            const bubble = 84.0 + 4;
                            final room = zone.maxHeight - bubble - 12;
                            final size = room.clamp(0.0, 250.0);
                            if (size < 90) return const SizedBox.shrink();
                            // Leftover sky above the speech bubble hosts the
                            // drifting questions, and never overlaps the duck.
                            final sky =
                                zone.maxHeight - bubble - size * 0.86 - 16;
                            return Stack(
                              children: [
                                if (sky > 120)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: sky,
                                    child: const _DriftingQuestions(),
                                  ),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Transform.translate(
                                    // The waterline sits ~14% up the duck's
                                    // box.
                                    offset: Offset(0, size * 0.14),
                                    child: _HeroDuck(
                                      size: size,
                                      pond: _pond,
                                      x: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: water),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20 + bottomInset,
                child: const FadeSlideIn(
                  delay: Duration(milliseconds: 160),
                  child: _PhoneActions(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PhoneGreeting extends StatelessWidget {
  const _PhoneGreeting();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Auth.instance,
      builder: (context, user, _) {
        final first = user?.name.split(' ').first;
        return SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                first == null
                    ? 'Explain it to the duck.'
                    : 'Welcome back, $first',
                style: context.text.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Answer a question and see the evidence behind every mark.',
                style: context.text.bodyLarge?.copyWith(
                  color: context.inkSoft,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhoneActions extends StatelessWidget {
  const _PhoneActions();

  @override
  Widget build(BuildContext context) {
    // Sits on the water, so the secondary action needs a light label in the
    // dark and a dark one by day to stay readable on teal.
    final onWater = context.isDark ? Colors.white : VD.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: Shine(
            child: FilledButton.icon(
              onPressed: () => openGated(context, page: const SubmitScreen()),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Answer a question'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: onWater,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () => openGated(
            context,
            page: const TeacherScreen(),
            role: UserRole.teacher,
          ),
          icon: const Icon(Icons.insights_rounded),
          label: const Text("I'm a teacher"),
        ),
      ],
    );
  }
}

/// The kinds of questions the duck asks, rising through the sky like
/// thoughts: they fade in low, sway as they drift up, and fade out near the
/// top. Each chip shows a new question every time it loops round.
class _DriftingQuestions extends StatefulWidget {
  const _DriftingQuestions();

  @override
  State<_DriftingQuestions> createState() => _DriftingQuestionsState();
}

class _DriftingQuestionsState extends State<_DriftingQuestions>
    with SingleTickerProviderStateMixin {
  static const _questions = [
    'Why is it O(log n)?',
    "What's the base case?",
    'What if the input is empty?',
    'Can you give an example?',
    'Why does the loop stop?',
    'What does 3NF fix?',
    'What would break first?',
    'How would you test it?',
  ];

  /// Seconds for one chip to travel from bottom to top.
  static const _travel = 14.0;

  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
      (elapsed) => setState(() => _t = elapsed.inMicroseconds / 1e6),
    )..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          // Enough chips to keep the sky gently busy, spaced so they never
          // stack on top of each other.
          final count = (box.maxHeight / 70).floor().clamp(2, 5);
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (var i = 0; i < count; i++)
                _chip(context, i, count, box.biggest, still),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(BuildContext context, int i, int count, Size area, bool still) {
    // Each chip is offset by an equal slice of the cycle.
    final progress = still ? (i + 0.5) / count : _t / _travel + i / count;
    final lap = progress.floor();
    final p = progress - lap; // 0 at the bottom → 1 at the top
    final text = _questions[(i + lap * count) % _questions.length];

    // Alternate left and right edges so neighbours never share a lane and
    // long questions never run off-screen. Sway gently as they rise.
    final sway = still ? 0.0 : math.sin(_t * 0.6 + i * 1.7) * 10;
    final inset = area.width * 0.04 + 10;
    final y = (area.height - 36) * (1 - p);
    // Fade in at the bottom, hold, fade out at the top.
    final opacity = still
        ? 0.9
        : (math.sin(p * math.pi) * 1.6).clamp(0.0, 1.0) * 0.9;
    final scale = 0.92 + 0.08 * math.sin(p * math.pi);

    final left = i.isEven;
    return Positioned(
      left: left ? inset + sway : null,
      right: left ? null : inset - sway,
      top: y,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          alignment: left ? Alignment.centerLeft : Alignment.centerRight,
          child: _QuestionChip(text: text, accent: _accentFor(i)),
        ),
      ),
    );
  }

  Color _accentFor(int i) => const [VD.orange, VD.teal, VD.yellow][i % 3];
}

class _QuestionChip extends StatelessWidget {
  final String text;
  final Color accent;
  const _QuestionChip({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: dark ? 0.55 : 0.7),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: context.line.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.22),
            ),
            child: Text(
              '?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: dark ? accent : VD.ink,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
