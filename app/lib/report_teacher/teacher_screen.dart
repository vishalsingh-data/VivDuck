import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/duck.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../home/home_screen.dart';
import 'charts.dart';
import 'report_screen.dart';

/// Teacher Dashboard screen presenting class-wide viva performance,
/// understanding progress, trap defense stats, individual student records,
/// and where the class is weakest.
class TeacherScreen extends StatefulWidget {
  final Future<TeacherSummary>? summaryFuture;
  const TeacherScreen({super.key, this.summaryFuture});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  late Future<TeacherSummary> _future =
      widget.summaryFuture ?? createApi().getTeacherSummary();

  void _refresh() {
    setState(() {
      _future = widget.summaryFuture ?? createApi().getTeacherSummary();
    });
  }

  void _goToStudentView(BuildContext context) {
    try {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (_) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          vdRoute(const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<TeacherSummary>(
          future: _future,
          builder: (context, snap) {
            final Widget body;
            final bool hasSample =
                snap.hasData && snap.data!.sessions.any((s) => s.sample);

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
              body = _TeacherDashboard(
                summary: snap.data!,
                onRefresh: _refresh,
              );
            }

            return Column(
              children: [
                PageBody(
                  child: _TeacherHeader(
                    hasSample: hasSample,
                    onStudentView: () => _goToStudentView(context),
                    onRefresh: _refresh,
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
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

// ── 1. Header with "Student view" & "Sample class data" chip ─────────────────

class _TeacherHeader extends StatelessWidget {
  final bool hasSample;
  final VoidCallback onStudentView;
  final VoidCallback onRefresh;

  const _TeacherHeader({
    required this.hasSample,
    required this.onStudentView,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: phone ? 8 : 16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (Navigator.of(context).canPop())
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    tooltip: 'Back',
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                ),
              GestureDetector(
                onTap: onStudentView,
                child: Logo(size: phone ? 28 : 38),
              ),
              if (hasSample && !phone) ...[
                const SizedBox(width: 14),
                const _SampleChip(),
              ],
            ],
          ),
          if (hasSample && phone) const _SampleChip(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
              const ThemeToggle(),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: onStudentView,
                icon: const Icon(Icons.school_outlined, size: 16),
                label: const Text('Student view'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: phone ? 10 : 14,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SampleChip extends StatelessWidget {
  const _SampleChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: VD.tealSoft.withValues(alpha: context.isDark ? 0.25 : 0.8),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: VD.teal.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_outlined, size: 14, color: VD.teal),
          SizedBox(width: 5),
          Text(
            'Sample class data',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: VD.teal,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. Dashboard Body ────────────────────────────────────────────────────────

class _TeacherDashboard extends StatefulWidget {
  final TeacherSummary summary;
  final VoidCallback onRefresh;

  const _TeacherDashboard({
    required this.summary,
    required this.onRefresh,
  });

  @override
  State<_TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<_TeacherDashboard> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final sessions = s.sessions;
    final n = sessions.length;

    // ── 3. Three Tiles Computation ───────────────────────────────────────────
    final avgBefore = n == 0
        ? 0
        : (sessions.map((x) => x.scoreBefore).reduce((a, b) => a + b) / n)
            .round();
    final avgAfter = n == 0
        ? 0
        : (sessions.map((x) => x.scoreAfter).reduce((a, b) => a + b) / n)
            .round();
    final trapCaughtCount = sessions.where((x) => x.trapCaught).length;
    final analyseCount = sessions
        .where((x) => bloomIndex(x.bloomReached) >= bloomIndex('Analyse'))
        .length;

    // ── Find newest session that is not a sample ─────────────────────────────
    SessionSummary? newestNonSample;
    final nonSamples = sessions.where((x) => !x.sample).toList();
    if (nonSamples.isNotEmpty) {
      nonSamples.sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
      newestNonSample = nonSamples.first;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth > 900;

    // Filtered list for search if user types
    final q = _filter.trim().toLowerCase();
    final visibleSessions = q.isEmpty
        ? sessions
        : sessions
            .where((x) =>
                x.student.toLowerCase().contains(q) ||
                x.weakestKeyPoint.toLowerCase().contains(q))
            .toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            // ── 2. Title: assignment & "N students have defended their submission" ──
            FadeSlideIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CLASS REPORT',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: context.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.assignment,
                    style: (context.isPhone
                            ? context.text.headlineMedium
                            : context.text.displaySmall)
                        ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$n ${n == 1 ? "student has" : "students have"} defended their submission',
                    style: TextStyle(
                      fontSize: context.isPhone ? 15 : 17,
                      fontWeight: FontWeight.w600,
                      color: context.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 3. Three Tiles ───────────────────────────────────────────────
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: _ThreeMetricTiles(
                avgBefore: avgBefore,
                avgAfter: avgAfter,
                trapCaughtCount: trapCaughtCount,
                analyseCount: analyseCount,
                totalStudents: n,
              ),
            ),
            const SizedBox(height: 28),

            // ── 4 & 5. Table & Dark Card (Side by side > 900 px, stacked <= 900 px) ──
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _TableCard(
                            sessions: visibleSessions,
                            newestNonSample: newestNonSample,
                            onFilter: (v) => setState(() => _filter = v),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 7,
                          child: _WeakestDarkCard(
                            weakConcepts: s.weakConcepts,
                            sessions: sessions,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TableCard(
                          sessions: visibleSessions,
                          newestNonSample: newestNonSample,
                          onFilter: (v) => setState(() => _filter = v),
                        ),
                        const SizedBox(height: 24),
                        _WeakestDarkCard(
                          weakConcepts: s.weakConcepts,
                          sessions: sessions,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ── 3. Three Tiles Widget ────────────────────────────────────────────────────

class _ThreeMetricTiles extends StatelessWidget {
  final int avgBefore;
  final int avgAfter;
  final int trapCaughtCount;
  final int analyseCount;
  final int totalStudents;

  const _ThreeMetricTiles({
    required this.avgBefore,
    required this.avgAfter,
    required this.trapCaughtCount,
    required this.analyseCount,
    required this.totalStudents,
  });

  @override
  Widget build(BuildContext context) {
    final gain = avgAfter - avgBefore;
    final tile1 = _Tile(
      icon: Icons.trending_up_rounded,
      color: VD.orange,
      label: 'Average understanding',
      value: '$avgBefore → $avgAfter',
      subtitle: 'before to after (${gain >= 0 ? "+$gain" : "$gain"} pts)',
    );

    final tile2 = _Tile(
      icon: Icons.shield_rounded,
      color: VD.solid,
      label: 'Caught the trap',
      value: '$trapCaughtCount of $totalStudents',
      subtitle: totalStudents == 0
          ? '0%'
          : '${(trapCaughtCount / totalStudents * 100).round()}% protected',
    );

    final tile3 = _Tile(
      icon: Icons.psychology_rounded,
      color: VD.teal,
      label: 'Reached Analyse',
      value: '$analyseCount of $totalStudents',
      subtitle: "Bloom's taxonomy level 4+",
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 640) {
          return Column(
            children: [
              tile1,
              const SizedBox(height: 12),
              tile2,
              const SizedBox(height: 12),
              tile3,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: tile1),
            const SizedBox(width: 14),
            Expanded(child: tile2),
            const SizedBox(width: 14),
            Expanded(child: tile3),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String subtitle;

  const _Tile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return VDCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: context.isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.fredoka(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: context.ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: context.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 4. The Students Table ────────────────────────────────────────────────────

class _TableCard extends StatelessWidget {
  final List<SessionSummary> sessions;
  final SessionSummary? newestNonSample;
  final ValueChanged<String> onFilter;

  const _TableCard({
    required this.sessions,
    required this.newestNonSample,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return VDCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'Student submissions',
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? VD.darkLine
                      : context.line.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${sessions.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Horizontal scroll container so it works on phone (390 px) and any narrow screen
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _TableHead(),
                  const Divider(height: 1),
                  if (sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No student submissions found.',
                          style: TextStyle(color: context.inkSoft),
                        ),
                      ),
                    )
                  else
                    for (final s in sessions)
                      _TableRow(
                        session: s,
                        isJustFinished: newestNonSample != null &&
                            s.sessionId == newestNonSample!.sessionId,
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

class _TableHead extends StatelessWidget {
  const _TableHead();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
      color: context.inkSoft,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 200, child: Text('STUDENT', style: style)),
          SizedBox(width: 155, child: Text('UNDERSTANDING', style: style)),
          SizedBox(width: 110, child: Text('LEVEL REACHED', style: style)),
          SizedBox(width: 110, child: Text('TRAP', style: style)),
          Expanded(child: Text('WEAKEST POINT', style: style)),
        ],
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  final SessionSummary session;
  final bool isJustFinished;

  const _TableRow({
    required this.session,
    required this.isJustFinished,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hover = false;

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: context.surface,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => _StudentReportSheet(session: widget.session),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final isJf = widget.isJustFinished;

    final bg = isJf
        ? (context.isDark
            ? const Color(0xFF1E382B)
            : const Color(0xFFE8F5E9))
        : (_hover
            ? (context.isDark ? VD.darkLine : const Color(0xFFF7F4EB))
            : Colors.transparent);

    final border = isJf
        ? Border.all(color: VD.solid, width: 1.5)
        : Border(top: BorderSide(color: context.line.withValues(alpha: 0.6)));

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _open(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: EdgeInsets.symmetric(vertical: isJf ? 3 : 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(isJf ? 10 : 0),
            border: border,
          ),
          child: Row(
            children: [
              // 1. Student column (Name + Avatar + "Just finished" badge)
              SizedBox(
                width: 200,
                child: Row(
                  children: [
                    _StudentAvatar(name: s.student),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  s.student,
                                  style: TextStyle(
                                    fontWeight: isJf
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    fontSize: 13.5,
                                    color: context.ink,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (isJf) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: VD.solid,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fiber_manual_record,
                                    size: 7,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Just finished',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (s.sample) ...[
                            Text(
                              'Sample',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.inkSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Understanding column (before to after, with thin bar for after score)
              SizedBox(
                width: 155,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.scoreBefore} → ${s.scoreAfter}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: context.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Thin bar for the after score
                      SizedBox(
                        height: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: (s.scoreAfter / 100).clamp(0.0, 1.0),
                            backgroundColor: context.line,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              VD.orange,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Level reached column
              SizedBox(
                width: 110,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: VD.teal.withValues(
                        alpha: context.isDark ? 0.25 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      s.bloomReached,
                      style: const TextStyle(
                        color: VD.teal,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Trap column (Caught or Missed, with an icon)
              SizedBox(
                width: 110,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      s.trapCaught
                          ? Icons.shield_rounded
                          : Icons.warning_amber_rounded,
                      color: s.trapCaught ? VD.solid : VD.missing,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      s.trapCaught ? 'Caught' : 'Missed',
                      style: TextStyle(
                        color: s.trapCaught ? VD.solid : VD.missing,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),

              // 5. Weakest point column
              Expanded(
                child: Text(
                  s.weakestKeyPoint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  final String name;
  const _StudentAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join();
    final hue = (name.hashCode.abs() % 360).toDouble();
    return CircleAvatar(
      radius: 16,
      backgroundColor: HSLColor.fromAHSL(
        1,
        hue,
        0.55,
        context.isDark ? 0.35 : 0.82,
      ).toColor(),
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 11.5,
          color: context.isDark ? Colors.white : VD.ink,
        ),
      ),
    );
  }
}

// ── 5. Dark Card: "Where the class is weakest" ───────────────────────────────

class _WeakestDarkCard extends StatelessWidget {
  final List<WeakConcept> weakConcepts;
  final List<SessionSummary> sessions;

  const _WeakestDarkCard({
    required this.weakConcepts,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    // If weakConcepts is empty from server/fixture, compute from sessions
    List<WeakConcept> items = weakConcepts;
    if (items.isEmpty && sessions.isNotEmpty) {
      final counts = <String, int>{};
      for (final s in sessions) {
        counts[s.weakestKeyPoint] = (counts[s.weakestKeyPoint] ?? 0) + 1;
      }
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      items = [
        for (final e in sorted.take(3))
          WeakConcept(
            concept: e.key,
            count: e.value,
            total: sessions.length,
          ),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF14192A), // Dark card background in both modes
        borderRadius: BorderRadius.circular(VD.radius),
        border: Border.all(
          color: const Color(0xFF28314E),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: VD.missing.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.report_problem_rounded,
                  color: VD.missing,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Where the class is weakest',
                  style: GoogleFonts.fredoka(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Concepts that proved hardest for students to defend under questioning.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFFA3ABC6),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),

          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No weak concepts recorded yet.',
                style: TextStyle(color: Color(0xFFA3ABC6)),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${items[i].count} of ${items[i].total}',
                          style: const TextStyle(
                            color: Color(0xFFCBD2E6),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // One bar per weak concept
                    SizedBox(
                      height: 8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: items[i].total == 0
                              ? 0.0
                              : (items[i].count / items[i].total)
                                  .clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFF252D47),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            i == 0
                                ? VD.missing
                                : (i == 1 ? VD.partial : VD.orange),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

          const SizedBox(height: 6),
          // The required line: "This shows what each student could explain. What it means is the teacher's call."
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.09),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: VD.yellow,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'This shows what each student could explain. What it means is the teacher\'s call.',
                    style: TextStyle(
                      color: Color(0xFFCBD2E8),
                      fontSize: 12.5,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
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

// ── Student Detail Sheet ─────────────────────────────────────────────────────

class _StudentReportSheet extends StatelessWidget {
  final SessionSummary session;
  const _StudentReportSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StudentAvatar(name: s.student),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.student,
                      style: context.text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      s.sample ? 'Sample student' : 'Live submission',
                      style: TextStyle(color: context.inkSoft, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ScoreRing(
                before: s.scoreBefore,
                after: s.scoreAfter,
                size: 110,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.scoreBefore} → ${s.scoreAfter}',
                      style: context.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                vdRoute(ReportScreen(sessionId: s.sessionId)),
              );
            },
            icon: const Icon(Icons.description_rounded),
            label: const Text('Open full report'),
          ),
        ],
      ),
    );
  }
}
