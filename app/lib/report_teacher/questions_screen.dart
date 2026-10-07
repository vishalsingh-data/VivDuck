import 'package:flutter/material.dart';

import '../core/ambient.dart';
import '../core/api.dart';
import '../core/duck.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Teacher-only: the questions students can pick, and a way to set new ones.
class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  late Future<List<Question>> _future = VivaApi.instance.getQuestions();

  void _refresh() => setState(() => _future = VivaApi.instance.getQuestions());

  Future<void> _new() async {
    final published = await Navigator.of(
      context,
    ).push<Question>(vdRoute(const QuestionEditorScreen()));
    if (published != null) _refresh();
  }

  Future<void> _delete(Question q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this question?'),
        content: Text(
          'Students will no longer see "${q.title}". Answers already graded keep their rubric and report.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await VivaApi.instance.deleteQuestion(q.id);
      _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

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
                child: FutureBuilder<List<Question>>(
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
                    final mine = snap.data!
                        .where((q) => q.origin == 'teacher')
                        .toList();
                    final samples = snap.data!
                        .where((q) => q.origin == 'sample')
                        .toList();
                    return SingleChildScrollView(
                      child: PageBody(
                        maxWidth: 900,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'QUESTIONS',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w600,
                                color: context.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Set any question',
                              style: context.isPhone
                                  ? context.text.headlineMedium
                                  : context.text.displaySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Type a question in any subject. The duck drafts a rubric with key points, a trap claim and follow-ups. You edit it, then publish it to your students.',
                              style: TextStyle(color: context.inkSoft),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.icon(
                                onPressed: _new,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('New question'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Your published questions',
                              style: context.text.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            if (mine.isEmpty)
                              Text(
                                'None yet. Students can still answer the sample questions below, or type their own.',
                                style: TextStyle(color: context.inkSoft),
                              )
                            else
                              for (final q in mine)
                                _QuestionRow(
                                  question: q,
                                  onDelete: () => _delete(q),
                                ),
                            const SizedBox(height: 24),
                            Text(
                              'Sample questions',
                              style: context.text.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            for (final q in samples) _QuestionRow(question: q),
                            const SizedBox(height: 32),
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

class _QuestionRow extends StatelessWidget {
  final Question question;
  final VoidCallback? onDelete;
  const _QuestionRow({required this.question, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final q = question;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VDCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.title, style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (q.subject.isNotEmpty) q.subject,
                      '${q.marks} marks',
                      '${q.points} rubric points',
                    ].join(' · '),
                    style: TextStyle(color: context.inkSoft, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q.prompt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.inkSoft, fontSize: 13.5),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Remove',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: context.inkSoft,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Editor ───────────────────────────────────────────────────────────────────

class _PointEdit {
  final statement = TextEditingController();
  final hint = TextEditingController();
  final probe = TextEditingController();
  int weight;

  _PointEdit([DraftPoint? p]) : weight = p?.weight ?? 2 {
    statement.text = p?.statement ?? '';
    hint.text = p?.hint ?? '';
    probe.text = p?.probe ?? '';
  }

  void dispose() {
    statement.dispose();
    hint.dispose();
    probe.dispose();
  }

  DraftPoint toPoint() => DraftPoint(
    statement: statement.text.trim(),
    weight: weight,
    hint: hint.text.trim(),
    probe: probe.text.trim(),
  );
}

/// Write a question, let the duck draft its rubric, edit it, publish it.
/// Pops with the published [Question].
class QuestionEditorScreen extends StatefulWidget {
  const QuestionEditorScreen({super.key});

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _prompt = TextEditingController();
  final _subject = TextEditingController();
  final _modelAnswer = TextEditingController();
  int _marks = 10;

  // Filled once the rubric is drafted.
  bool _drafted = false;
  final _title = TextEditingController();
  final _trapClaim = TextEditingController();
  final _trapTruth = TextEditingController();
  final _whatIf = TextEditingController();
  final List<_PointEdit> _points = [];

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _prompt,
      _subject,
      _modelAnswer,
      _title,
      _trapClaim,
      _trapTruth,
      _whatIf,
    ]) {
      c.dispose();
    }
    for (final p in _points) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _draft() async {
    if (_prompt.text.trim().length < 10) {
      setState(() => _error = 'Write the full question first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await VivaApi.instance.draftQuestion(
        prompt: _prompt.text.trim(),
        subject: _subject.text.trim(),
        marks: _marks,
        modelAnswer: _modelAnswer.text.trim(),
      );
      if (!mounted) return;
      for (final p in _points) {
        p.dispose();
      }
      _points
        ..clear()
        ..addAll(d.points.map(_PointEdit.new));
      _title.text = d.title;
      if (_subject.text.trim().isEmpty) _subject.text = d.subject;
      _trapClaim.text = d.trapClaim;
      _trapTruth.text = d.trapTruth;
      _whatIf.text = d.whatIf;
      setState(() {
        _drafted = true;
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

  Future<void> _publish() async {
    if (!_form.currentState!.validate()) return;
    if (_points.length < 2) {
      setState(() => _error = 'A rubric needs at least 2 points.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final q = await VivaApi.instance.publishQuestion(
        QuestionDraft(
          title: _title.text.trim(),
          subject: _subject.text.trim(),
          prompt: _prompt.text.trim(),
          marks: _marks,
          points: [for (final p in _points) p.toPoint()],
          trapClaim: _trapClaim.text.trim(),
          trapTruth: _trapTruth.text.trim(),
          whatIf: _whatIf.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(q);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  String? _required(String? v, {int min = 3}) =>
      (v == null || v.trim().length < min) ? 'Required' : null;

  Widget _field(
    TextEditingController c, {
    required String label,
    String? hint,
    int lines = 1,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      enabled: !_busy,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 4,
      validator: validator,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Ambient(
        child: SafeArea(
          child: Column(
            children: [
              PageBody(
                child: VDTopBar(showBack: true, actions: const [ThemeToggle()]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: PageBody(
                    maxWidth: 820,
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'New question',
                            style: context.isPhone
                                ? context.text.headlineMedium
                                : context.text.displaySmall,
                          ),
                          const SizedBox(height: 20),
                          _Section(
                            n: 1,
                            title: 'The question',
                            children: [
                              _field(
                                _prompt,
                                label: 'Question',
                                hint:
                                    'Any subject or language, e.g. "Explain how photosynthesis works and why it matters."',
                                lines: 3,
                                validator: (v) => _required(v, min: 10),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _field(
                                      _subject,
                                      label: 'Subject (optional)',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 120,
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _marks,
                                      decoration: const InputDecoration(
                                        labelText: 'Marks',
                                      ),
                                      items: [
                                        for (final m in [5, 10, 15, 20, 25])
                                          DropdownMenuItem(
                                            value: m,
                                            child: Text('$m'),
                                          ),
                                      ],
                                      onChanged: _busy
                                          ? null
                                          : (m) => setState(() => _marks = m!),
                                    ),
                                  ),
                                ],
                              ),
                              _field(
                                _modelAnswer,
                                label: 'Model answer (optional)',
                                hint:
                                    'If you paste one, the rubric points are based on it.',
                                lines: 3,
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child:
                                    (_drafted
                                    ? OutlinedButton.icon
                                    : FilledButton.icon)(
                                      onPressed: _busy ? null : _draft,
                                      icon: _busy && !_drafted
                                          ? const SizedBox.square(
                                              dimension: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.auto_awesome_rounded,
                                            ),
                                      label: Text(
                                        _drafted
                                            ? 'Draft again'
                                            : (_busy
                                                  ? 'Drafting the rubric…'
                                                  : 'Draft rubric with AI'),
                                      ),
                                    ),
                              ),
                            ],
                          ),
                          if (_drafted) ...[
                            const SizedBox(height: 20),
                            _Section(
                              n: 2,
                              title: 'Check the rubric',
                              subtitle:
                                  'The duck grades against exactly these points. Weight 3 = core idea, 1 = nice to have.',
                              children: [
                                _field(
                                  _title,
                                  label: 'Short title',
                                  validator: _required,
                                ),
                                for (var i = 0; i < _points.length; i++)
                                  _PointEditor(
                                    key: ObjectKey(_points[i]),
                                    n: i + 1,
                                    point: _points[i],
                                    enabled: !_busy,
                                    onWeight: (w) =>
                                        setState(() => _points[i].weight = w),
                                    onRemove: _points.length > 2
                                        ? () => setState(
                                            () => _points.removeAt(i).dispose(),
                                          )
                                        : null,
                                  ),
                                if (_points.length < 10)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => setState(
                                              () => _points.add(_PointEdit()),
                                            ),
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Add a point'),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _Section(
                              n: 3,
                              title: 'Follow-up questions',
                              subtitle:
                                  'After grading, the duck asks about the weakest point, then the what-if, then states the false claim and asks if the student agrees.',
                              children: [
                                _field(
                                  _whatIf,
                                  label: 'What-if question',
                                  lines: 2,
                                  validator: _required,
                                ),
                                _field(
                                  _trapClaim,
                                  label: 'False claim (the trap)',
                                  hint:
                                      'Must be clearly false. A student who understands should reject it.',
                                  lines: 2,
                                  validator: _required,
                                ),
                                _field(
                                  _trapTruth,
                                  label: 'Why it is false',
                                  lines: 2,
                                  validator: _required,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _publish,
                                icon: const Icon(Icons.publish_rounded),
                                label: Text(
                                  _busy ? 'Publishing…' : 'Publish to students',
                                ),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Row(
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
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

class _Section extends StatelessWidget {
  final int n;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const _Section({
    required this.n,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$n · $title', style: context.text.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(color: context.inkSoft, fontSize: 13.5),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _PointEditor extends StatelessWidget {
  final int n;
  final _PointEdit point;
  final bool enabled;
  final ValueChanged<int> onWeight;
  final VoidCallback? onRemove;

  const _PointEditor({
    super.key,
    required this.n,
    required this.point,
    required this.enabled,
    required this.onWeight,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Point $n', style: context.text.titleSmall),
              const Spacer(),
              Text(
                'Weight',
                style: TextStyle(color: context.inkSoft, fontSize: 13),
              ),
              const SizedBox(width: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                ],
                selected: {point.weight},
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: enabled ? (s) => onWeight(s.first) : null,
              ),
              IconButton(
                tooltip: 'Remove point',
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (c, label, lines) in [
            (point.statement, 'What a good answer says', 2),
            (point.hint, 'Hint for the student (optional)', 1),
            (point.probe, 'Follow-up question for this point (optional)', 1),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10, right: 6),
              child: TextFormField(
                controller: c,
                enabled: enabled,
                minLines: lines,
                maxLines: lines + 3,
                textCapitalization: TextCapitalization.sentences,
                validator: c == point.statement
                    ? (v) =>
                          (v == null || v.trim().length < 3) ? 'Required' : null
                    : null,
                decoration: InputDecoration(labelText: label),
              ),
            ),
        ],
      ),
    );
  }
}
