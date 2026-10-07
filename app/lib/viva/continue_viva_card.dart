import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'session_controller.dart';
import 'viva_screen.dart';

/// Offers to continue the unfinished viva saved on this device. Shows
/// nothing when there isn't one.
class ContinueVivaCard extends StatefulWidget {
  const ContinueVivaCard({super.key});

  @override
  State<ContinueVivaCard> createState() => _ContinueVivaCardState();
}

class _ContinueVivaCardState extends State<ContinueVivaCard> {
  SavedViva? _saved;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await SessionController.peekSaved();
    if (mounted) setState(() => _saved = s);
  }

  Future<void> _continue() async {
    setState(() => _opening = true);
    final c = await SessionController.restore();
    if (!mounted) return;
    setState(() => _opening = false);
    if (c == null) {
      setState(() => _saved = null);
      return;
    }
    await Navigator.of(context).push(vdRoute(VivaScreen.withController(c)));
    // The viva may have been finished or left again; show what's saved now.
    _load();
  }

  Future<void> _discard() async {
    await SessionController.discardSaved();
    if (mounted) setState(() => _saved = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = _saved;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: s == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: VDCard(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_rounded, color: VD.orange),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Continue your follow-up questions',
                                style: context.text.titleMedium,
                              ),
                              Text(
                                '${s.title} · '
                                '${s.round} of $totalRounds follow-ups answered',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.inkSoft),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _opening ? null : _discard,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(64, 44),
                          ),
                          child: const Text('Start over'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          onPressed: _opening ? null : _continue,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(64, 44),
                          ),
                          child: const Text('Continue'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
