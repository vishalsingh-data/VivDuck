import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'session_controller.dart';

/// Pick a question (a teacher's, a sample, or the student's own), answer it by
/// typing or with a photo of a handwritten page, and hand the finished
/// request to [onSubmit].
class AnswerForm extends StatefulWidget {
  /// The signed-in student's name; when null the form asks for it.
  final String? studentName;

  /// Grades the answer. Throws [ApiException] on failure; the form shows it.
  final Future<void> Function(CreateSessionRequest req) onSubmit;

  const AnswerForm({super.key, this.studentName, required this.onSubmit});

  @override
  State<AnswerForm> createState() => _AnswerFormState();
}

enum _Mode { typed, photo }

class _AnswerFormState extends State<AnswerForm> {
  late Future<List<Question>> _questions = VivaApi.instance.getQuestions();
  final _name = TextEditingController();
  final _answer = TextEditingController();
  final _transcript = TextEditingController();
  final _customPrompt = TextEditingController();
  final _customSubject = TextEditingController();
  Question? _question;

  /// The student is writing their own question instead of picking one.
  bool _custom = false;
  _Mode _mode = _Mode.typed;
  bool _pasted = false;
  int _lastLength = 0;

  // Photo flow.
  Uint8List? _photo;
  Transcription? _transcription;
  bool _reading = false;

  bool _busy = false;
  String? _error;

  void _reloadQuestions() =>
      setState(() => _questions = VivaApi.instance.getQuestions());

  @override
  void initState() {
    super.initState();
    questionsChanged.addListener(_reloadQuestions);
    _answer.addListener(() {
      final len = _answer.text.length;
      if (looksPasted(_lastLength, len)) _pasted = true;
      if (len == 0) _pasted = false;
      _lastLength = len;
      setState(() {});
    });
    _transcript.addListener(() => setState(() {}));
    _name.addListener(() => setState(() {}));
    _customPrompt.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    questionsChanged.removeListener(_reloadQuestions);
    _name.dispose();
    _answer.dispose();
    _transcript.dispose();
    _customPrompt.dispose();
    _customSubject.dispose();
    super.dispose();
  }

  /// The question being answered: the picked one, or the student's own once
  /// it is long enough to grade.
  Question? get _selected => _custom
      ? (_customPrompt.text.trim().length >= 10
            ? Question.custom(
                _customPrompt.text,
                subject: _customSubject.text.trim(),
              )
            : null)
      : _question;

  String get _studentName => widget.studentName ?? _name.text.trim();

  String get _text =>
      (_mode == _Mode.typed ? _answer.text : _transcript.text).trim();

  bool get _ready =>
      !_busy &&
      !_reading &&
      _selected != null &&
      _studentName.isNotEmpty &&
      _text.isNotEmpty &&
      (_mode == _Mode.typed || _transcription != null);

  Future<void> _pick(ImageSource source) async {
    final q = _selected;
    if (q == null) return;
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2200,
        imageQuality: 85,
      );
    } catch (_) {
      setState(() => _error = "Couldn't open the camera or your photos.");
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    final mime =
        file.mimeType ?? (name.endsWith('.png') ? 'image/png' : 'image/jpeg');
    setState(() {
      _photo = bytes;
      _transcription = null;
      _reading = true;
      _error = null;
    });
    try {
      final t = await VivaApi.instance.transcribe(q.id, bytes, mime);
      if (!mounted) return;
      _transcript.text = t.text;
      setState(() {
        _transcription = t;
        _reading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _photo = null;
        _error = e.message;
      });
    }
  }

  Future<void> _submit() async {
    if (!_ready) return;
    final t = _transcription;
    final req = CreateSessionRequest(
      studentName: _studentName,
      question: _selected!,
      answerText: _text,
      source: _mode == _Mode.typed ? 'typed' : 'photo',
      pasted: _mode == _Mode.typed && _pasted,
      transcription: _mode == _Mode.photo ? t : null,
      transcriptionEdited:
          _mode == _Mode.photo &&
          t != null &&
          _transcript.text.trim() != t.text.trim(),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(req);
      if (mounted) setState(() => _busy = false);
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
    return FutureBuilder<List<Question>>(
      future: _questions,
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            "Couldn't load the questions. ${snap.error}",
            style: TextStyle(color: context.inkSoft),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final questions = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Step(n: 1, label: 'Choose a question'),
            const SizedBox(height: 12),
            _QuestionPicker(
              questions: questions,
              selected: _custom ? null : _question,
              custom: _custom,
              onSelect: (q) => setState(() {
                _question = q;
                _custom = false;
                _error = null;
              }),
              onCustom: () => setState(() {
                _custom = true;
                _error = null;
              }),
            ),
            if (_question != null || _custom) ...[
              const SizedBox(height: 16),
              if (_custom)
                _CustomQuestion(prompt: _customPrompt, subject: _customSubject)
              else
                _Prompt(question: _question!),
              const SizedBox(height: 28),
              const _Step(n: 2, label: 'Your answer'),
              const SizedBox(height: 12),
              if (widget.studentName == null) ...[
                Semantics(
                  label: 'Your name',
                  child: TextField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(hintText: 'Your name'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<_Mode>(
                  segments: const [
                    ButtonSegment(
                      value: _Mode.typed,
                      label: Text('Type it'),
                      icon: Icon(Icons.keyboard_outlined),
                    ),
                    ButtonSegment(
                      value: _Mode.photo,
                      label: Text('Photo of handwriting'),
                      icon: Icon(Icons.photo_camera_outlined),
                    ),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() {
                    _mode = s.first;
                    _error = null;
                  }),
                ),
              ),
              const SizedBox(height: 12),
              if (_mode == _Mode.typed)
                _TypedAnswer(controller: _answer, pasted: _pasted)
              else
                _PhotoAnswer(
                  photo: _photo,
                  reading: _reading,
                  transcription: _transcription,
                  controller: _transcript,
                  onPick: _pick,
                  onRetake: () => setState(() {
                    _photo = null;
                    _transcription = null;
                  }),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _ready ? _submit : null,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.fact_check_outlined),
                  label: Text(
                    _busy
                        ? (_custom
                              ? 'Writing a rubric, then grading…'
                              : 'Grading against the rubric…')
                        : _mode == _Mode.photo
                        ? 'Confirm text and grade'
                        : 'Grade my answer',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Graded against the rubric, then 3 follow-up questions. About 5 minutes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.inkSoft, fontSize: 13),
              ),
            ],
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
          ],
        );
      },
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String label;
  const _Step({required this.n, required this.label});

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

class _QuestionPicker extends StatelessWidget {
  final List<Question> questions;
  final Question? selected;
  final bool custom;
  final ValueChanged<Question> onSelect;
  final VoidCallback onCustom;
  const _QuestionPicker({
    required this.questions,
    required this.selected,
    required this.custom,
    required this.onSelect,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final q in questions)
        _QuestionCard(
          question: q,
          selected: selected?.id == q.id,
          onTap: () => onSelect(q),
        ),
      _QuestionCard(
        question: const Question(
          id: Question.customId,
          title: 'Your own question',
          subject: 'Any subject',
          prompt: '',
          marks: 10,
          points: 0,
          origin: 'custom',
        ),
        selected: custom,
        onTap: onCustom,
      ),
    ];
    // A grid that grows with the number of questions: 1 column on phones,
    // up to 3 on wide screens.
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth < 560 ? 1 : (c.maxWidth < 860 ? 2 : 3);
        final w = (c.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      },
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final Question question;
  final bool selected;
  final VoidCallback onTap;
  const _QuestionCard({
    required this.question,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    return Semantics(
      button: true,
      selected: selected,
      label: q.isCustom
          ? 'Your own question, any subject'
          : '${q.title}, ${q.subject}, ${q.marks} marks',
      child: Material(
        color: context.surface,
        borderRadius: BorderRadius.circular(VD.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VD.radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VD.radius),
              border: Border.all(
                color: selected ? context.ink : context.line,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (q.isCustom) ...[
                        Icon(
                          Icons.edit_note_rounded,
                          size: 16,
                          color: context.inkSoft,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          (q.subject.isEmpty ? 'General' : q.subject)
                              .toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                            color: context.inkSoft,
                          ),
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 18,
                        color: selected ? context.ink : context.inkSoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    q.isCustom
                        ? 'Type any question. The duck writes a rubric for it.'
                        : q.origin == 'teacher'
                        ? 'Set by ${q.author ?? 'your teacher'} · ${q.marks} marks'
                        : '${q.marks} marks · ${q.points} rubric points',
                    style: TextStyle(color: context.inkSoft, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomQuestion extends StatelessWidget {
  final TextEditingController prompt, subject;
  const _CustomQuestion({required this.prompt, required this.subject});

  @override
  Widget build(BuildContext context) {
    final short =
        prompt.text.trim().isNotEmpty && prompt.text.trim().length < 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Your question',
          child: TextField(
            controller: prompt,
            minLines: 2,
            maxLines: 6,
            maxLength: 3000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'Type or paste the question, e.g. "Explain how photosynthesis works and why it matters."',
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          label: 'Subject (optional)',
          child: TextField(
            controller: subject,
            maxLength: 60,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Subject (optional), e.g. Biology',
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 15, color: context.inkSoft),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                short
                    ? 'Write the full question (at least 10 characters).'
                    : 'Works for any subject or language. The duck drafts a rubric for your question, and your teacher can check it.',
                style: TextStyle(color: context.inkSoft, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Prompt extends StatelessWidget {
  final Question question;
  const _Prompt({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(VD.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUESTION · ${question.marks} MARKS',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: context.inkSoft,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            question.prompt,
            style: context.text.bodyLarge?.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _TypedAnswer extends StatelessWidget {
  final TextEditingController controller;
  final bool pasted;
  const _TypedAnswer({required this.controller, required this.pasted});

  @override
  Widget build(BuildContext context) {
    final words = controller.text.trim().isEmpty
        ? 0
        : controller.text.trim().split(RegExp(r'\s+')).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Your answer',
          child: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 18,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'Write your answer in full sentences, as you would in an exam.',
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (pasted) ...[
              const Icon(
                Icons.content_paste_rounded,
                size: 15,
                color: VD.partial,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Looks pasted. Pasted answers are sent to your teacher for review.',
                  style: TextStyle(color: context.inkSoft, fontSize: 12.5),
                ),
              ),
            ] else
              const Spacer(),
            Text(
              '$words words',
              style: TextStyle(color: context.inkSoft, fontSize: 12.5),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoAnswer extends StatelessWidget {
  final Uint8List? photo;
  final bool reading;
  final Transcription? transcription;
  final TextEditingController controller;
  final void Function(ImageSource) onPick;
  final VoidCallback onRetake;

  const _PhotoAnswer({
    required this.photo,
    required this.reading,
    required this.transcription,
    required this.controller,
    required this.onPick,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VD.radius),
          border: Border.all(color: context.line),
          color: context.surface,
        ),
        child: Column(
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 32,
              color: context.inkSoft,
            ),
            const SizedBox(height: 10),
            Text(
              'Photograph your handwritten answer',
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'One page, flat and well lit. You will check the text before it is graded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.inkSoft, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => onPick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take photo'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onPick(ImageSource.gallery),
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Upload photo'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.memory(photo!, width: 120, height: 150, fit: BoxFit.cover),
    );
    final t = transcription;
    final unresolved = controller.text.contains('[?]');
    final body = reading || t == null
        ? Row(
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reading your handwriting…',
                  style: context.text.titleMedium,
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    t.unclear
                        ? Icons.info_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 18,
                    color: t.unclear ? VD.partial : VD.solid,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.unclear
                          ? 'Check the text against your page. Words marked [?] could not be read; type what you wrote.'
                          : 'Check the text matches your page, then grade it.',
                      style: TextStyle(color: context.inkSoft, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Semantics(
                label: 'Transcribed answer',
                child: TextField(
                  controller: controller,
                  minLines: 6,
                  maxLines: 16,
                  decoration: const InputDecoration(),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (unresolved)
                    Expanded(
                      child: Text(
                        'Still has [?]. It will be graded as written.',
                        style: const TextStyle(
                          color: VD.partial,
                          fontSize: 12.5,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  TextButton.icon(
                    onPressed: onRetake,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Use a different photo'),
                  ),
                ],
              ),
            ],
          );

    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < 520
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [thumb, const SizedBox(height: 12), body],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                thumb,
                const SizedBox(width: 16),
                Expanded(child: body),
              ],
            ),
    );
  }
}
