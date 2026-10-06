import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../auth/auth_screen.dart';
import '../core/api.dart';
import '../core/auth.dart';
import '../core/duck.dart';
import '../core/effects.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'teacher_screen.dart';
import 'widgets/bloom_badge.dart';
import 'widgets/key_point_tile.dart';
import 'widgets/score_ring.dart';

/// Provides an API client for loading reports.
/// When `--dart-define=FIXTURES=true` is supplied, or when offline mock data
/// doesn't contain the requested session, it falls back to the bundled fixture.
VivaApi createApi() {
  const bool fixtures = bool.fromEnvironment('FIXTURES', defaultValue: false);
  if (fixtures) {
    return _FixtureVivaApi();
  }
  return _FixtureFallbackVivaApi(VivaApi.instance);
}

class _FixtureVivaApi implements VivaApi {
  @override
  bool get isMock => true;

  @override
  Future<String> createSession(CreateSessionRequest req) =>
      VivaApi.instance.createSession(req);

  @override
  Future<TurnResponse> submitTurn(
    String sessionId,
    String text, {
    required bool pasted,
  }) =>
      VivaApi.instance.submitTurn(sessionId, text, pasted: pasted);

  @override
  Future<TeacherSummary> getTeacherSummary() =>
      VivaApi.instance.getTeacherSummary();

  @override
  Future<Report> getReport(String sessionId) async {
    final raw = await rootBundle.loadString('assets/fixtures/03_report.json');
    final j = (jsonDecode(raw) as Map<String, dynamic>)['response']
        as Map<String, dynamic>;
    return Report.fromJson({
      ...j,
      'session_id': sessionId,
    });
  }
}

class _FixtureFallbackVivaApi implements VivaApi {
  final VivaApi _inner;
  _FixtureFallbackVivaApi(this._inner);

  @override
  bool get isMock => _inner.isMock;

  @override
  Future<String> createSession(CreateSessionRequest req) =>
      _inner.createSession(req);

  @override
  Future<TurnResponse> submitTurn(
    String sessionId,
    String text, {
    required bool pasted,
  }) =>
      _inner.submitTurn(sessionId, text, pasted: pasted);

  @override
  Future<TeacherSummary> getTeacherSummary() => _inner.getTeacherSummary();

  @override
  Future<Report> getReport(String sessionId) async {
    try {
      return await _inner.getReport(sessionId);
    } catch (_) {
      if (_inner.isMock) {
        final raw =
            await rootBundle.loadString('assets/fixtures/03_report.json');
        final j = (jsonDecode(raw) as Map<String, dynamic>)['response']
            as Map<String, dynamic>;
        return Report.fromJson({
          ...j,
          'session_id': sessionId,
        });
      }
      rethrow;
    }
  }
}

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
        return await createApi().getReport(widget.sessionId);
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
          const SizedBox(height: 16),
          Text(
            'Marking your viva…',
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Checking every key point against what you said.',
            style: TextStyle(color: context.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Shows the report and fires celebratory confetti if there was a big gain.
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
    const gap = SizedBox(height: 20);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 48),
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. "Viva report" with the submission title
            FadeSlideIn(child: _Header(report: report)),
            const SizedBox(height: 24),

            // 2. A card with ScoreRing, "Understanding", the two scores as "54 to 79",
            // and a two-line legend. If paste_flags > 0, shows a note.
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: _ScoreCard(report: report),
            ),
            gap,

            // 3. Two tiles side by side: "Level reached" with BloomBadge,
            // and "Trap question" showing "Caught" or "Missed" with one line of explanation.
            FadeSlideIn(
              delay: const Duration(milliseconds: 160),
              child: _SideBySideTiles(report: report),
            ),
            gap,

            // 4. "What you could explain": one KeyPointTile per key point.
            FadeSlideIn(
              delay: const Duration(milliseconds: 240),
              child: _KeyPointsSection(report: report),
            ),
            gap,

            // 5. "Review next": the review_next items.
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: _ReviewNextSection(items: report.reviewNext),
            ),
            const SizedBox(height: 32),

            // 6. Two buttons: "Try again" goes to the "/" route and clears the history;
            // "Done" goes to the "/teacher" route.
            FadeSlideIn(
              delay: const Duration(milliseconds: 360),
              child: const _ActionButtons(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 1. Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Report report;
  const _Header({required this.report});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Viva report',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color: context.inkSoft,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                report.title,
                style: (context.isPhone
                        ? context.text.headlineMedium
                        : context.text.displaySmall)
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Duck(size: context.isPhone ? 72 : 96, mood: DuckMood.happy),
      ],
    );
  }
}

// ── 2. Understanding Card with ScoreRing ──────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final Report report;
  const _ScoreCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final gain = report.scoreAfter - report.scoreBefore;
    final ring = ScoreRing(
      before: report.scoreBefore,
      after: report.scoreAfter,
      size: phone ? 150 : 170,
    );

    final blueColor = context.isDark
        ? const Color(0xFF93AAFF)
        : const Color(0xFF2450E0);
    final greyColor = context.isDark
        ? const Color(0xFF7E8BAA)
        : context.inkSoft;

    final content = Column(
      crossAxisAlignment:
          phone ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Understanding',
          style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '${report.scoreBefore} to ${report.scoreAfter}',
          style: TextStyle(
            fontSize: phone ? 22 : 26,
            fontWeight: FontWeight.w900,
            color: blueColor,
          ),
        ),
        const SizedBox(height: 14),
        _Legend(
          color: greyColor,
          label: 'Before the viva',
          value: report.scoreBefore,
        ),
        const SizedBox(height: 8),
        _Legend(
          color: blueColor,
          label: 'After the viva',
          value: report.scoreAfter,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: phone ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Pill(
              '${gain >= 0 ? '+' : ''}$gain points',
              color: gain >= 0 ? VD.solid : VD.missing,
              icon: gain >= 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
            ),
            if (report.pasteFlags > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: VD.partial.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: VD.partial.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.content_paste_rounded,
                      size: 14,
                      color: VD.partial,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${report.pasteFlags} ${report.pasteFlags == 1 ? 'answer was' : 'answers were'} pasted',
                      style: const TextStyle(
                        color: VD.partial,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );

    return VDCard(
      padding: EdgeInsets.all(phone ? 18 : 24),
      child: phone
          ? Column(
              children: [
                ring,
                const SizedBox(height: 18),
                content,
              ],
            )
          : Row(
              children: [
                ring,
                const SizedBox(width: 28),
                Expanded(child: content),
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
          style: TextStyle(
            color: context.inkSoft,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$value',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: context.ink,
          ),
        ),
      ],
    );
  }
}

// ── 3. Two Tiles Side by Side: Level reached & Trap question ──────────────────

class _SideBySideTiles extends StatelessWidget {
  final Report report;
  const _SideBySideTiles({required this.report});

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final gap = phone ? 12.0 : 16.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _BloomTile(level: report.bloomReached)),
          SizedBox(width: gap),
          Expanded(child: _TrapTile(report: report)),
        ],
      ),
    );
  }
}

class _BloomTile extends StatelessWidget {
  final String level;
  const _BloomTile({required this.level});

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    return VDCard(
      padding: EdgeInsets.all(phone ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Level reached',
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: phone ? 15 : 17,
            ),
          ),
          const SizedBox(height: 12),
          BloomBadge(level),
        ],
      ),
    );
  }
}

class _TrapTile extends StatelessWidget {
  final Report report;
  const _TrapTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final caught = report.trapCaught;
    final c = caught ? VD.solid : VD.missing;
    final statusText = caught ? 'Caught' : 'Missed';
    final explanation = report.trapExplanation?.trim().isNotEmpty == true
        ? report.trapExplanation!
        : (caught
            ? 'Spotted the deliberate trap question.'
            : 'Did not notice the trap question.');
    final phone = context.isPhone;

    return VDCard(
      padding: EdgeInsets.all(phone ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Trap question',
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: phone ? 15 : 17,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Pill(
                statusText,
                color: c,
                icon: caught
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: TextStyle(
              fontSize: phone ? 16 : 18,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            explanation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.inkSoft,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 4. What you could explain: one KeyPointTile per key point ─────────────────

class _KeyPointsSection extends StatelessWidget {
  final Report report;
  const _KeyPointsSection({required this.report});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'What you could explain',
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${report.keyPoints.length} key points',
              style: TextStyle(
                color: context.inkSoft,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final kp in report.keyPoints) KeyPointTile(kp),
      ],
    );
  }
}

// ── 5. Review next: review_next items ─────────────────────────────────────────

class _ReviewNextSection extends StatelessWidget {
  final List<String> items;
  const _ReviewNextSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return VDCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: VD.teal),
              const SizedBox(width: 8),
              Text(
                'Review next',
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7),
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: VD.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items[i],
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

// ── 6. Two Buttons: Try again & Done ──────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  void _onTryAgain(BuildContext context) {
    try {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (_) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  void _onDone(BuildContext context) {
    try {
      Navigator.of(context).pushNamed('/teacher');
    } catch (_) {
      Navigator.of(context).push(vdRoute(const TeacherScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          onPressed: () => _onTryAgain(context),
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Try again'),
        ),
        FilledButton.icon(
          onPressed: () => _onDone(context),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Done'),
        ),
      ],
    );
  }
}
