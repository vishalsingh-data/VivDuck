import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/auth.dart';
import '../core/duck.dart';
import '../core/effects.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'viva_screen.dart';

class _Sample {
  final String id, title, kind, language, asset, blurb;
  final IconData icon;
  const _Sample(
    this.id,
    this.title,
    this.kind,
    this.language,
    this.asset,
    this.blurb,
    this.icon,
  );
}

const _samples = [
  _Sample(
    'binary_search',
    'Binary search',
    'code',
    'python',
    'assets/samples/binary_search.py',
    'Iterative search in a sorted list',
    Icons.search_rounded,
  ),
  _Sample(
    'factorial_recursive',
    'Recursive factorial',
    'code',
    'python',
    'assets/samples/factorial_recursive.py',
    'Base cases and recursion',
    Icons.functions_rounded,
  ),
  _Sample(
    'normalisation',
    'Database normalisation',
    'text',
    'english',
    'assets/samples/normalisation.txt',
    '1NF, 2NF and 3NF explained',
    Icons.table_chart_rounded,
  ),
];

const _languages = ['python', 'java', 'javascript', 'c', 'cpp', 'other'];

class SubmitScreen extends StatefulWidget {
  const SubmitScreen({super.key});

  @override
  State<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends State<SubmitScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: Auth.instance.user?.name);
  final _title = TextEditingController();
  final _submission = TextEditingController();
  String _kind = 'code';
  String _language = 'python';
  String? _sampleId;
  bool _busy = false;
  int _hop = 0;

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _submission.dispose();
    super.dispose();
  }

  Future<void> _useSample(_Sample s) async {
    final body = await rootBundle.loadString(s.asset);
    setState(() {
      _sampleId = s.id;
      _hop++;
      _kind = s.kind;
      if (s.kind == 'code') _language = s.language;
      _title.text = s.title;
      _submission.text = body;
    });
  }

  Future<void> _start() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final req = CreateSessionRequest(
      studentName: _name.text.trim(),
      title: _title.text.trim(),
      kind: _kind,
      submission: _submission.text,
      language: _kind == 'code' ? _language : 'english',
      sampleId: _sampleId,
    );
    try {
      final id = await VivaApi.instance.createSession(req);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(vdRoute(VivaScreen(sessionId: id, request: req)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.width >= Breakpoints.desktop;
    final details = _DetailsColumn(
      name: _name,
      title: _title,
      kind: _kind,
      language: _language,
      sampleId: _sampleId,
      onKind: (k) => setState(() {
        _kind = k;
        _sampleId = null;
      }),
      onLanguage: (l) => setState(() => _language = l),
      onSample: _useSample,
    );
    final editor = _Editor(
      controller: _submission,
      kind: _kind,
      onEdited: () {
        if (_sampleId != null) setState(() => _sampleId = null);
      },
    );
    final startButton = SizedBox(
      width: double.infinity,
      child: Shine(
        child: FilledButton.icon(
          onPressed: _busy ? null : _start,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : const Icon(Icons.forum_rounded),
          label: Text(_busy ? 'Waking the duck…' : 'Start my viva'),
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const VDTopBar(showBack: true, actions: [ThemeToggle()]),
                  FadeSlideIn(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'What are we defending today?',
                                style: context.isPhone
                                    ? context.text.headlineMedium
                                    : context.text.headlineLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Paste your work or pick a sample. The duck reads it before asking anything.',
                                style: context.text.bodyLarge?.copyWith(
                                  color: context.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!context.isPhone)
                          Duck(
                            size: 96,
                            mood: DuckMood.curious,
                            jumpSignal: _hop,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 380,
                          child: Column(
                            children: [
                              details,
                              const SizedBox(height: 20),
                              startButton,
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: editor),
                      ],
                    )
                  else ...[
                    details,
                    const SizedBox(height: 20),
                    editor,
                    const SizedBox(height: 20),
                    startButton,
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsColumn extends StatelessWidget {
  final TextEditingController name, title;
  final String kind, language;
  final String? sampleId;
  final ValueChanged<String> onKind, onLanguage;
  final ValueChanged<_Sample> onSample;

  const _DetailsColumn({
    required this.name,
    required this.title,
    required this.kind,
    required this.language,
    required this.sampleId,
    required this.onKind,
    required this.onLanguage,
    required this.onSample,
  });

  @override
  Widget build(BuildContext context) {
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Required' : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VDCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Label('Try a sample'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _samples)
                    _SampleChip(
                      sample: s,
                      selected: sampleId == s.id,
                      onTap: () => onSample(s),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        VDCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Label('Your name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: name,
                validator: required,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  hintText: 'e.g. Alice Nguyen',
                ),
              ),
              const SizedBox(height: 16),
              _Label('Assignment title'),
              const SizedBox(height: 8),
              TextFormField(
                controller: title,
                validator: required,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'e.g. Binary search',
                ),
              ),
              const SizedBox(height: 16),
              _Label('Type of work'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'code',
                    label: Text('Code'),
                    icon: Icon(Icons.code_rounded),
                  ),
                  ButtonSegment(
                    value: 'text',
                    label: Text('Writing'),
                    icon: Icon(Icons.notes_rounded),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: (s) => onKind(s.first),
                showSelectedIcon: false,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: kind != 'code'
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Label('Language'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: language,
                              borderRadius: BorderRadius.circular(14),
                              items: [
                                for (final l in _languages)
                                  DropdownMenuItem(
                                    value: l,
                                    child: Text(_prettyLang(l)),
                                  ),
                              ],
                              onChanged: (v) => onLanguage(v!),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _prettyLang(String l) => switch (l) {
  'javascript' => 'JavaScript',
  'cpp' => 'C++',
  'c' => 'C',
  _ => l[0].toUpperCase() + l.substring(1),
};

class _SampleChip extends StatelessWidget {
  final _Sample sample;
  final bool selected;
  final VoidCallback onTap;
  const _SampleChip({
    required this.sample,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: sample.blurb,
      child: ChoiceChip(
        avatar: Icon(
          sample.icon,
          size: 18,
          color: selected ? VD.ink : context.inkSoft,
        ),
        label: Text(sample.title),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: VD.yellow,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? VD.ink : context.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? VD.yellow : context.line,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 12,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w800,
      color: context.inkSoft,
    ),
  );
}

class _Editor extends StatelessWidget {
  final TextEditingController controller;
  final String kind;
  final VoidCallback onEdited;
  const _Editor({
    required this.controller,
    required this.kind,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final code = kind == 'code';
    return VDCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.line, width: 1.5),
              ),
            ),
            child: Row(
              children: [
                for (final c in [VD.missing, VD.partial, VD.solid])
                  Container(
                    width: 11,
                    height: 11,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                const SizedBox(width: 8),
                Icon(
                  code ? Icons.code_rounded : Icons.notes_rounded,
                  size: 16,
                  color: context.inkSoft,
                ),
                const SizedBox(width: 6),
                Text(
                  code ? 'Your code' : 'Your writing',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.inkSoft,
                  ),
                ),
                const Spacer(),
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, v, _) => Text(
                    '${'\n'.allMatches(v.text).length + (v.text.isEmpty ? 0 : 1)} lines',
                    style: TextStyle(fontSize: 12, color: context.inkSoft),
                  ),
                ),
              ],
            ),
          ),
          TextFormField(
            controller: controller,
            onChanged: (_) => onEdited(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Paste your work or choose a sample'
                : null,
            minLines: context.isPhone ? 10 : 18,
            maxLines: context.isPhone ? 16 : 26,
            style: code
                ? monoStyle(context)
                : context.text.bodyLarge?.copyWith(height: 1.6),
            decoration: InputDecoration(
              hintText: code
                  ? 'def my_function():\n    ...'
                  : 'Paste your essay or answer here…',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
        ],
      ),
    );
  }
}
