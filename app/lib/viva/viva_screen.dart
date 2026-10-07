import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ambient.dart';
import '../core/duck.dart';
import '../core/effects.dart';
import '../core/models.dart';
import '../core/shell_scope.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../report_teacher/report_screen.dart';
import 'session_controller.dart';

/// At this width and above the submission sits in a panel beside the chat.
const _sideBySideWidth = 900.0;

class _QType {
  final String label;
  final IconData icon;
  final Color color;
  final DuckMood mood;
  const _QType(this.label, this.icon, this.color, this.mood);
}

_QType _qType(String? t) => switch (t) {
  'probe' => const _QType(
    'Question · Understand',
    Icons.search_rounded,
    VD.teal,
    DuckMood.curious,
  ),
  'what_if' => const _QType(
    'Question · Apply',
    Icons.alt_route_rounded,
    VD.orange,
    DuckMood.curious,
  ),
  // Don't reveal it's a trap to the student — that's on the report.
  'trap' => const _QType(
    'Question · Analyse',
    Icons.psychology_alt_outlined,
    Color(0xFF6D5BD0),
    DuckMood.playful,
  ),
  _ => const _QType(
    'Marked',
    Icons.chat_bubble_outline_rounded,
    VD.inkSoft,
    DuckMood.idle,
  ),
};

class VivaScreen extends StatefulWidget {
  final SessionController controller;

  /// Opens the follow-up chat for a graded answer, or one restored from the
  /// device. The screen takes ownership of [controller].
  const VivaScreen.withController(this.controller, {super.key});

  @override
  State<VivaScreen> createState() => _VivaScreenState();
}

class _VivaScreenState extends State<VivaScreen> {
  late final SessionController _c = widget.controller;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _confetti = ConfettiController();
  bool _pasted = false;
  int _lastLength = 0;
  int _seenMessages = 0;

  List<VivaMessage> get _messages => _c.messages;
  CreateSessionRequest get _request => _c.request!;

  @override
  void initState() {
    super.initState();
    _seenMessages = _c.messages.length;
    _c.addListener(_onChange);
    _input.addListener(_detectPaste);
    _scrollToEnd();
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _c.dispose();
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    if (_c.messages.length > _seenMessages &&
        _c.messages.last.fromDuck &&
        !_c.finished) {
      _focus.requestFocus();
    }
    _seenMessages = _c.messages.length;
    _scrollToEnd();
  }

  void _detectPaste() {
    final len = _input.text.length;
    if (looksPasted(_lastLength, len) && !_pasted) {
      setState(() => _pasted = true);
    }
    if (len == 0 && _pasted) setState(() => _pasted = false);
    _lastLength = len;
  }

  DuckMood get _mood {
    if (_c.finished) return DuckMood.happy;
    if (_c.loading) return DuckMood.thinking;
    final last = _messages.lastWhere((m) => m.fromDuck);
    return _qType(last.type).mood;
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty ||
        _c.loading ||
        _c.finished ||
        _c.expired ||
        _c.awaitingReply) {
      return;
    }
    final pasted = _pasted;
    _input.clear();
    _pasted = false;
    _lastLength = 0;
    _c.sendAnswer(text, pasted: pasted);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Bubbles below the fold are laid out lazily, so the end can move once
      // they are reached; follow it a few times so the newest is in view.
      for (var i = 0; i < 4; i++) {
        if (!mounted || !_scroll.hasClients) return;
        final end = _scroll.position.maxScrollExtent;
        if ((end - _scroll.offset).abs() < 1) return;
        await _scroll.animateTo(
          end,
          duration: Duration(milliseconds: i == 0 ? 400 : 150),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<bool> _confirmLeave() async {
    if (_c.finished || _c.expired || _messages.length <= 1) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave this viva?'),
        content: const Text(
          'Your answers are saved on this device. '
          'You can continue the viva later from the start screen.',
        ),
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
    ).pushReplacement(vdRoute(ReportScreen(sessionId: _c.sessionId!)));
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
          child: _SubmissionView(request: _request),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // In the app shell the viva is a single centred chat column, like a chat
    // app; the work opens in a sheet from the top bar instead of a side panel.
    final shell = context.inShell;
    final wide = !shell && context.width >= _sideBySideWidth;
    final chat = _ChatColumn(
      messages: _messages,
      scroll: _scroll,
      thinking: _c.loading,
      error: _c.loading ? null : _c.error,
      onRetry: _c.canRetry ? _c.retry : null,
      footer: _c.finished
          ? _DoneBar(onReport: _openReport)
          : _Composer(
              controller: _input,
              focus: _focus,
              pasted: _pasted,
              enabled: !_c.loading && !_c.awaitingReply && !_c.expired,
              hint: _c.loading
                  ? 'The duck is thinking…'
                  : _c.expired
                  ? 'Start a new viva from the start screen.'
                  : _c.awaitingReply
                  ? 'Use Try again to resend your answer.'
                  : 'Explain in your own words…',
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
          body: Ambient(
            child: SafeArea(
              child: PageBody(
                maxWidth: shell ? 860 : 1240,
                child: Column(
                  children: [
                    VDTopBar(
                      showBack: true,
                      actions: [
                        if (!wide)
                          IconButton(
                            tooltip: 'View my answer',
                            onPressed: _showSubmission,
                            icon: const Icon(Icons.description_outlined),
                          ),
                        // Phones have no room for both; the theme can be
                        // changed from the other screens.
                        if (!context.isPhone) const ThemeToggle(),
                      ],
                    ),
                    if (!wide) ...[
                      _CompactHeader(
                        mood: _mood,
                        round: _c.round,
                        done: _c.finished,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Expanded(
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: context.width >= 1080 ? 360 : 300,
                                  child: _SidePanel(
                                    mood: _mood,
                                    round: _c.round,
                                    done: _c.finished,
                                    request: _request,
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
      ),
    );
  }
}

// ── Progress ─────────────────────────────────────────────────────────────────

const _stepLabels = ['Understand', 'Apply', 'Analyse'];

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
        for (var i = 0; i < totalRounds; i++) ...[
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
                          ? FontWeight.w700
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
          if (i < totalRounds - 1) const SizedBox(width: 6),
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
                    ? 'Follow-ups complete'
                    : 'Question ${round + 1} of $totalRounds',
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
      DuckMood.happy => 'All done. Nice work.',
      DuckMood.playful => 'A tricky one this time.',
      DuckMood.curious => 'Curious about your reasoning.',
      DuckMood.idle || DuckMood.shy => 'Listening.',
    };
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The duck floats on the backdrop itself rather than in a box, so
          // the side panel has one card (the work) instead of two.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
          const SizedBox(height: 28),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(request.title, style: context.text.titleMedium),
            ),
            if (request.source == 'photo')
              const Pill(
                'From a photo',
                color: VD.teal,
                icon: Icons.photo_camera_outlined,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          request.question.prompt,
          style: TextStyle(color: context.inkSoft, fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            request.answerText,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.fade,
            style: context.text.bodyMedium,
          ),
        ),
      ],
    );
  }
}

// ── Chat ─────────────────────────────────────────────────────────────────────

class _ChatColumn extends StatelessWidget {
  final List<VivaMessage> messages;
  final ScrollController scroll;
  final bool thinking;
  final String? error;
  final VoidCallback? onRetry;
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
    final list = ListView(
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
    );
    if (context.inShell) {
      // Chat-app style: the conversation sits on the page and the composer
      // floats in its own card at the bottom.
      return Column(
        children: [
          Expanded(child: list),
          VDCard(padding: const EdgeInsets.all(12), child: footer),
          const SizedBox(height: 8),
        ],
      );
    }
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
  final VivaMessage msg;
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
            ? (context.isDark ? VD.darkBg : const Color(0xFFF1F3F6))
            : (context.isDark ? const Color(0xFF2E3A57) : VD.ink),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(duck ? 4 : 14),
          bottomRight: Radius.circular(duck ? 14 : 4),
        ),
        border: duck ? Border.all(color: context.line) : null,
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
              fontWeight: FontWeight.w400,
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
              color: context.isDark ? VD.darkBg : const Color(0xFFF1F3F6),
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
  final VoidCallback? onRetry;
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
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
              child: const Text('Try again'),
            ),
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
  final String hint;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.focus,
    required this.pasted,
    required this.enabled,
    required this.hint,
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
                child: Semantics(
                  label: 'Your answer',
                  child: TextField(
                    controller: controller,
                    focusNode: focus,
                    autofocus: !phone,
                    minLines: 1,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: hint,
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
                        backgroundColor: context.isDark ? VD.yellow : VD.ink,
                        foregroundColor: context.isDark ? VD.ink : Colors.white,
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
          const Icon(Icons.check_circle_rounded, color: VD.solid),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Follow-ups complete. Your report is ready.',
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
