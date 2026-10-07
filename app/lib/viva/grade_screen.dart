import 'package:flutter/material.dart';

import '../core/ambient.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../report_teacher/charts.dart';
import '../report_teacher/rubric_points.dart';
import 'session_controller.dart';
import 'viva_screen.dart';

/// The rubric grade of the written answer, with the evidence for every
/// point, before the follow-up questions. Takes ownership of [controller].
class GradeScreen extends StatelessWidget {
  final SessionController controller;
  const GradeScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final req = controller.request!;
    final grade = controller.grade!;
    final phone = context.isPhone;

    final score = VDCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          ScoreRing(
            before: grade.score,
            after: grade.score,
            size: phone ? 120 : 140,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rubric score', style: context.text.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${grade.score} out of 100 for your written answer.',
                  style: TextStyle(color: context.inkSoft),
                ),
                const SizedBox(height: 10),
                GradingRunsNote(runs: grade.runs),
              ],
            ),
          ),
        ],
      ),
    );

    final next = VDCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next: 3 follow-up questions', style: context.text.titleLarge),
          const SizedBox(height: 6),
          Text(
            'The duck asks about your weakest point, a what-if, and one '
            'deliberately false claim to spot. Good answers can raise your score.',
            style: TextStyle(color: context.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(
                context,
              ).pushReplacement(vdRoute(VivaScreen.withController(controller))),
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Start follow-up questions'),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: Ambient(
        child: SafeArea(
          child: SingleChildScrollView(
            child: PageBody(
              maxWidth: 1000,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const VDTopBar(showBack: true, actions: [ThemeToggle()]),
                  FadeSlideIn(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GRADED · ${req.title.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                            color: context.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your answer, marked against the rubric',
                          style: phone
                              ? context.text.headlineSmall
                              : context.text.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (grade.review.needsReview) ...[
                    ReviewBanner(review: grade.review),
                    const SizedBox(height: 16),
                  ],
                  if (phone) ...[
                    score,
                    const SizedBox(height: 16),
                    next,
                  ] else
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: score),
                          const SizedBox(width: 16),
                          Expanded(flex: 4, child: next),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  RubricPointsCard(
                    points: grade.points,
                    subtitle:
                        'Each point shows the words from your answer that earned it.',
                  ),
                  const SizedBox(height: 16),
                  AnswerCard(request: req),
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

/// The question and the student's answer as it was graded.
class AnswerCard extends StatelessWidget {
  final CreateSessionRequest request;
  const AnswerCard({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return VDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Your answer', style: context.text.titleLarge),
              ),
              Pill(
                request.source == 'photo' ? 'From a photo' : 'Typed',
                color: request.source == 'photo' ? VD.teal : VD.inkSoft,
                icon: request.source == 'photo'
                    ? Icons.photo_camera_outlined
                    : Icons.keyboard_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.question.prompt,
            style: TextStyle(color: context.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 12),
          SelectableText(
            request.answerText,
            style: context.text.bodyLarge?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
