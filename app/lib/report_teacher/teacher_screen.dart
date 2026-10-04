import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/duck.dart';
import '../core/effects.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'charts.dart';
import 'report_screen.dart';

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
      body: SafeArea(
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
              body = _Dashboard(summary: snap.data!);
            }
            return Column(
              children: [
                PageBody(
                  child: VDTopBar(
                    showBack: true,
                    actions: [
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
                    duration: const Duration(milliseconds: 350),
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

enum _Sort { recent, name, after, gain }

class _Dashboard extends StatefulWidget {
  final TeacherSummary summary;
  const _Dashboard({required this.summary});

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  String _query = '';
  _Sort _sort = _Sort.recent;
  bool _hideSamples = false;

  List<SessionSummary> get _visible {
    final q = _query.toLowerCase();
    final list = widget.summary.sessions
        .where((s) => !_hideSamples || !s.sample)
        .where(
          (s) =>
              q.isEmpty ||
              s.student.toLowerCase().contains(q) ||
              s.weakestKeyPoint.toLowerCase().contains(q),
        )
        .toList();
    list.sort(switch (_sort) {
      _Sort.recent => (a, b) => b.finishedAt.compareTo(a.finishedAt),
      _Sort.name => (a, b) => a.student.compareTo(b.student),
      _Sort.after => (a, b) => b.scoreAfter.compareTo(a.scoreAfter),
      _Sort.gain => (a, b) => b.gain.compareTo(a.gain),
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final sessions = s.sessions;
    final n = sessions.length;
    double avg(int Function(SessionSummary) f) =>
        n == 0 ? 0 : sessions.map(f).reduce((a, b) => a + b) / n;
    final trapPct = n == 0
        ? 0
        : sessions.where((x) => x.trapCaught).length / n * 100;
    final desktop = context.isDesktop;

    final tiles = [
      _Kpi(
        icon: Icons.groups_rounded,
        color: VD.ink,
        label: 'Students',
        value: n,
      ),
      _Kpi(
        icon: Icons.speed_rounded,
        color: VD.orange,
        label: 'Avg score after',
        value: avg((x) => x.scoreAfter).round(),
      ),
      _Kpi(
        icon: Icons.trending_up_rounded,
        color: VD.solid,
        label: 'Avg gain',
        value: avg((x) => x.gain).round(),
        prefix: '+',
      ),
      _Kpi(
        icon: Icons.shield_rounded,
        color: VD.teal,
        label: 'Caught the trap',
        value: trapPct.round(),
        suffix: '%',
      ),
    ];

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
                      fontWeight: FontWeight.w800,
                      color: context.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.assignment,
                    style: context.isPhone
                        ? context.text.headlineMedium
                        : context.text.displaySmall,
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
                          delay: Duration(milliseconds: 60 * i),
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
                    Expanded(child: _WeakConcepts(items: s.weakConcepts)),
                    const SizedBox(width: 20),
                    Expanded(child: _BloomSpread(sessions: sessions)),
                  ],
                ),
              )
            else ...[
              _WeakConcepts(items: s.weakConcepts),
              const SizedBox(height: 20),
              _BloomSpread(sessions: sessions),
            ],
            const SizedBox(height: 20),
            VDCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SessionsToolbar(
                    query: _query,
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
                          'No students match.',
                          style: TextStyle(color: context.inkSoft),
                        ),
                      ),
                    )
                  else if (context.isPhone)
                    for (final x in _visible) _SessionCard(session: x)
                  else ...[
                    const _TableHeader(),
                    for (final x in _visible) _SessionRow(session: x),
                  ],
                ],
              ),
            ),
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
  final String label, prefix, suffix;
  final num value;
  const _Kpi({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final c = color == VD.ink ? context.ink : color;
    return VDCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c),
          const SizedBox(height: 10),
          CountUp(
            value,
            prefix: prefix,
            suffix: suffix,
            style: context.text.headlineLarge?.copyWith(height: 1),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.inkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeakConcepts extends StatelessWidget {
  final List<WeakConcept> items;
  const _WeakConcepts({required this.items});

  @override
  Widget build(BuildContext context) {
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where the class is stuck', style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Concepts that came up as a weakest point.',
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
                      children: [
                        Expanded(
                          child: Text(
                            items[i].concept,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${items[i].count} of ${items[i].total}',
                          style: TextStyle(
                            color: context.inkSoft,
                            fontWeight: FontWeight.w800,
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
          Text("Bloom's levels reached", style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'How deep each student got.',
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
                              fontWeight: FontWeight.w900,
                              color: counts[i] == 0
                                  ? context.inkSoft
                                  : context.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: counts[i] / maxC),
                            duration: Duration(milliseconds: 700 + i * 90),
                            curve: Curves.easeOutBack,
                            builder: (_, v, _) => Container(
                              height: 4 + 110 * v.clamp(0, 1.1),
                              decoration: BoxDecoration(
                                color: counts[i] == 0
                                    ? context.line
                                    : VD.teal.withValues(
                                        alpha: 0.35 + i * 0.12,
                                      ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            child: Text(
                              bloomLevels[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
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
  final String query;
  final _Sort sort;
  final bool hideSamples;
  final ValueChanged<String> onQuery;
  final ValueChanged<_Sort> onSort;
  final ValueChanged<bool> onHideSamples;

  const _SessionsToolbar({
    required this.query,
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
        hintText: 'Search students or concepts',
        prefixIcon: Icon(Icons.search_rounded),
        isDense: true,
      ),
    );
    final sortMenu = PopupMenuButton<_Sort>(
      tooltip: 'Sort',
      initialValue: sort,
      onSelected: onSort,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => const [
        PopupMenuItem(value: _Sort.recent, child: Text('Most recent')),
        PopupMenuItem(value: _Sort.name, child: Text('Name')),
        PopupMenuItem(value: _Sort.after, child: Text('Score after')),
        PopupMenuItem(value: _Sort.gain, child: Text('Biggest gain')),
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
              _Sort.name => 'Name',
              _Sort.after => 'Score',
              _Sort.gain => 'Gain',
            }, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
    final samples = FilterChip(
      label: const Text('Hide samples'),
      selected: hideSamples,
      onSelected: onHideSamples,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
    );

    if (context.isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Students', style: context.text.titleLarge),
          const SizedBox(height: 12),
          search,
          const SizedBox(height: 8),
          Row(children: [samples, const Spacer(), sortMenu]),
        ],
      );
    }
    return Row(
      children: [
        Text('Students', style: context.text.titleLarge),
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
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
      color: context.inkSoft,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('STUDENT', style: style)),
          Expanded(flex: 3, child: Text('SCORE', style: style)),
          Expanded(flex: 2, child: Text('BLOOM', style: style)),
          SizedBox(width: 56, child: Text('TRAP', style: style)),
          Expanded(flex: 4, child: Text('WEAKEST POINT', style: style)),
        ],
      ),
    );
  }
}

void _openSession(BuildContext context, SessionSummary s) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: context.surface,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (c) => _SessionSheet(session: s),
  );
}

class _SessionRow extends StatefulWidget {
  final SessionSummary session;
  const _SessionRow({required this.session});

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
        onTap: () => _openSession(context, s),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: _hover ? context.bg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border(top: BorderSide(color: context.line)),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: _NameCell(session: s)),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: _ScoreCell(session: s),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Pill(s.bloomReached, color: VD.teal),
                ),
              ),
              SizedBox(width: 56, child: _TrapIcon(caught: s.trapCaught)),
              Expanded(
                flex: 4,
                child: Text(
                  s.weakestKeyPoint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.inkSoft),
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
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: context.bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openSession(context, s),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _NameCell(session: s)),
                    _TrapIcon(caught: s.trapCaught),
                  ],
                ),
                const SizedBox(height: 12),
                _ScoreCell(session: s),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Pill(s.bloomReached, color: VD.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.weakestKeyPoint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.inkSoft, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
          radius: 18,
          backgroundColor: HSLColor.fromAHSL(
            1,
            hue,
            0.6,
            context.isDark ? 0.35 : 0.85,
          ).toColor(),
          child: Text(
            initials,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
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
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                s.sample
                    ? 'Sample · ${_ago(s.finishedAt)}'
                    : _ago(s.finishedAt),
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
            height: 10,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GrowBar(value: s.scoreAfter / 100, color: VD.orange),
                ),
                Positioned.fill(
                  child: GrowBar(
                    value: s.scoreBefore / 100,
                    color: context.inkSoft.withValues(alpha: 0.6),
                    track: Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${s.scoreBefore} → ${s.scoreAfter}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ],
    );
  }
}

class _TrapIcon extends StatelessWidget {
  final bool caught;
  const _TrapIcon({required this.caught});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: caught ? 'Caught the trap' : 'Missed the trap',
      child: Icon(
        caught ? Icons.shield_rounded : Icons.warning_amber_rounded,
        color: caught ? VD.solid : VD.missing,
        size: 22,
      ),
    );
  }
}

class _SessionSheet extends StatelessWidget {
  final SessionSummary session;
  const _SessionSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NameCell(session: s),
          const SizedBox(height: 20),
          Row(
            children: [
              ScoreRing(before: s.scoreBefore, after: s.scoreAfter, size: 120),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.scoreBefore} → ${s.scoreAfter}',
                      style: context.text.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Pill(
                      '+${s.gain} points',
                      color: VD.solid,
                      icon: Icons.trending_up_rounded,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Pill(
                          s.bloomReached,
                          color: VD.teal,
                          icon: Icons.stairs_rounded,
                        ),
                        Pill(
                          s.trapCaught ? 'Trap caught' : 'Trap missed',
                          color: s.trapCaught ? VD.solid : VD.missing,
                          icon: s.trapCaught
                              ? Icons.shield_rounded
                              : Icons.warning_amber_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VD.partial.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Weakest point: ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: s.weakestKeyPoint),
                ],
              ),
            ),
          ),
          if (!s.sample) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(vdRoute(ReportScreen(sessionId: s.sessionId)));
              },
              icon: const Icon(Icons.description_rounded),
              label: const Text('Open full report'),
            ),
          ],
        ],
      ),
    );
  }
}
