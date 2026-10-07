import 'models.dart';

/// A hand-checked rubric from shared/rubrics/. The real backend keeps these
/// on the server; demo mode bundles them so grading works offline.
class Rubric {
  final Question question;
  final List<RubricPoint> points;
  final String trapClaim;
  final String trapTruth;
  final Map<String, String> probes;
  final String whatIf;

  const Rubric({
    required this.question,
    required this.points,
    required this.trapClaim,
    required this.trapTruth,
    required this.probes,
    required this.whatIf,
  });

  factory Rubric.fromJson(Map<String, dynamic> j) {
    final points = [
      for (final p in j['points'] as List)
        RubricPoint.fromJson(p as Map<String, dynamic>),
    ];
    final follow = j['follow_ups'] as Map<String, dynamic>;
    return Rubric(
      question: Question(
        id: j['id'] as String,
        title: j['title'] as String,
        subject: j['subject'] as String? ?? '',
        prompt: j['prompt'] as String,
        marks: (j['marks'] as num?)?.toInt() ?? 10,
        points: points.length,
      ),
      points: points,
      trapClaim: (j['trap'] as Map)['false_claim'] as String,
      trapTruth: (j['trap'] as Map)['truth'] as String,
      probes: Map<String, String>.from(follow['probe'] as Map),
      whatIf: follow['what_if'] as String,
    );
  }
}

class RubricPoint {
  final String id;
  final String statement;
  final int weight;
  final String hint;
  final List<String> keywords;

  const RubricPoint({
    required this.id,
    required this.statement,
    required this.weight,
    required this.hint,
    required this.keywords,
  });

  factory RubricPoint.fromJson(Map<String, dynamic> j) => RubricPoint(
    id: j['id'] as String,
    statement: j['statement'] as String,
    weight: (j['weight'] as num).toInt(),
    hint: j['hint'] as String? ?? '',
    keywords: [
      for (final k in (j['mock_keywords'] as List? ?? const []))
        (k as String).toLowerCase(),
    ],
  );
}

/// Keyword-based stand-in for the AI grader, so the demo responds to what
/// the student actually wrote. Quotes are always whole sentences copied from
/// the student's text, the same guarantee the real evidence check enforces.
class MockGrader {
  static final _sentenceBreak = RegExp(r'(?<=[.!?])\s+|\n+');
  static final _disagree = RegExp(
    r"\b(no|not|false|wrong|incorrect|disagree|isn't|doesn't|can't|cannot|won't)\b",
    caseSensitive: false,
  );

  static List<String> sentences(String text) => [
    for (final s in text.split(_sentenceBreak))
      if (s.trim().isNotEmpty) s.trim(),
  ];

  static int wordCount(String text) =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  /// Grades one rubric point against [texts] (answer, then any follow-ups).
  static KeyPoint gradePoint(RubricPoint p, List<String> texts) {
    final found = <String>{};
    String? best;
    var bestHits = 0;
    for (final t in texts) {
      for (final s in sentences(t)) {
        final lower = s.toLowerCase();
        final hits = p.keywords.where(lower.contains).toList();
        found.addAll(hits);
        if (hits.length > bestHits) {
          bestHits = hits.length;
          best = s;
        }
      }
    }
    final status = found.length >= 2
        ? KeyPointStatus.solid
        : found.length == 1
        ? KeyPointStatus.partial
        : KeyPointStatus.missing;
    return KeyPoint(
      id: p.id,
      statement: p.statement,
      weight: p.weight,
      status: status,
      comment: switch (status) {
        KeyPointStatus.solid => 'Covered clearly.',
        KeyPointStatus.partial => 'Partly covered. ${p.hint}',
        KeyPointStatus.missing => 'Not covered. ${p.hint}',
      },
      evidenceQuote: status == KeyPointStatus.missing ? null : best,
    );
  }

  static int score(List<KeyPoint> points) {
    final total = points.fold(0, (a, p) => a + p.weight);
    if (total == 0) return 0;
    final got = points.fold<double>(
      0,
      (a, p) =>
          a +
          p.weight *
              switch (p.status) {
                KeyPointStatus.solid => 1.0,
                KeyPointStatus.partial => 0.5,
                KeyPointStatus.missing => 0.0,
              },
    );
    return (100 * got / total).round();
  }

  /// Grades the written answer twice and decides whether a teacher should
  /// look at it.
  static Grade grade(
    Rubric r,
    String answer, {
    bool pasted = false,
    Transcription? transcription,
  }) {
    final points = [
      for (final p in r.points) gradePoint(p, [answer]),
    ];
    final run1 = score(points);
    // A second independent run. Short, thin answers are where graders
    // disagree most, so the demo's second run drifts further on those.
    final words = wordCount(answer);
    final drift = words < 35
        ? (run1 >= 12 ? -12 : 12)
        : (answer.hashCode.abs() % 5) - 2;
    final run2 = (run1 + drift).clamp(0, 100);
    final reasons = <ReviewReason>[
      if ((run1 - run2).abs() > 10)
        ReviewReason(
          'runs_differ',
          'The two grading runs differ by ${(run1 - run2).abs()} points ($run1 and $run2).',
        ),
      if (pasted) const ReviewReason('pasted', 'The answer was pasted.'),
      if (transcription != null && transcription.unclear)
        ReviewReason(
          'handwriting',
          transcription.unclearWords > 0
              ? 'The handwriting was hard to read (${transcription.unclearWords} unclear word${transcription.unclearWords == 1 ? '' : 's'}).'
              : 'The handwriting was hard to read.',
        ),
    ];
    return Grade(
      score: ((run1 + run2) / 2).round(),
      runs: [run1, run2],
      points: points,
      review: Review(needsReview: reasons.isNotEmpty, reasons: reasons),
    );
  }

  /// The probe targets the weakest point: the heaviest missing one, else the
  /// heaviest partial one.
  static KeyPoint weakest(List<KeyPoint> points) {
    for (final s in [KeyPointStatus.missing, KeyPointStatus.partial]) {
      final c = points.where((p) => p.status == s).toList()
        ..sort((a, b) => b.weight.compareTo(a.weight));
      if (c.isNotEmpty) return c.first;
    }
    return points.reduce((a, b) => b.weight > a.weight ? b : a);
  }

  static String probe(Rubric r, Grade g) =>
      r.probes[weakest(g.points).id] ?? 'Can you explain that in more detail?';

  static String trapQuestion(Rubric r) =>
      'A classmate told me: “${r.trapClaim}” Do you agree?';

  static bool caughtTrap(String reply) => _disagree.hasMatch(reply);

  /// What a student would plausibly write by hand for [questionId], as the
  /// AI would transcribe it, with one word it could not read.
  static Transcription transcribe(String questionId) => Transcription(
    text: _handwritten[questionId] ?? _handwritten['binary_search']!,
    legibility: 'unclear',
    confidence: 0.74,
    unclearWords: 1,
  );

  static const _handwritten = {
    'binary_search':
        'Binary search needs the list to be sorted first. It checks the middle '
        'element and compares it with the [?] we want. If the target is '
        'smaller it throws away the right half, if bigger the left half. It '
        'repeats until it finds it or the list is empty, then it says not '
        'found. This is why it takes log n steps.',
    'factorial_recursive':
        'Recursion is when a function calls itself on a smaller problem. For '
        'factorial the base case is n == 0 which returns 1. Otherwise it '
        'returns n times factorial(n - 1). The calls wait on the [?] until the '
        'base case is reached and then they unwind.',
    'normalisation':
        'Normalisation is used to remove redundant data so we do not get '
        'update anomalies. 1NF means every column has atomic values. 2NF '
        'means there is no partial dependency on part of a composite key. 3NF '
        'removes [?] dependencies between non-key columns.',
  };
}
