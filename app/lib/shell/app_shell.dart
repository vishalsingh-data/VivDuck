import 'package:flutter/material.dart';

import '../core/ambient.dart';
import '../core/api.dart';
import '../core/auth.dart';
import '../core/duck.dart';
import '../core/models.dart';
import '../core/pond.dart';
import '../core/recent.dart';
import '../core/shell_scope.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../report_teacher/report_screen.dart';
import '../report_teacher/questions_screen.dart';
import '../report_teacher/teacher_screen.dart';
import '../viva/continue_viva_card.dart';
import '../viva/answer_form.dart';
import '../viva/submit_screen.dart' show gradeAndOpen;

/// Signed-in desktop layout, modelled on chat apps: a sidebar with history
/// on the left and a content area with its own navigator on the right, so the
/// sidebar stays put while vivas and reports open beside it.
/// Narrowest window that gets the sidebar layout.
const shellMinWidth = 900.0;

class AppShell extends StatefulWidget {
  final AppUser user;
  const AppShell({super.key, required this.user});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _nav = GlobalKey<NavigatorState>();
  final _selected = ValueNotifier<String?>(null);
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    RecentVivas.instance.load(widget.user.id);
  }

  @override
  void didUpdateWidget(AppShell old) {
    super.didUpdateWidget(old);
    if (old.user.id != widget.user.id) {
      RecentVivas.instance.load(widget.user.id);
    }
  }

  @override
  void dispose() {
    _selected.dispose();
    super.dispose();
  }

  void _newViva() {
    _selected.value = null;
    _nav.currentState?.popUntil((r) => r.isFirst);
  }

  void _open(Widget page, {String? id}) {
    _selected.value = id;
    final nav = _nav.currentState!;
    nav.popUntil((r) => r.isFirst);
    nav.push(vdRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    return ShellScope(
      selected: _selected,
      child: Scaffold(
        body: Row(
          children: [
            _Sidebar(
              user: widget.user,
              collapsed: _collapsed,
              selected: _selected,
              onToggle: () => setState(() => _collapsed = !_collapsed),
              onNewViva: _newViva,
              onOpenReport: (id) => _open(ReportScreen(sessionId: id), id: id),
              onOpenClass: () => _open(const TeacherScreen(), id: '#class'),
              onOpenQuestions: () =>
                  _open(const QuestionsScreen(), id: '#questions'),
            ),
            Expanded(
              child: ClipRect(
                child: Navigator(
                  key: _nav,
                  onGenerateRoute: (_) => vdRoute(ShellHome(user: widget.user)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final AppUser user;
  final bool collapsed;
  final ValueNotifier<String?> selected;
  final VoidCallback onToggle, onNewViva, onOpenClass, onOpenQuestions;
  final ValueChanged<String> onOpenReport;

  const _Sidebar({
    required this.user,
    required this.collapsed,
    required this.selected,
    required this.onToggle,
    required this.onNewViva,
    required this.onOpenReport,
    required this.onOpenClass,
    required this.onOpenQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final bg = dark ? const Color(0xFF0A0F1A) : const Color(0xFFF1F3F6);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: collapsed ? 72 : 268,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: context.line)),
      ),
      child: SafeArea(
        right: false,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: collapsed ? 72 : 268,
            maxWidth: collapsed ? 72 : 268,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (!collapsed) ...[
                        const SizedBox(width: 4),
                        const Logo(size: 32),
                        const Spacer(),
                      ],
                      IconButton(
                        tooltip: collapsed ? 'Open sidebar' : 'Close sidebar',
                        onPressed: onToggle,
                        icon: Icon(
                          collapsed
                              ? Icons.keyboard_double_arrow_right_rounded
                              : Icons.keyboard_double_arrow_left_rounded,
                          color: context.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _NavItem(
                    icon: Icons.add_rounded,
                    label: 'New answer',
                    collapsed: collapsed,
                    emphasis: true,
                    onTap: onNewViva,
                  ),
                  if (user.isTeacher) ...[
                    const SizedBox(height: 4),
                    ValueListenableBuilder(
                      valueListenable: selected,
                      builder: (context, sel, _) => _NavItem(
                        icon: Icons.insights_rounded,
                        label: 'Class dashboard',
                        collapsed: collapsed,
                        selected: sel == '#class',
                        onTap: onOpenClass,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder(
                      valueListenable: selected,
                      builder: (context, sel, _) => _NavItem(
                        icon: Icons.quiz_outlined,
                        label: 'Questions',
                        collapsed: collapsed,
                        selected: sel == '#questions',
                        onTap: onOpenQuestions,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Expanded(
                    child: collapsed
                        ? const SizedBox.shrink()
                        : _RecentList(selected: selected, onOpen: onOpenReport),
                  ),
                  Divider(color: context.line, height: 20),
                  _AccountRow(user: user, collapsed: collapsed),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool collapsed, selected, emphasis;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.onTap,
    this.selected = false,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final fill = selected
        ? context.ink.withValues(alpha: context.isDark ? 0.10 : 0.07)
        : emphasis
        ? context.surface
        : Colors.transparent;
    final item = Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: emphasis ? BorderSide(color: context.line) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              if (!collapsed) const SizedBox(width: 12),
              Icon(
                icon,
                size: 20,
                color: emphasis ? VD.orange : context.inkSoft,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return collapsed ? Tooltip(message: label, child: item) : item;
  }
}

class _RecentList extends StatelessWidget {
  final ValueNotifier<String?> selected;
  final ValueChanged<String> onOpen;
  const _RecentList({required this.selected, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 6),
          child: Text(
            'Recent',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: context.inkSoft,
            ),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: RecentVivas.instance,
            builder: (context, items, _) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Text(
                    'Graded answers will show up here.',
                    style: TextStyle(color: context.inkSoft, fontSize: 13),
                  ),
                );
              }
              return ValueListenableBuilder(
                valueListenable: selected,
                builder: (context, sel, _) => ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  itemBuilder: (context, i) => _RecentTile(
                    viva: items[i],
                    selected: sel == items[i].id,
                    onTap: () => onOpen(items[i].id),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  final RecentViva viva;
  final bool selected;
  final VoidCallback onTap;
  const _RecentTile({
    required this.viva,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gain = viva.scoreAfter - viva.scoreBefore;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? context.ink.withValues(alpha: context.isDark ? 0.10 : 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    viva.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.ink, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${viva.scoreAfter}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: gain >= 0 ? VD.solid : VD.missing,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final AppUser user;
  final bool collapsed;
  const _AccountRow({required this.user, required this.collapsed});

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [ThemeToggle(), SizedBox(height: 6), AccountButton()],
      );
    }
    return Row(
      children: [
        const AccountButton(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.ink,
                ),
              ),
              Text(
                user.isTeacher ? 'Teacher' : 'Student',
                style: TextStyle(fontSize: 12, color: context.inkSoft),
              ),
            ],
          ),
        ),
        const ThemeToggle(),
      ],
    );
  }
}

// ── Home: greeting + composer ────────────────────────────────────────────────

/// The shell's start page: a greeting, then pick a question and answer it.
class ShellHome extends StatefulWidget {
  final AppUser user;
  const ShellHome({super.key, required this.user});

  @override
  State<ShellHome> createState() => _ShellHomeState();
}

class _ShellHomeState extends State<ShellHome> {
  final _pond = PondController();
  int _formKey = 0;

  @override
  void dispose() {
    _pond.dispose();
    super.dispose();
  }

  Future<void> _submit(CreateSessionRequest req) async {
    await gradeAndOpen(context, req);
    // Back from the grade or the follow-ups: start a fresh form, and let the
    // resume card pick up a viva left half-way.
    if (mounted) setState(() => _formKey++);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    final part = h < 12
        ? 'Good morning'
        : h < 18
        ? 'Good afternoon'
        : 'Good evening';
    return '$part, ${widget.user.firstName}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Ambient(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: IgnorePointer(
                // A quiet nod to the brand, not a feature of the page.
                child: Opacity(
                  opacity: 0.35,
                  child: PondBackground(
                    waterHeight: 56,
                    showSky: false,
                    controller: _pond,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Row(
                      children: [
                        const Spacer(),
                        if (VivaApi.instance.isMock)
                          const Tooltip(
                            message:
                                'Demo mode: running on bundled sample data.',
                            child: Icon(
                              Icons.science_outlined,
                              size: 20,
                              color: VD.teal,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 8, 32, 120),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FadeSlideIn(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _greeting,
                                            style: context.text.headlineLarge,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Answer a question. It is graded against a rubric, with your own words shown under every mark.',
                                            style: context.text.bodyLarge
                                                ?.copyWith(
                                                  color: context.inkSoft,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Duck(
                                      size: 80,
                                      mood: DuckMood.curious,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                              ContinueVivaCard(key: ValueKey(_formKey)),
                              FadeSlideIn(
                                delay: const Duration(milliseconds: 100),
                                child: AnswerForm(
                                  key: ValueKey('form$_formKey'),
                                  studentName: widget.user.name,
                                  onSubmit: _submit,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
