import 'package:flutter/material.dart';

import '../auth/auth_screen.dart';
import '../core/api.dart';
import '../core/auth.dart';
import '../core/duck.dart';
import '../core/effects.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../viva/submit_screen.dart';
import 'charts.dart';
import 'teacher_screen.dart';

class ReportScreen extends StatefulWidget {
  final String sessionId;
  const ReportScreen({super.key, required this.sessionId});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late Future<Report> _future = _load();

  /// The backend may still be marking when we arrive (409); poll briefly.
  Future<Report> _load() async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await VivaApi.instance.getReport(widget.sessionId);
      } on ApiException catch (e) {
        if (e.status != 409 || attempt >= 5) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Report>(
          future: _future,
          builder: (context, snap) {
            final Widget body;
            if (snap.hasError) {
              body = ErrorState(
                message: snap.error.toString(),
                onRetry: () => setState(() => _future = _load()),
              );
            } else if (!snap.hasData) {
              body = const _Marking();
            } else {
              body = _Celebrate(report: snap.data!);
            }
            return Column(
              children: [
                PageBody(
                  child: VDTopBar(
                    showBack: true,
                    actions: [
                      if (snap.hasData &&
                          !context.isPhone &&
                          (Auth.instance.user?.isTeacher ?? false))
                        TextButton.icon(
                          onPressed: () => openGated(
                            context,
                            page: const TeacherScreen(),
                            role: UserRole.teacher,
                          ),
                          icon: const Icon(Icons.insights_rounded),
                          label: const Text('Class view'),
                        ),
                      const ThemeToggle(),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: body,
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

class _Marking extends StatelessWidget {
  const _Marking();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Duck(size: 160, mood: DuckMood.thinking),
          const SizedBox(height: 12),
          Text('Marking your viva…', style: context.text.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Checking every key point against what you said.',
            style: TextStyle(color: context.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Shows the report and throws confetti for a big improvement.
class _Celebrate extends StatefulWidget {
  final Report report;
  const _Celebrate({required this.report});

  @override
  State<_Celebrate> createState() => _CelebrateState();
}

class _CelebrateState extends State<_Celebrate> {
  final _confetti = ConfettiController();

  @override
  void initState() {
    super.initState();
    final r = widget.report;
    if (r.scoreAfter - r.scoreBefore >= 15) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _confetti.fire(origin: const Offset(0.5, 0.25));
      });
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Confetti(
    controller: _confetti,
    child: _ReportBody(report: widget.report),
  );
}

class _ReportBody extends StatelessWidget {
  final Report report;
  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final desktop = context.isDesktop;
    const gap = SizedBox(height: 20, width: 20);

    final score = _ScoreCard(report: report);
    final bloom = _BloomCard(level: report.bloomReached);
    final trap = _TrapCard(report: report);

    return SingleChildScrollView(
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeSlideIn(child: _Header(report: report)),
            const SizedBox(height: 24),
            if (desktop)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: FadeSlideIn(child: score)),
                    gap,
                    Expanded(
                      flex: 4,
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 100),
                        child: bloom,
                      ),
                    ),
                    gap,
                    Expanded(
                      flex: 4,
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 200),
                        child: trap,
                      ),
                    ),
                  ],
                ),
              )
            else if (!phone) ...[
              FadeSlideIn(child: score),
              gap,
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: bloom),
                    gap,
                    Expanded(child: trap),
                  ],
                ),
              ),
            ] else ...[
              FadeSlideIn(child: score),
              gap,
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: bloom,
              ),
              gap,
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: trap,
              ),
            ],
            gap,
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: _KeyPointsCard(report: report),
            ),
            gap,
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: _Takeaways(report: report),
            ),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushReplacement(vdRoute(const SubmitScreen())),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Start another viva'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Home'),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Report report;
  const _Header({required this.report});

  @override
  Widget build(BuildContext context) {
    final gain = report.scoreAfter - report.scoreBefore;
    final headline = gain >= 20
        ? 'Big improvement!'
        : gain > 0
        ? 'Nice progress.'
        : 'Good effort. Keep practising.';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VIVA REPORT · ${report.title.toUpperCase()}',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: context.inkSoft,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                headline,
                style: context.isPhone
                    ? context.text.headlineMedium
                    : context.text.displaySmall,
              ),
            ],
          ),
        ),
        Duck(size: context.isPhone ? 72 : 110, mood: DuckMood.happy),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final Report report;
  const _ScoreCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final gain = report.scoreAfter - report.scoreBefore;
    final phone = context.isPhone;
    final ring = ScoreRing(
      before: report.scoreBefore,
      after: report.scoreAfter,
      size: phone ? 170 : 190,
    );
    final legend = Column(
      crossAxisAlignment: phone
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Understanding score', style: context.text.titleLarge),
        const SizedBox(height: 14),
        _Legend(
          color: VD.inkSoft,
          label: 'Before the viva',
          value: report.scoreBefore,
        ),
        const SizedBox(height: 8),
        _Legend(
          color: VD.orange,
          label: 'After the viva',
          value: report.scoreAfter,
        ),
        const SizedBox(height: 16),
        Pill(
          '${gain >= 0 ? '+' : ''}$gain points',
          color: gain >= 0 ? VD.solid : VD.missing,
          icon: gain >= 0
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
        ),
        if (report.pasteFlags > 0) ...[
          const SizedBox(height: 10),
          Pill(
            '${report.pasteFlags} pasted answer${report.pasteFlags == 1 ? '' : 's'}',
            color: VD.partial,
            icon: Icons.content_paste_rounded,
          ),
        ],
      ],
    );
    return VDCard(
      padding: const EdgeInsets.all(24),
      child: phone
          ? Column(children: [ring, const SizedBox(height: 20), legend])
          : Row(
              children: [
                ring,
                const SizedBox(width: 28),
                Expanded(child: legend),
              ],
            ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: context.inkSoft, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 10),
        CountUp(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ],
    );
  }
}

class _BloomCard extends StatelessWidget {
  final String level;
  const _BloomCard({required this.level});

  @override
  Widget build(BuildContext context) {
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("Bloom's level", style: context.text.titleLarge),
              ),
              Tooltip(
                message:
                    "How deeply you can work with the idea, from recalling facts "
                    "(Remember) up to building something new (Create).",
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: context.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'You reached ',
                  style: TextStyle(color: context.inkSoft),
                ),
                TextSpan(
                  text: level,
                  style: const TextStyle(
                    color: VD.teal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          BloomLadder(reached: level),
        ],
      ),
    );
  }
}

class _TrapCard extends StatelessWidget {
  final Report report;
  const _TrapCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final caught = report.trapCaught;
    final c = caught ? VD.solid : VD.missing;
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The curveball', style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'One question was a deliberate trap.',
            style: TextStyle(color: context.inkSoft),
          ),
          const SizedBox(height: 18),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (_, t, child) => Transform.scale(scale: t, child: child),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  caught ? Icons.shield_rounded : Icons.warning_amber_rounded,
                  color: c,
                  size: 44,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              caught ? 'You spotted it!' : 'It caught you out',
              style: context.text.titleLarge?.copyWith(color: c),
            ),
          ),
          if (report.trapExplanation != null) ...[
            const SizedBox(height: 10),
            Text(
              report.trapExplanation!,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.inkSoft, height: 1.5),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VD.partial.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.gps_fixed_rounded,
                  size: 18,
                  color: VD.partial,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Weakest point: ',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(text: report.weakestKeyPoint),
                      ],
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

class _KeyPointsCard extends StatefulWidget {
  final Report report;
  const _KeyPointsCard({required this.report});

  @override
  State<_KeyPointsCard> createState() => _KeyPointsCardState();
}

class _KeyPointsCardState extends State<_KeyPointsCard> {
  KeyPointStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final kps = widget.report.keyPoints;
    int count(KeyPointStatus s) => kps.where((k) => k.status == s).length;
    final shown = _filter == null
        ? kps
        : kps.where((k) => k.status == _filter).toList();

    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text('Key points', style: context.text.titleLarge),
              Text(
                'Tap one to see what you said',
                style: TextStyle(color: context.inkSoft, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StatusBar(
            solid: count(KeyPointStatus.solid),
            partial: count(KeyPointStatus.partial),
            missing: count(KeyPointStatus.missing),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'All ${kps.length}',
                color: context.ink,
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              for (final s in KeyPointStatus.values)
                _FilterChip(
                  label: '${statusLabel(s)} ${count(s)}',
                  color: statusColor(s),
                  selected: _filter == s,
                  onTap: () =>
                      setState(() => _filter = _filter == s ? null : s),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++)
                  FadeSlideIn(
                    key: ValueKey(shown[i].id),
                    delay: Duration(milliseconds: 60 * i),
                    from: const Offset(0.04, 0),
                    child: _KeyPointTile(kp: shown[i]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.16),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: selected ? color : context.inkSoft,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(99),
        side: BorderSide(color: selected ? color : context.line, width: 1.5),
      ),
    );
  }
}

class _KeyPointTile extends StatefulWidget {
  final KeyPoint kp;
  const _KeyPointTile({required this.kp});

  @override
  State<_KeyPointTile> createState() => _KeyPointTileState();
}

class _KeyPointTileState extends State<_KeyPointTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final kp = widget.kp;
    final c = statusColor(kp.status);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: context.bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(statusIcon(kp.status), color: c, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        kp.statement,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!context.isPhone)
                      Pill(statusLabel(kp.status), color: c),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: context.inkSoft,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: _open
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(left: 32, top: 10),
                    child: kp.evidenceQuote == null
                        ? Text(
                            "You didn't mention this one. Worth adding to your review list.",
                            style: TextStyle(
                              color: context.inkSoft,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: c, width: 3),
                              ),
                            ),
                            child: Text(
                              '“${kp.evidenceQuote}”',
                              style: TextStyle(
                                color: context.inkSoft,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Takeaways extends StatelessWidget {
  final Report report;
  const _Takeaways({required this.report});

  @override
  Widget build(BuildContext context) {
    final cols = [
      _ListCard(
        title: 'Strengths',
        icon: Icons.star_rounded,
        color: VD.solid,
        items: report.strengths,
      ),
      _ListCard(
        title: 'Gaps',
        icon: Icons.construction_rounded,
        color: VD.missing,
        items: report.gaps,
      ),
      _ListCard(
        title: 'Review next',
        icon: Icons.menu_book_rounded,
        color: VD.teal,
        items: report.reviewNext,
        checklist: true,
      ),
    ];
    if (!context.isDesktop) {
      return Column(
        children: [
          for (final c in cols)
            Padding(padding: const EdgeInsets.only(bottom: 20), child: c),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cols.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            Expanded(child: cols[i]),
          ],
        ],
      ),
    );
  }
}

class _ListCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final bool checklist;

  const _ListCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    this.checklist = false,
  });

  @override
  State<_ListCard> createState() => _ListCardState();
}

class _ListCardState extends State<_ListCard> {
  final Set<int> _done = {};

  @override
  Widget build(BuildContext context) {
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: widget.color),
              const SizedBox(width: 8),
              Text(widget.title, style: context.text.titleLarge),
              const Spacer(),
              if (widget.checklist)
                Text(
                  '${_done.length}/${widget.items.length}',
                  style: TextStyle(
                    color: context.inkSoft,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < widget.items.length; i++)
            widget.checklist
                ? InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(
                      () => _done.contains(i) ? _done.remove(i) : _done.add(i),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (c, a) =>
                                ScaleTransition(scale: a, child: c),
                            child: Icon(
                              _done.contains(i)
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              key: ValueKey(_done.contains(i)),
                              color: widget.color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: context.text.bodyLarge!.copyWith(
                                height: 1.45,
                                color: _done.contains(i)
                                    ? context.inkSoft
                                    : context.ink,
                                decoration: _done.contains(i)
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              child: Text(widget.items[i]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: widget.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.items[i],
                            style: context.text.bodyLarge?.copyWith(
                              height: 1.45,
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
