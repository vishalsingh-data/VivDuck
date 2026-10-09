import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ambient.dart';
import '../core/api.dart';
import '../core/duck.dart';
import '../core/effects.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'charts.dart';
import 'report_screen.dart';
import 'rubric_points.dart';
import 'sheets_screen.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  late Future<TeacherSummary> _future = VivaApi.instance.getTeacherSummary();

  void _refresh() =>
      setState(() => _future = VivaApi.instance.getTeacherSummary());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Ambient(
        child: SafeArea(
          child: FutureBuilder<TeacherSummary>(
            future: _future,
            builder: (context, snap) {
              final Widget body;
              if (snap.hasError) {
                body = ErrorState(
                  message: snap.error.toString(),
                  onRetry: _refresh,
                );
              } else if (!snap.hasData) {
                body = const Center(
                  child: Duck(size: 120, mood: DuckMood.thinking),
                );
              } else {
                body = _Dashboard(summary: snap.data!, onChanged: _refresh);
              }
              return Column(
                children: [
                  PageBody(
                    child: VDTopBar(
                      showBack: true,
                      actions: [
                        IconButton(
                          tooltip: 'Grade an answer sheet',
                          onPressed: () => Navigator.of(
                            context,
                          ).push(vdRoute(const SheetsScreen())),
                          icon: const Icon(Icons.document_scanner_outlined),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        const ThemeToggle(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: body,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _Sort { recent, name, score, review }

class _Dashboard extends StatefulWidget {
  final TeacherSummary summary;
  final VoidCallback onChanged;
  const _Dashboard({required this.summary, required this.onChanged});

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  String _query = '';
  String? _questionId;
  _Sort _sort = _Sort.recent;
  bool _hideSamples = false;

  List<SessionSummary> get _scoped => widget.summary.sessions
      .where((s) => _questionId == null || s.questionId == _questionId)
      .toList();

  List<SessionSummary> get _visible {
    final q = _query.toLowerCase();
    final list = _scoped
        .where((s) => !_hideSamples || !s.sample)
        .where(
          (s) =>
              q.isEmpty ||
              s.student.toLowerCase().contains(q) ||
              s.questionTitle.toLowerCase().contains(q) ||
              s.weakestKeyPoint.toLowerCase().contains(q),
        )
        .toList();
    list.sort(switch (_sort) {
      _Sort.recent => (a, b) => b.finishedAt.compareTo(a.finishedAt),
      _Sort.name => (a, b) => a.student.compareTo(b.student),
      _Sort.score => (a, b) => b.scoreBefore.compareTo(a.scoreBefore),
      _Sort.review => (a, b) => (b.inReviewQueue ? 1 : 0).compareTo(
        a.inReviewQueue ? 1 : 0,
      ),
    });
    return list;
  }

  void _open(SessionSummary s) =>
      openSessionSheet(context, s, widget.onChanged);

  @override
  Widget build(BuildContext context) {
    final sessions = _scoped;
    final n = sessions.length;
    double avg(int Function(SessionSummary) f) =>
        n == 0 ? 0 : sessions.map(f).reduce((a, b) => a + b) / n;
    final queue = sessions.where((s) => s.inReviewQueue).toList();
    final agreement = Agreement.of(sessions);
    final desktop = context.isDesktop;

    final questions = <String, String>{
      for (final s in widget.summary.sessions)
        if (s.questionId.isNotEmpty) s.questionId: s.questionTitle,
    };

    final tiles = [
      _Kpi(
        icon: Icons.assignment_turned_in_outlined,
        color: VD.ink,
        label: 'Answers graded',
        value: n,
      ),
      _Kpi(
        icon: Icons.speed_rounded,
        color: VD.orange,
        label: 'Average rubric score',
        value: avg((x) => x.scoreBefore).round(),
        detail: '${avg((x) => x.scoreAfter).round()} after follow-ups',
      ),
      _Kpi(
        icon: Icons.flag_outlined,
        color: VD.partial,
        label: 'Waiting for review',
        value: queue.length,
      ),
      _Kpi(
        icon: Icons.handshake_outlined,
        color: VD.teal,
        label: 'Agree with teacher',
        value: agreement.within10Pct,
        suffix: '%',
        detail: agreement.sampleSize == 0
            ? 'No teacher scores yet'
            : 'within 10 points · n = ${agreement.sampleSize}',
      ),
    ];

    final reviewQueue = _ReviewQueue(items: queue, onOpen: _open);
    final agreementCard = _AgreementCard(
      sessions: sessions,
      agreement: agreement,
    );

    return SingleChildScrollView(
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeSlideIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CLASS DASHBOARD',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                      color: context.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _questionId == null
                        ? 'Descriptive answers'
                        : questions[_questionId]!,
                    style: context.isPhone
                        ? context.text.headlineMedium
                        : context.text.displaySmall,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All questions'),
                        selected: _questionId == null,
                        onSelected: (_) => setState(() => _questionId = null),
                        showCheckmark: false,
                      ),
                      for (final e in questions.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: _questionId == e.key,
                          onSelected: (_) =>
                              setState(() => _questionId = e.key),
                          showCheckmark: false,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth < 560 ? 2 : 4;
                final w = (c.maxWidth - (cols - 1) * 14) / cols;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (var i = 0; i < tiles.length; i++)
                      SizedBox(
                        width: w,
                        child: FadeSlideIn(
                          delay: Duration(milliseconds: 50 * i),
                          child: tiles[i],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            if (desktop)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 6, child: reviewQueue),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: agreementCard),
                  ],
                ),
              )
            else ...[
              reviewQueue,
              const SizedBox(height: 20),
              agreementCard,
            ],
            const SizedBox(height: 20),
            VDCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SessionsToolbar(
                    sort: _sort,
                    hideSamples: _hideSamples,
                    onQuery: (v) => setState(() => _query = v),
                    onSort: (v) => setState(() => _sort = v),
                    onHideSamples: (v) => setState(() => _hideSamples = v),
                  ),
                  const SizedBox(height: 12),
                  if (_visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Text(
                          'No answers match.',
                          style: TextStyle(color: context.inkSoft),
                        ),
                      ),
                    )
                  else if (context.isPhone)
                    for (final x in _visible)
                      _SessionCard(session: x, onTap: () => _open(x))
                  else ...[
                    const _TableHeader(),
                    for (final x in _visible)
                      _SessionRow(session: x, onTap: () => _open(x)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (desktop)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _WeakConcepts(
                        items: widget.summary.weakConcepts,
                        total: widget.summary.sessions.length,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(child: _BloomSpread(sessions: sessions)),
                  ],
                ),
              )
            else ...[
              _WeakConcepts(
                items: widget.summary.weakConcepts,
                total: widget.summary.sessions.length,
              ),
              const SizedBox(height: 20),
              _BloomSpread(sessions: sessions),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, suffix;
  final String? detail;
  final num value;
  const _Kpi({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.suffix = '',
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final c = color == VD.ink ? context.ink : color;
    return VDCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(height: 10),
          CountUp(
            value,
            suffix: suffix,
            style: context.text.headlineLarge?.copyWith(height: 1),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (detail != null)
            Text(
              detail!,
              style: TextStyle(color: context.inkSoft, fontSize: 12.5),
            ),
        ],
      ),
    );
  }
}

String _reasonLabel(String code) => switch (code) {
  'evidence_check' => 'Quote not found',
  'runs_differ' => 'Runs disagree',
  'pasted' => 'Pasted',
  'handwriting' => 'Handwriting unclear',
  _ => code,
};

class _ReviewQueue extends StatelessWidget {
  final List<SessionSummary> items;
  final ValueChanged<SessionSummary> onOpen;
  const _ReviewQueue({required this.items, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: VD.partial, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Review queue', style: context.text.titleLarge),
              ),
              Text(
                '${items.length} waiting',
                style: TextStyle(color: context.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Grades VivDuck is unsure about. Enter your own score to clear one.',
            style: TextStyle(color: context.inkSoft),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: VD.solid),
                  const SizedBox(width: 8),
                  Text(
                    'Nothing to review.',
                    style: TextStyle(color: context.inkSoft),
                  ),
                ],
              ),
            )
          else
            for (final s in items.take(6))
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onOpen(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: context.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.student} · ${s.questionTitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final r in s.reviewReasons)
                                  Tooltip(
                                    message: r.message,
                                    child: Pill(
                                      _reasonLabel(r.code),
                                      color: VD.partial,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${s.scoreBefore}', style: context.text.titleLarge),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => onOpen(s),
                        child: const Text('Review'),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// VivDuck's rubric score against the teacher's own mark, one dot per
/// answer the teacher has scored, with the ±10 band around agreement.
class _AgreementCard extends StatelessWidget {
  final List<SessionSummary> sessions;
  final Agreement agreement;
  const _AgreementCard({required this.sessions, required this.agreement});

  @override
  Widget build(BuildContext context) {
    final scored = [
      for (final s in sessions)
        if (s.teacherScore != null) s,
    ];
    final a = agreement;
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VivDuck vs teacher', style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(
            a.sampleSize == 0
                ? 'Enter your own score on a few answers to see how closely VivDuck agrees.'
                : 'Average difference ${a.meanAbsDiff.toStringAsFixed(1)} points. '
                      '${a.within10Pct}% within 10 points, across ${a.sampleSize} answers you scored.',
            style: TextStyle(color: context.inkSoft, height: 1.45),
          ),
          const SizedBox(height: 16),
          if (scored.isNotEmpty)
            AspectRatio(
              aspectRatio: 1.6,
              child: Semantics(
                label:
                    'Scatter plot of VivDuck score against teacher score for ${scored.length} answers',
                child: CustomPaint(
                  painter: _ScatterPainter(
                    points: [
                      for (final s in scored)
                        Offset(
                          s.teacherScore!.toDouble(),
                          s.scoreBefore.toDouble(),
                        ),
                    ],
                    ink: context.ink,
                    soft: context.inkSoft,
                    line: context.line,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScatterPainter extends CustomPainter {
  final List<Offset> points; // (teacher, vivduck)
  final Color ink, soft, line;
  _ScatterPainter({
    required this.points,
    required this.ink,
    required this.soft,
    required this.line,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const pad = EdgeInsets.fromLTRB(30, 6, 6, 26);
    final w = size.width - pad.horizontal;
    final h = size.height - pad.vertical;
    Offset at(double x, double y) =>
        Offset(pad.left + w * x / 100, pad.top + h * (1 - y / 100));

    // ±10 agreement band around the diagonal.
    final band = Path()
      ..moveTo(at(0, 10).dx, at(0, 10).dy)
      ..lineTo(at(90, 100).dx, at(90, 100).dy)
      ..lineTo(at(100, 100).dx, at(100, 100).dy)
      ..lineTo(at(100, 90).dx, at(100, 90).dy)
      ..lineTo(at(10, 0).dx, at(10, 0).dy)
      ..lineTo(at(0, 0).dx, at(0, 0).dy)
      ..close();
    canvas.drawPath(band, Paint()..color = VD.teal.withValues(alpha: 0.1));

    final grid = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var v = 0; v <= 100; v += 25) {
      canvas.drawLine(at(0, v.toDouble()), at(100, v.toDouble()), grid);
      canvas.drawLine(at(v.toDouble(), 0), at(v.toDouble(), 100), grid);
      _label(canvas, '$v', at(v.toDouble(), 0) + const Offset(0, 12), soft);
      _label(canvas, '$v', at(0, v.toDouble()) + const Offset(-15, 0), soft);
    }
    canvas.drawLine(
      at(0, 0),
      at(100, 100),
      Paint()
        ..color = VD.teal.withValues(alpha: 0.6)
        ..strokeWidth = 1.2,
    );
    _label(canvas, 'Teacher', at(50, 0) + const Offset(0, 22), soft);

    for (final p in points) {
      final c = at(p.dx, p.dy);
      final close = (p.dx - p.dy).abs() <= 10;
      canvas.drawCircle(c, 4.5, Paint()..color = close ? VD.teal : VD.partial);
    }
  }

  void _label(Canvas canvas, String text, Offset centre, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 10.5, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_ScatterPainter old) =>
      old.points != points || old.ink != ink;
}

class _WeakConcepts extends StatelessWidget {
  final List<WeakConcept> items;
  final int total;
  const _WeakConcepts({required this.items, required this.total});

  @override
  Widget build(BuildContext context) {
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where the class is weakest', style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'The rubric points that came up most as a weakest point.',
            style: TextStyle(color: context.inkSoft),
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            Text('Nothing yet.', style: TextStyle(color: context.inkSoft))
          else
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            items[i].concept,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${items[i].count} of ${items[i].total}',
                          style: TextStyle(
                            color: context.inkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GrowBar(
                      value: items[i].total == 0
                          ? 0
                          : items[i].count / items[i].total,
                      color: i == 0 ? VD.missing : VD.partial,
                      delay: Duration(milliseconds: 120 * i),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _BloomSpread extends StatelessWidget {
  final List<SessionSummary> sessions;
  const _BloomSpread({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final counts = List.filled(bloomLevels.length, 0);
    for (final s in sessions) {
      counts[bloomIndex(s.bloomReached)]++;
    }
    final maxC = counts.fold(1, (a, b) => a > b ? a : b);
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Follow-up depth', style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(
            "The Bloom's level each student reached in the follow-up questions.",
            style: TextStyle(color: context.inkSoft),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < bloomLevels.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${counts[i]}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: counts[i] == 0
                                  ? context.inkSoft
                                  : context.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: counts[i] / maxC),
                            duration: Duration(milliseconds: 600 + i * 80),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => Container(
                              height: 4 + 110 * v.clamp(0, 1),
                              decoration: BoxDecoration(
                                color: counts[i] == 0
                                    ? context.line
                                    : VD.teal.withValues(
                                        alpha: 0.35 + i * 0.12,
                                      ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            child: Text(
                              bloomLevels[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.inkSoft,
                              ),
                            ),
                          ),
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

class _SessionsToolbar extends StatelessWidget {
  final _Sort sort;
  final bool hideSamples;
  final ValueChanged<String> onQuery;
  final ValueChanged<_Sort> onSort;
  final ValueChanged<bool> onHideSamples;

  const _SessionsToolbar({
    required this.sort,
    required this.hideSamples,
    required this.onQuery,
    required this.onSort,
    required this.onHideSamples,
  });

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      onChanged: onQuery,
      decoration: const InputDecoration(
        hintText: 'Search students, questions or points',
        prefixIcon: Icon(Icons.search_rounded),
        isDense: true,
      ),
    );
    final sortMenu = PopupMenuButton<_Sort>(
      tooltip: 'Sort',
      initialValue: sort,
      onSelected: onSort,
      itemBuilder: (_) => const [
        PopupMenuItem(value: _Sort.recent, child: Text('Most recent')),
        PopupMenuItem(value: _Sort.review, child: Text('Needs review first')),
        PopupMenuItem(value: _Sort.name, child: Text('Name')),
        PopupMenuItem(value: _Sort.score, child: Text('Rubric score')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, color: context.inkSoft),
            const SizedBox(width: 4),
            Text(switch (sort) {
              _Sort.recent => 'Recent',
              _Sort.review => 'Review',
              _Sort.name => 'Name',
              _Sort.score => 'Score',
            }, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
    final samples = FilterChip(
      label: const Text('Hide samples'),
      selected: hideSamples,
      onSelected: onHideSamples,
    );

    if (context.isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('All answers', style: context.text.titleLarge),
          const SizedBox(height: 12),
          search,
          const SizedBox(height: 8),
          Row(children: [samples, const Spacer(), sortMenu]),
        ],
      );
    }
    return Row(
      children: [
        Text('All answers', style: context.text.titleLarge),
        const SizedBox(width: 20),
        Expanded(child: search),
        const SizedBox(width: 12),
        samples,
        const SizedBox(width: 4),
        sortMenu,
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: context.inkSoft,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('STUDENT', style: style)),
          Expanded(flex: 2, child: Text('QUESTION', style: style)),
          Expanded(flex: 3, child: Text('VIVDUCK SCORE', style: style)),
          Expanded(flex: 2, child: Text('TEACHER', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          Expanded(flex: 3, child: Text('WEAKEST POINT', style: style)),
        ],
      ),
    );
  }
}

class _SessionRow extends StatefulWidget {
  final SessionSummary session;
  final VoidCallback onTap;
  const _SessionRow({required this.session, required this.onTap});

  @override
  State<_SessionRow> createState() => _SessionRowState();
}

class _SessionRowState extends State<_SessionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: _hover ? context.bg : Colors.transparent,
            border: Border(top: BorderSide(color: context.line)),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: _NameCell(session: s)),
              Expanded(
                flex: 2,
                child: Text(
                  s.questionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: _ScoreCell(session: s),
                ),
              ),
              Expanded(flex: 2, child: _TeacherCell(session: s)),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusPill(session: s),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  s.weakestKeyPoint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.inkSoft, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionSummary session;
  final VoidCallback onTap;
  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: context.bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _NameCell(session: s)),
                    _StatusPill(session: s),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  s.questionTitle,
                  style: TextStyle(color: context.inkSoft, fontSize: 13),
                ),
                const SizedBox(height: 8),
                _ScoreCell(session: s),
                const SizedBox(height: 8),
                _TeacherCell(session: s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final SessionSummary session;
  const _StatusPill({required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    if (s.inReviewQueue) {
      return Tooltip(
        message: s.reviewReasons.map((r) => r.message).join('\n'),
        child: const Pill(
          'Needs review',
          color: VD.partial,
          icon: Icons.flag_rounded,
        ),
      );
    }
    if (s.teacherScore != null) {
      return const Pill('Reviewed', color: VD.solid, icon: Icons.done_rounded);
    }
    return Pill('Graded', color: context.inkSoft);
  }
}

class _TeacherCell extends StatelessWidget {
  final SessionSummary session;
  const _TeacherCell({required this.session});

  @override
  Widget build(BuildContext context) {
    final t = session.teacherScore;
    if (t == null) {
      return Text('—', style: TextStyle(color: context.inkSoft));
    }
    final diff = t - session.scoreBefore;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$t', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Text(
          diff == 0 ? '(same)' : '(${diff > 0 ? '+' : ''}$diff)',
          style: TextStyle(
            fontSize: 12.5,
            color: diff.abs() <= 10 ? context.inkSoft : VD.partial,
          ),
        ),
      ],
    );
  }
}

class _NameCell extends StatelessWidget {
  final SessionSummary session;
  const _NameCell({required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final initials = s.student
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join();
    final hue = (s.student.hashCode % 360).toDouble();
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: HSLColor.fromAHSL(
            1,
            hue,
            0.35,
            context.isDark ? 0.3 : 0.88,
          ).toColor(),
          child: Text(
            initials,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: context.isDark ? Colors.white : VD.ink,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.student,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                [
                  if (s.sample) 'Sample',
                  if (s.source == 'photo') 'Photo',
                  if (s.source == 'document') 'Document',
                  _ago(s.finishedAt),
                ].join(' · '),
                style: TextStyle(fontSize: 12, color: context.inkSoft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().toUtc().difference(t.toUtc());
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return '${t.day}/${t.month}/${t.year}';
}

class _ScoreCell extends StatelessWidget {
  final SessionSummary session;
  const _ScoreCell({required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GrowBar(value: s.scoreAfter / 100, color: VD.orange),
                ),
                Positioned.fill(
                  child: GrowBar(
                    value: s.scoreBefore / 100,
                    color: context.ink.withValues(alpha: 0.55),
                    track: Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: 'Rubric score, then after follow-ups',
          child: Text(
            '${s.scoreBefore} → ${s.scoreAfter}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// The detail sheet for one answer, where the teacher records their score.
void openSessionSheet(
  BuildContext context,
  SessionSummary s,
  VoidCallback onChanged,
) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
      child: _SessionSheet(session: s, onChanged: onChanged),
    ),
  );
}

class _SessionSheet extends StatefulWidget {
  final SessionSummary session;
  final VoidCallback onChanged;
  const _SessionSheet({required this.session, required this.onChanged});

  @override
  State<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends State<_SessionSheet> {
  late final _score = TextEditingController(
    text: widget.session.teacherScore?.toString() ?? '',
  );
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _score.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = int.tryParse(_score.text.trim());
    if (v == null || v < 0 || v > 100) {
      setState(() => _error = 'Enter a whole number from 0 to 100.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await VivaApi.instance.setTeacherScore(
        widget.session.sessionId,
        v,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NameCell(session: s),
          const SizedBox(height: 6),
          Text(s.questionTitle, style: TextStyle(color: context.inkSoft)),
          const SizedBox(height: 18),
          Row(
            children: [
              // The teacher marks the written answer, so show that score.
              ScoreRing(before: s.scoreBefore, after: s.scoreBefore, size: 110),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rubric score ${s.scoreBefore}',
                      style: context.text.titleLarge,
                    ),
                    Text(
                      '${s.scoreAfter} after follow-ups',
                      style: TextStyle(color: context.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Pill(s.bloomReached, color: VD.teal),
                        Pill(
                          s.trapCaught ? 'Trap caught' : 'Trap missed',
                          color: s.trapCaught ? VD.solid : VD.missing,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (s.needsReview) ...[
            const SizedBox(height: 16),
            ReviewBanner(
              review: Review(needsReview: true, reasons: s.reviewReasons),
              forTeacher: true,
            ),
          ],
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Weakest point: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: s.weakestKeyPoint),
              ],
            ),
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 20),
          Text('Your score', style: context.text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Mark the written answer out of 100. It is compared with VivDuck\'s rubric score.',
            style: TextStyle(color: context.inkSoft, fontSize: 13.5),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Semantics(
                  label: 'Teacher score out of 100',
                  child: TextField(
                    controller: _score,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'Score',
                      suffixText: '/ 100',
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  label: 'Note, optional',
                  child: TextField(
                    controller: _note,
                    decoration: const InputDecoration(
                      hintText: 'Note (optional)',
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: VD.missing)),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  s.teacherScore == null ? 'Save my score' : 'Update my score',
                ),
              ),
              if (!s.sample)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      vdRoute(
                        ReportScreen(sessionId: s.sessionId, remember: false),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Open full report'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
