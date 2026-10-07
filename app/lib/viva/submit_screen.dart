import 'package:flutter/material.dart';

import '../core/ambient.dart';
import '../core/auth.dart';
import '../core/duck.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'answer_form.dart';
import 'continue_viva_card.dart';
import 'grade_screen.dart';
import 'session_controller.dart';

/// Grades [req], then opens the grade screen. Shared by the phone screen
/// and the desktop shell.
Future<void> gradeAndOpen(
  BuildContext context,
  CreateSessionRequest req, {
  bool replace = false,
}) async {
  final session = SessionController();
  try {
    await session.start(req);
  } catch (_) {
    session.dispose();
    rethrow;
  }
  if (!context.mounted) return;
  final route = vdRoute(GradeScreen(controller: session));
  replace
      ? await Navigator.of(context).pushReplacement(route)
      : await Navigator.of(context).push(route);
}

/// The student's start screen: choose a question and answer it.
class SubmitScreen extends StatelessWidget {
  const SubmitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final name = Auth.instance.user?.name;
    return Scaffold(
      body: Ambient(
        child: SafeArea(
          child: SingleChildScrollView(
            child: PageBody(
              maxWidth: 960,
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
                                'Answer a question',
                                style: context.isPhone
                                    ? context.text.headlineMedium
                                    : context.text.headlineLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your answer is graded against a rubric, with your own words shown under every mark.',
                                style: context.text.bodyLarge?.copyWith(
                                  color: context.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!context.isPhone)
                          const Duck(size: 88, mood: DuckMood.curious),
                      ],
                    ),
                  ),
                  SizedBox(height: context.isPhone ? 20 : 28),
                  const ContinueVivaCard(),
                  AnswerForm(
                    studentName: (name == null || name.trim().isEmpty)
                        ? null
                        : name,
                    onSubmit: (req) =>
                        gradeAndOpen(context, req, replace: true),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
