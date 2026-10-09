import 'package:flutter/material.dart';

import '../core/ambient.dart';
import '../core/api.dart';
import '../core/duck.dart';
import '../core/models.dart';
import '../core/page_picker.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'charts.dart';
import 'rubric_points.dart';

/// Teacher-only: scan a student's whole answer sheet and grade every
/// question on it against its rubric (contract 10).
class SheetsScreen extends StatefulWidget {
  const SheetsScreen({super.key});

  @override
  State<SheetsScreen> createState() => _SheetsScreenState();
}

class _SheetsScreenState extends State<SheetsScreen> {
  late Future<List<AnswerSheet>> _future = VivaApi.instance.getSheets();

  void _refresh() => setState(() => _future = VivaApi.instance.getSheets());

  Future<void> _new() async {
    await Navigator.of(context).push(vdRoute(const SheetGradeScreen()));
    _refresh();
  }

  void _openSheet(AnswerSheet s) => Navigator.of(
    context,
  ).push(vdRoute(SheetResultScreen(sheetId: s.sheetId)));

  @override
  Widget build(BuildContext context) {
    return _Page(
      onRefresh: _refresh,
      child: FutureBuilder<List<AnswerSheet>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorState(
              message: snap.error.toString(),
              onRetry: _refresh,
            );
          }
          if (!snap.hasData) {
            return const Center(
              child: Duck(size: 120, mood: DuckMood.thinking),
            );
          }
          final sheets = snap.data!;
          return SingleChildScrollView(
            child: PageBody(
              maxWidth: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Eyebrow('ANSWER SHEETS'),
                  const SizedBox(height: 4),
                  Text(
                    'Grade a whole answer sheet',
                    style: context.isPhone
                        ? context.text.headlineMedium
                        : context.text.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Scan a student's handwritten exam, pick the questions it answers, and the duck finds each answer, reads it, and grades it against that question's rubric. You check the text before anything is graded.",
                    style: TextStyle(color: context.inkSoft),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _new,
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Grade an answer sheet'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Graded sheets', style: context.text.titleMedium),
                  const SizedBox(height: 10),
                  if (sheets.isEmpty)
                    Text('None yet.', style: TextStyle(color: context.inkSoft))
                  else
                    for (final s in sheets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SheetRow(sheet: s, onTap: () => _openSheet(s)),
                      ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final AnswerSheet sheet;
  final VoidCallback onTap;
  const _SheetRow({required this.sheet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = sheet;
    final d = s.createdAt.toLocal();
    return VDCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.student,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    '${s.answered} of ${s.questions} answered',
                    '${d.day}/${d.month}/${d.year}',
                    if (s.gradedBy != null) 'by ${s.gradedBy}',
                  ].join(' · '),
                  style: TextStyle(color: context.inkSoft, fontSize: 13),
                ),
              ],
            ),
          ),
          if (s.needsReview) ...[
            const Pill('Review', color: VD.partial, icon: Icons.flag_rounded),
            const SizedBox(width: 12),
          ],
          Text(
            '${formatMarks(s.totalMarks)} / ${s.maxMarks}',
            style: context.text.titleMedium,
          ),
        ],
      ),
    );
  }
}

// ── Grade a new sheet ────────────────────────────────────────────────────────

/// Student, questions and pages; then the text found for each question, for
/// the teacher to check; then grading.
class SheetGradeScreen extends StatefulWidget {
  const SheetGradeScreen({super.key});

  @override
  State<SheetGradeScreen> createState() => _SheetGradeScreenState();
}

class _SheetGradeScreenState extends State<SheetGradeScreen> {
  final _questions = VivaApi.instance.getQuestions();
  final _name = TextEditingController();

  /// In the order the teacher picked them: Q1, Q2, ...
  final List<Question> _picked = [];
  List<UploadPage> _pages = const [];

  /// Set once the sheet has been read; one per picked question.
  List<SheetAnswer>? _answers;
  List<TextEditingController> _texts = [];

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    for (final c in _texts) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canRead =>
      !_busy &&
      _name.text.trim().isNotEmpty &&
      _picked.isNotEmpty &&
      _pages.isNotEmpty;

  void _toggle(Question q) => setState(() {
    _error = null;
    if (!_picked.remove(q) && _picked.length < maxSheetQuestions) {
      _picked.add(q);
    }
  });

  Future<void> _read() async {
    if (!_canRead) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final answers = await VivaApi.instance.readSheet([
        for (final q in _picked) q.id,
      ], _pages);
      if (!mounted) return;
      setState(() {
        _answers = answers;
        _texts = [
          for (final a in answers)
            TextEditingController(text: a.transcription.text)
              ..addListener(() => setState(() {})),
        ];
        _busy = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  void _startOver() => setState(() {
    for (final c in _texts) {
      c.dispose();
    }
    _texts = [];
    _answers = null;
    _error = null;
  });

  Future<void> _grade() async {
    final answers = _answers;
    if (answers == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sheet = await VivaApi.instance.gradeSheet(_name.text.trim(), [
        for (var i = 0; i < answers.length; i++)
          (
            questionId: answers[i].questionId,
            text: _texts[i].text.trim(),
            transcription: answers[i].found ? answers[i].transcription : null,
            edited: _texts[i].text.trim() != answers[i].transcription.text,
          ),
      ]);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(vdRoute(SheetResultScreen(sheet: sheet)));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final answers = _answers;
    return _Page(
      child: SingleChildScrollView(
        child: PageBody(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Eyebrow('GRADE AN ANSWER SHEET'),
              const SizedBox(height: 4),
              Text(
                answers == null ? 'Scan the sheet' : 'Check what was read',
                style: context.isPhone
                    ? context.text.headlineMedium
                    : context.text.displaySmall,
              ),
              const SizedBox(height: 24),
              if (answers == null) ..._setup() else ..._review(answers),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: VD.missing,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _setup() => [
    const _StepLabel(n: 1, label: 'Student'),
    const SizedBox(height: 12),
    Semantics(
      label: "Student's name",
      child: TextField(
        controller: _name,
        enabled: !_busy,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(hintText: "Student's name"),
      ),
    ),
    const SizedBox(height: 28),
    const _StepLabel(n: 2, label: 'Questions on this exam'),
    const SizedBox(height: 4),
    Text(
      'Pick them in exam order (up to $maxSheetQuestions). The duck finds each answer by the numbers the student wrote, or by topic.',
      style: TextStyle(color: context.inkSoft, fontSize: 13.5),
    ),
    const SizedBox(height: 12),
    FutureBuilder<List<Question>>(
      future: _questions,
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            "Couldn't load the questions. ${snap.error}",
            style: TextStyle(color: context.inkSoft),
          );
        }
        if (!snap.hasData) return const LinearProgressIndicator();
        return Column(
          children: [
            for (final q in snap.data!)
              _QuestionTick(
                question: q,
                number: _picked.indexOf(q) + 1,
                enabled:
                    !_busy &&
                    (_picked.contains(q) || _picked.length < maxSheetQuestions),
                onTap: () => _toggle(q),
              ),
          ],
        );
      },
    ),
    const SizedBox(height: 28),
    const _StepLabel(n: 3, label: 'The answer sheet'),
    const SizedBox(height: 12),
    PagePicker(
      pages: _pages,
      enabled: !_busy,
      what: "the student's answer sheet",
      onChanged: (p) => setState(() {
        _pages = p;
        _error = null;
      }),
    ),
    const SizedBox(height: 20),
    SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _canRead ? _read : null,
        icon: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : const Icon(Icons.text_snippet_outlined),
        label: Text(
          _busy
              ? 'Finding and reading each answer…'
              : _picked.isEmpty
              ? 'Read the sheet'
              : 'Read the sheet for ${_picked.length} ${_picked.length == 1 ? 'question' : 'questions'}',
        ),
      ),
    ),
  ];

  List<Widget> _review(List<SheetAnswer> answers) {
    final found = answers.where((a) => a.found).length;
    return [
      Text(
        'Found $found of ${answers.length} answers for ${_name.text.trim()}. Correct any words the duck misread, and fill in or clear an answer if it was matched to the wrong question. An empty answer scores 0.',
        style: TextStyle(color: context.inkSoft),
      ),
      const SizedBox(height: 16),
      for (var i = 0; i < answers.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _AnswerCheck(
            number: i + 1,
            question: _picked[i],
            answer: answers[i],
            controller: _texts[i],
            enabled: !_busy,
          ),
        ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _grade,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.fact_check_outlined),
            label: Text(
              _busy
                  ? 'Grading each answer against its rubric…'
                  : 'Grade ${answers.length} ${answers.length == 1 ? 'answer' : 'answers'}',
            ),
          ),
          TextButton.icon(
            onPressed: _busy ? null : _startOver,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Change questions or pages'),
          ),
        ],
      ),
      if (_busy) ...[
        const SizedBox(height: 8),
        Text(
          'Each answer is graded twice, one question at a time. This can take a minute.',
          style: TextStyle(color: context.inkSoft, fontSize: 13),
        ),
      ],
    ];
  }
}

class _QuestionTick extends StatelessWidget {
  final Question question;

  /// 1-based position in the exam, or 0 when not picked.
  final int number;
  final bool enabled;
  final VoidCallback onTap;

  const _QuestionTick({
    required this.question,
    required this.number,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    final on = number > 0;
    return Semantics(
      checked: on,
      button: true,
      label: '${q.title}, ${q.marks} marks${on ? ', question $number' : ''}',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(VD.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 34,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? context.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: on ? context.ink : context.line),
                  ),
                  child: Text(
                    on ? 'Q$number' : '',
                    style: TextStyle(
                      color: context.surface,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Opacity(
                    opacity: enabled ? 1 : 0.5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          q.prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.inkSoft,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${q.marks} marks',
                  style: TextStyle(color: context.inkSoft, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerCheck extends StatelessWidget {
  final int number;
  final Question question;
  final SheetAnswer answer;
  final TextEditingController controller;
  final bool enabled;

  const _AnswerCheck({
    required this.number,
    required this.question,
    required this.answer,
    required this.controller,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final empty = controller.text.trim().isEmpty;
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Q$number · ${question.title}',
                  style: context.text.titleMedium,
                ),
              ),
              if (!answer.found)
                const Pill('Not found', color: VD.missing)
              else if (answer.transcription.unclear)
                const Pill('Hard to read', color: VD.partial)
              else
                const Pill('Read clearly', color: VD.solid),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            question.prompt,
            style: TextStyle(color: context.inkSoft, fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Answer to question $number',
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 3,
              maxLines: 14,
              decoration: InputDecoration(
                hintText: answer.found
                    ? 'No answer: this question will score 0.'
                    : 'No answer to this question was found on the sheet. Type it here if the duck missed it.',
              ),
            ),
          ),
          if (!empty && controller.text.contains('[?]')) ...[
            const SizedBox(height: 6),
            const Text(
              'Still has [?]. It will be graded as written.',
              style: TextStyle(color: VD.partial, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ── A graded sheet ───────────────────────────────────────────────────────────

/// Total marks, then every question with its marks, review flags and the
/// rubric points with the student's own words as evidence.
class SheetResultScreen extends StatefulWidget {
  /// Shown straight away after grading; otherwise loaded by [sheetId].
  final AnswerSheet? sheet;
  final String? sheetId;
  const SheetResultScreen({super.key, this.sheet, this.sheetId})
    : assert(sheet != null || sheetId != null);

  @override
  State<SheetResultScreen> createState() => _SheetResultScreenState();
}

class _SheetResultScreenState extends State<SheetResultScreen> {
  late Future<AnswerSheet> _future = _load();

  Future<AnswerSheet> _load() => widget.sheet != null
      ? Future.value(widget.sheet!)
      : VivaApi.instance.getSheet(widget.sheetId!);

  @override
  Widget build(BuildContext context) {
    return _Page(
      child: FutureBuilder<AnswerSheet>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorState(
              message: snap.error.toString(),
              onRetry: () => setState(() => _future = _load()),
            );
          }
          if (!snap.hasData) {
            return const Center(
              child: Duck(size: 120, mood: DuckMood.thinking),
            );
          }
          final s = snap.data!;
          final flagged = s.items.where((i) => i.grade.review.needsReview);
          return SingleChildScrollView(
            child: PageBody(
              maxWidth: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Eyebrow('ANSWER SHEET'),
                  const SizedBox(height: 4),
                  Text(
                    s.student,
                    style: context.isPhone
                        ? context.text.headlineMedium
                        : context.text.displaySmall,
                  ),
                  const SizedBox(height: 16),
                  VDCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${formatMarks(s.totalMarks)} / ${s.maxMarks}',
                                style: context.text.displaySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  'marks',
                                  '${s.answered} of ${s.questions} questions answered',
                                  if (flagged.isNotEmpty)
                                    '${flagged.length} to review',
                                ].join(' · '),
                                style: TextStyle(color: context.inkSoft),
                              ),
                            ],
                          ),
                        ),
                        _Percent(
                          s.maxMarks == 0
                              ? 0
                              : (100 * s.totalMarks / s.maxMarks).round(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Each answer was graded on its own against its rubric, twice. Marks come from fixed rules, never from the AI directly, and every mark cites the student\'s words.',
                    style: TextStyle(color: context.inkSoft, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < s.items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ItemCard(number: i + 1, item: s.items[i]),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Percent extends StatelessWidget {
  final int pct;
  const _Percent(this.pct);

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 64,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CircularProgressIndicator(
          value: pct / 100,
          strokeWidth: 6,
          backgroundColor: context.line,
          color: pct >= 70
              ? VD.solid
              : pct >= 40
              ? VD.partial
              : VD.missing,
        ),
        Center(
          child: Text(
            '$pct%',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _ItemCard extends StatelessWidget {
  final int number;
  final SheetItem item;
  const _ItemCard({required this.number, required this.item});

  @override
  Widget build(BuildContext context) {
    final it = item;
    int count(KeyPointStatus st) =>
        it.grade.points.where((p) => p.status == st).length;
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Q$number · ${it.title}',
                  style: context.text.titleLarge,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${formatMarks(it.marks)} / ${it.maxMarks}',
                style: context.text.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(it.prompt, style: TextStyle(color: context.inkSoft)),
          const SizedBox(height: 12),
          if (!it.answered)
            const Align(
              alignment: Alignment.centerLeft,
              child: Pill('Not answered', color: VD.missing),
            )
          else ...[
            if (it.grade.review.needsReview) ...[
              ReviewBanner(review: it.grade.review, forTeacher: true),
              const SizedBox(height: 12),
            ],
            GradingRunsNote(runs: it.grade.runs),
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(
                  'The answer as graded',
                  style: context.text.titleSmall,
                ),
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SelectableText(
                      it.answerText,
                      style: context.text.bodyMedium?.copyWith(height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            StatusBar(
              solid: count(KeyPointStatus.solid),
              partial: count(KeyPointStatus.partial),
              missing: count(KeyPointStatus.missing),
            ),
            const SizedBox(height: 6),
            for (final p in it.grade.points) RubricPointTile(point: p),
          ],
        ],
      ),
    );
  }
}

// ── Shared bits ──────────────────────────────────────────────────────────────

class _Page extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRefresh;
  const _Page({required this.child, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Ambient(
        child: SafeArea(
          child: Column(
            children: [
              PageBody(
                child: VDTopBar(
                  showBack: true,
                  actions: [
                    if (onRefresh != null)
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    const ThemeToggle(),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String text;
  const _Eyebrow(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      letterSpacing: 1,
      fontWeight: FontWeight.w600,
      color: context.inkSoft,
    ),
  );
}

class _StepLabel extends StatelessWidget {
  final int n;
  final String label;
  const _StepLabel({required this.n, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.ink,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$n',
            style: TextStyle(
              color: context.surface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(label, style: context.text.titleMedium),
      ],
    );
  }
}
