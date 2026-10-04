import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/duck.dart';
import '../core/effects.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../report_teacher/report_screen.dart';

/// Total student turns in a viva: opening explanation + probe + what-if + trap.
const _totalRounds = 4;

/// A single insertion this long is treated as a paste.
const _pasteThreshold = 25;

class _Msg {
  final bool fromDuck;
  final String text;
  final String? type; // opening | probe | what_if | trap
  final bool pasted;
  const _Msg.duck(this.text, this.type) : fromDuck = true, pasted = false;
  const _Msg.student(this.text, {this.pasted = false})
    : fromDuck = false,
      type = null;
}

class _QType {
  final String label;
  final IconData icon;
  final Color color;
  final DuckMood mood;
  const _QType(this.label, this.icon, this.color, this.mood);
}

_QType _qType(String? t) => switch (t) {
  'probe' => const _QType(
    'Probe',
    Icons.search_rounded,
    VD.teal,
    DuckMood.curious,
  ),
  'what_if' => const _QType(
    'What if?',
    Icons.alt_route_rounded,
    VD.orange,
    DuckMood.curious,
  ),
  // Don't reveal it's a trap to the student — that's on the report.
  'trap' => const _QType(
    'Curveball',
    Icons.sports_baseball_rounded,
    Color(0xFF8B5CF6),
    DuckMood.sly,
  ),
  _ => const _QType(
    'Warm-up',
    Icons.waving_hand_rounded,
    VD.partial,
    DuckMood.idle,
  ),
};

class VivaScreen extends StatefulWidget {
  final String sessionId;
  final CreateSessionRequest request;
  const VivaScreen({super.key, required this.sessionId, required this.request});

  @override
  State<VivaScreen> createState() => _VivaScreenState();
}

class _VivaScreenState extends State<VivaScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final List<_Msg> _messages = [];
  final _confetti = ConfettiController();
  int _round = 0;
  bool _thinking = false;
  bool _done = false;
  bool _pasted = false;
  String? _error;
  int _lastLength = 0;

  @override
  void initState() {
    super.initState();
    final first = widget.request.studentName.split(' ').first;
    final what = widget.request.kind == 'code' ? 'code' : 'writing';
    _messages.add(
      _Msg.duck(
        "Hi $first! I've read your $what on “${widget.request.title}”. "
            'Start by walking me through it in your own words — what does it do, and how?',
        'opening',
      ),
    );
    _input.addListener(_detectPaste);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _detectPaste() {
    final len = _input.text.length;
    if (len - _lastLength >= _pasteThreshold && !_pasted) {
      setState(() => _pasted = true);
    }
    if (len == 0 && _pasted) setState(() => _pasted = false);
    _lastLength = len;
  }

  DuckMood get _mood {
    if (_done) return DuckMood.happy;
    if (_thinking) return DuckMood.thinking;
    final last = _messages.lastWhere((m) => m.fromDuck);
    return _qType(last.type).mood;
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _thinking || _done) return;
    final pasted = _pasted;
    setState(() {
      _messages.add(_Msg.student(text, pasted: pasted));
      _input.clear();
      _pasted = false;
      _lastLength = 0;
      _error = null;
    });
    await _submit(text, pasted);
  }

  Future<void> _submit(String text, bool pasted) async {
    setState(() {
      _thinking = true;
      _error = null;
    });
    _scrollToEnd();
    try {
      final res = await VivaApi.instance.submitTurn(
        widget.sessionId,
        text,
        pasted: pasted,
      );
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _round = res.round;
        if (res.done) {
          _done = true;
          _messages.add(
            const _Msg.duck(
              "That's a wrap! Thanks for talking it through with me. "
                  "I'm putting together your report now.",
              'done',
            ),
          );
        } else {
          _messages.add(_Msg.duck(res.question ?? '…', res.questionType));
        }
      });
      if (_done) _confetti.fire(origin: const Offset(0.5, 0.6));
      if (!_done) _focus.requestFocus();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _error = e.message;
      });
    }
    _scrollToEnd();
  }

  void _retry() {
    final last = _messages.lastWhere((m) => !m.fromDuck);
    _submit(last.text, last.pasted);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<bool> _confirmLeave() async {
    if (_done || _messages.length <= 1) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave this viva?'),
        content: const Text("Your answers so far won't be scored."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  void _openReport() {
    Navigator.of(
      context,
    ).pushReplacement(vdRoute(ReportScreen(sessionId: widget.sessionId)));
  }

  void _showSubmission() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.surface,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (c, sc) => SingleChildScrollView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: _SubmissionView(request: widget.request),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.width >= Breakpoints.desktop;
    final chat = _ChatColumn(
      messages: _messages,
      scroll: _scroll,
      thinking: _thinking,
      error: _error,
      onRetry: _retry,
      footer: _done
          ? _DoneBar(onReport: _openReport)
          : _Composer(
              controller: _input,
              focus: _focus,
              pasted: _pasted,
              enabled: !_thinking,
              onSend: _send,
            ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Confetti(
        controller: _confetti,
        child: Scaffold(
          body: SafeArea(
            child: PageBody(
              maxWidth: 1240,
              child: Column(
                children: [
                  VDTopBar(
                    showBack: true,
                    actions: [
                      if (!wide)
                        IconButton(
                          tooltip: 'View my work',
                          onPressed: _showSubmission,
                          icon: const Icon(Icons.description_outlined),
                        ),
                      const ThemeToggle(),
                    ],
                  ),
                  if (!wide) ...[
                    _CompactHeader(mood: _mood, round: _round, done: _done),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 360,
                                child: _SidePanel(
                                  mood: _mood,
                                  round: _round,
                                  done: _done,
                                  request: widget.request,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(child: chat),
                            ],
                          )
                        : chat,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Progress ─────────────────────────────────────────────────────────────────

const _stepLabels = ['Explain', 'Probe', 'What if', 'Curveball'];

class _Progress extends StatelessWidget {
  final int round;
  final bool done;
  final bool compact;
  const _Progress({
    required this.round,
    required this.done,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _totalRounds; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      end: i < round || done ? 1 : (i == round ? 0.35 : 0),
                    ),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      backgroundColor: context.line,
                      color: i < round || done ? VD.solid : VD.yellow,
                    ),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 6),
                  Text(
                    _stepLabels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == round && !done
                          ? FontWeight.w900
                          : FontWeight.w600,
                      color: i == round && !done
                          ? context.ink
                          : context.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (i < _totalRounds - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _CompactHeader extends StatelessWidget {
  final DuckMood mood;
  final int round;
  final bool done;
  const _CompactHeader({
    required this.mood,
    required this.round,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Duck(size: 56, mood: mood, jumpSignal: round),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                done
                    ? 'Viva complete'
                    : 'Question ${round + 1} of $_totalRounds',
                style: context.text.titleMedium,
              ),
              const SizedBox(height: 6),
              _Progress(round: round, done: done, compact: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidePanel extends StatelessWidget {
  final DuckMood mood;
  final int round;
  final bool done;
  final CreateSessionRequest request;
  const _SidePanel({
    required this.mood,
    required this.round,
    required this.done,
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final status = switch (mood) {
      DuckMood.thinking => 'Thinking about your answer…',
      DuckMood.happy => 'All done, nice work!',
      DuckMood.sly => 'Think carefully about this one.',
      DuckMood.curious => 'Curious about your reasoning.',
      DuckMood.idle || DuckMood.shy => 'Listening.',
    };
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VDCard(
            child: Column(
              children: [
                Duck(size: 150, mood: mood, jumpSignal: round),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    status,
                    key: ValueKey(status),
                    style: context.text.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                _Progress(round: round, done: done),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VDCard(child: _SubmissionView(request: request, maxLines: 18)),
        ],
      ),
    );
  }
}

class _SubmissionView extends StatelessWidget {
  final CreateSessionRequest request;
  final int? maxLines;
  const _SubmissionView({required this.request, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final code = request.kind == 'code';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              code ? Icons.code_rounded : Icons.notes_rounded,
              size: 18,
              color: context.inkSoft,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(request.title, style: context.text.titleMedium),
            ),
            if (code && request.language != null)
              Pill(request.language!, color: VD.teal),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SingleChildScrollView(
            scrollDirection: code ? Axis.horizontal : Axis.vertical,
            child: Text(
              request.submission,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.fade,
              style: code
                  ? monoStyle(context, size: 12.5)
                  : context.text.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Chat ─────────────────────────────────────────────────────────────────────

class _ChatColumn extends StatelessWidget {
  final List<_Msg> messages;
  final ScrollController scroll;
  final bool thinking;
  final String? error;
  final VoidCallback onRetry;
  final Widget footer;

  const _ChatColumn({
    required this.messages,
    required this.scroll,
    required this.thinking,
    required this.error,
    required this.onRetry,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return VDCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: EdgeInsets.all(context.isPhone ? 14 : 24),
              children: [
                for (final m in messages)
                  FadeSlideIn(
                    key: ObjectKey(m),
                    from: Offset(m.fromDuck ? -0.04 : 0.04, 0.05),
                    child: _Bubble(msg: m),
                  ),
                if (thinking) const _TypingBubble(),
                if (error != null) _ErrorRow(message: error!, onRetry: onRetry),
              ],
            ),
          ),
          Divider(height: 1.5, thickness: 1.5, color: context.line),
          Padding(
            padding: EdgeInsets.all(context.isPhone ? 10 : 16),
            child: footer,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final duck = msg.fromDuck;
    final q = _qType(msg.type);
    final maxW = context.isPhone ? context.width * 0.82 : 560.0;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: duck
            ? (context.isDark ? VD.darkBg : VD.yellowSoft)
            : (context.isDark ? const Color(0xFF3B4A80) : VD.ink),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(duck ? 6 : 20),
          bottomRight: Radius.circular(duck ? 20 : 6),
        ),
        border: duck && msg.type == 'trap'
            ? Border.all(color: q.color.withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (duck && msg.type != null && msg.type != 'done') ...[
            Pill(q.label, color: q.color, icon: q.icon),
            const SizedBox(height: 8),
          ],
          SelectableText(
            msg.text,
            style: context.text.bodyLarge?.copyWith(
              height: 1.5,
              color: duck ? context.ink : Colors.white,
              fontWeight: duck ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: duck
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (duck) ...[
            Duck(
              size: 36,
              float: false,
              mood: msg.type == 'done' ? DuckMood.happy : DuckMood.idle,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: duck
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                bubble,
                if (msg.pasted)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.content_paste_rounded,
                          size: 13,
                          color: VD.partial,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Pasted',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.inkSoft,
                          ),
                        ),
                      ],
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

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Duck(size: 36, float: false, mood: DuckMood.thinking),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: context.isDark ? VD.darkBg : VD.yellowSoft,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
              ),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Transform.translate(
                      offset: Offset(0, -4 * _wave(_c.value, i)),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.inkSoft.withValues(
                            alpha: 0.5 + 0.5 * _wave(_c.value, i),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 5),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _wave(double t, int i) {
    final x = (t - i * 0.18) % 1.0;
    return x < 0.5 ? math.sin(x * 2 * math.pi) : 0;
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRow({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: VD.missing.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: VD.missing, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool pasted;
  final bool enabled;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.focus,
    required this.pasted,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: pasted
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.content_paste_rounded,
                        size: 16,
                        color: VD.partial,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Looks pasted. The duck learns more from your own words, and your teacher will see a paste flag.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: CallbackShortcuts(
                bindings: {
                  if (!phone)
                    const SingleActivator(LogicalKeyboardKey.enter): onSend,
                },
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  autofocus: !phone,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: enabled
                        ? 'Explain in your own words…'
                        : 'The duck is thinking…',
                    helperText: phone
                        ? null
                        : 'Enter to send · Shift+Enter for a new line',
                    helperStyle: TextStyle(
                      color: context.inkSoft,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: EdgeInsets.only(bottom: phone ? 4 : 26),
              child: ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, v, _) {
                  final can = enabled && v.text.trim().isNotEmpty;
                  return AnimatedScale(
                    scale: can ? 1 : 0.9,
                    duration: const Duration(milliseconds: 150),
                    child: IconButton.filled(
                      tooltip: 'Send',
                      onPressed: can ? onSend : null,
                      style: IconButton.styleFrom(
                        backgroundColor: VD.orange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(50, 50),
                      ),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DoneBar extends StatelessWidget {
  final VoidCallback onReport;
  const _DoneBar({required this.onReport});

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Row(
        children: [
          const Icon(Icons.celebration_rounded, color: VD.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Viva complete. Your report is ready.',
              style: context.text.titleMedium,
            ),
          ),
          Shine(
            child: FilledButton.icon(
              onPressed: onReport,
              icon: const Icon(Icons.auto_graph_rounded),
              label: const Text('See report'),
            ),
          ),
        ],
      ),
    );
  }
}
