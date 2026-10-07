// Data models mirroring shared/contracts/*.json. Field names match the wire format.

/// A question a student can answer (00_questions.json): a teacher's, a
/// sample, or the student's own ([Question.custom]).
class Question {
  final String id;
  final String title;
  final String subject;
  final String prompt;
  final int marks;
  final int points;

  /// teacher | sample | custom
  final String origin;

  /// Who set it, for teacher questions.
  final String? author;

  const Question({
    required this.id,
    required this.title,
    required this.subject,
    required this.prompt,
    required this.marks,
    required this.points,
    this.origin = 'sample',
    this.author,
  });

  static const customId = 'custom';

  /// The student's own question. The server drafts a rubric for it.
  factory Question.custom(String prompt, {String subject = ''}) => Question(
    id: customId,
    title: 'Your own question',
    subject: subject,
    prompt: prompt.trim(),
    marks: 10,
    points: 0,
    origin: 'custom',
  );

  bool get isCustom => id == customId;

  factory Question.fromJson(Map<String, dynamic> j) => Question(
    id: j['id'] as String,
    title: j['title'] as String,
    subject: j['subject'] as String? ?? '',
    prompt: j['prompt'] as String,
    marks: (j['marks'] as num?)?.toInt() ?? 10,
    points: (j['points'] as num?)?.toInt() ?? 0,
    origin: j['origin'] as String? ?? 'sample',
    author: j['author'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'prompt': prompt,
    'marks': marks,
    'points': points,
    'origin': origin,
    if (author != null) 'author': author,
  };
}

/// One rubric point in the teacher's question editor (09_teacher_questions.json).
class DraftPoint {
  final String statement;
  final int weight; // 1-3
  final String hint;
  final String probe;

  const DraftPoint({
    required this.statement,
    required this.weight,
    this.hint = '',
    this.probe = '',
  });

  factory DraftPoint.fromJson(Map<String, dynamic> j) => DraftPoint(
    statement: j['statement'] as String,
    weight: ((j['weight'] as num?)?.toInt() ?? 2).clamp(1, 3),
    hint: j['hint'] as String? ?? '',
    probe: j['probe'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'statement': statement,
    'weight': weight,
    'hint': hint,
    'probe': probe,
  };
}

/// A question with its rubric, as a teacher edits it before publishing.
class QuestionDraft {
  final String title;
  final String subject;
  final String prompt;
  final int marks;
  final List<DraftPoint> points;
  final String trapClaim;
  final String trapTruth;
  final String whatIf;

  const QuestionDraft({
    required this.title,
    required this.subject,
    required this.prompt,
    required this.marks,
    required this.points,
    required this.trapClaim,
    required this.trapTruth,
    required this.whatIf,
  });

  factory QuestionDraft.fromJson(Map<String, dynamic> j) => QuestionDraft(
    title: j['title'] as String? ?? '',
    subject: j['subject'] as String? ?? '',
    prompt: j['prompt'] as String,
    marks: (j['marks'] as num?)?.toInt() ?? 10,
    points: [
      for (final p in j['points'] as List)
        DraftPoint.fromJson(p as Map<String, dynamic>),
    ],
    trapClaim: (j['trap'] as Map)['false_claim'] as String,
    trapTruth: (j['trap'] as Map)['truth'] as String,
    whatIf: j['what_if'] as String,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'subject': subject,
    'prompt': prompt,
    'marks': marks,
    'points': [for (final p in points) p.toJson()],
    'trap': {'false_claim': trapClaim, 'truth': trapTruth},
    'what_if': whatIf,
  };
}

/// How a photographed answer was read (07_transcribe.json).
class Transcription {
  final String text;
  final String legibility; // clear | unclear
  final double confidence;
  final int unclearWords;

  const Transcription({
    required this.text,
    required this.legibility,
    required this.confidence,
    required this.unclearWords,
  });

  bool get unclear => legibility == 'unclear';

  factory Transcription.fromJson(Map<String, dynamic> j) => Transcription(
    text: j['text'] as String,
    legibility: j['legibility'] as String? ?? 'clear',
    confidence: (j['confidence'] as num?)?.toDouble() ?? 1,
    unclearWords: (j['unclear_words'] as num?)?.toInt() ?? 0,
  );
}

class CreateSessionRequest {
  final String studentName;
  final Question question;
  final String answerText;
  final String source; // typed | photo
  final bool pasted;

  /// Set for photographed answers.
  final Transcription? transcription;
  final bool transcriptionEdited;

  const CreateSessionRequest({
    required this.studentName,
    required this.question,
    required this.answerText,
    this.source = 'typed',
    this.pasted = false,
    this.transcription,
    this.transcriptionEdited = false,
  });

  String get title => question.title;

  /// The same answer, with the question the server says it graded.
  CreateSessionRequest withQuestion(Question q) => CreateSessionRequest(
    studentName: studentName,
    question: q,
    answerText: answerText,
    source: source,
    pasted: pasted,
    transcription: transcription,
    transcriptionEdited: transcriptionEdited,
  );

  Map<String, dynamic> toJson() => {
    'student_name': studentName,
    if (question.isCustom)
      'custom_question': {
        'prompt': question.prompt,
        'subject': question.subject,
      }
    else
      'question_id': question.id,
    'answer_text': answerText,
    'source': source,
    'pasted': pasted,
    'transcription': transcription == null
        ? null
        : {
            'legibility': transcription!.legibility,
            'confidence': transcription!.confidence,
            'edited': transcriptionEdited,
          },
  };

  /// Everything needed to rebuild the request on this device.
  Map<String, dynamic> toStore() => {
    ...toJson(),
    'question': question.toJson(),
    if (transcription != null)
      'transcription_full': {
        'text': transcription!.text,
        'legibility': transcription!.legibility,
        'confidence': transcription!.confidence,
        'unclear_words': transcription!.unclearWords,
      },
  };

  factory CreateSessionRequest.fromStore(Map<String, dynamic> j) =>
      CreateSessionRequest(
        studentName: j['student_name'] as String,
        question: Question.fromJson(j['question'] as Map<String, dynamic>),
        answerText: j['answer_text'] as String,
        source: j['source'] as String? ?? 'typed',
        pasted: j['pasted'] as bool? ?? false,
        transcription: j['transcription_full'] == null
            ? null
            : Transcription.fromJson(
                j['transcription_full'] as Map<String, dynamic>,
              ),
        transcriptionEdited:
            (j['transcription'] as Map<String, dynamic>?)?['edited'] == true,
      );
}

enum KeyPointStatus { solid, partial, missing }

/// One rubric point, as graded.
class KeyPoint {
  final String id;
  final String statement;
  final int weight;
  final KeyPointStatus status;
  final String? comment;
  final String? evidenceQuote;

  const KeyPoint({
    required this.id,
    required this.statement,
    required this.status,
    this.weight = 1,
    this.comment,
    this.evidenceQuote,
  });

  factory KeyPoint.fromJson(Map<String, dynamic> j) => KeyPoint(
    id: j['id'] as String,
    statement: j['statement'] as String,
    weight: (j['weight'] as num?)?.toInt() ?? 1,
    status: KeyPointStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => KeyPointStatus.missing,
    ),
    comment: j['comment'] as String?,
    evidenceQuote: j['evidence_quote'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'statement': statement,
    'weight': weight,
    'status': status.name,
    'comment': comment,
    'evidence_quote': evidenceQuote,
  };
}

class ReviewReason {
  final String code; // evidence_check | runs_differ | pasted | handwriting
  final String message;
  const ReviewReason(this.code, this.message);

  factory ReviewReason.fromJson(Map<String, dynamic> j) =>
      ReviewReason(j['code'] as String, j['message'] as String);

  Map<String, dynamic> toJson() => {'code': code, 'message': message};
}

class Review {
  final bool needsReview;
  final List<ReviewReason> reasons;
  const Review({required this.needsReview, required this.reasons});

  static const none = Review(needsReview: false, reasons: []);

  factory Review.fromJson(Map<String, dynamic>? j) => j == null
      ? none
      : Review(
          needsReview: j['needs_review'] as bool? ?? false,
          reasons: [
            for (final r in (j['reasons'] as List? ?? const []))
              ReviewReason.fromJson(r as Map<String, dynamic>),
          ],
        );

  Map<String, dynamic> toJson() => {
    'needs_review': needsReview,
    'reasons': [for (final r in reasons) r.toJson()],
  };
}

/// The rubric grade of the written answer, before any follow-ups.
class Grade {
  final int score;
  final List<int> runs;
  final List<KeyPoint> points;
  final Review review;

  const Grade({
    required this.score,
    required this.runs,
    required this.points,
    required this.review,
  });

  factory Grade.fromJson(Map<String, dynamic> j) => Grade(
    score: (j['score'] as num).toInt(),
    runs: [
      for (final r in (j['runs'] as List? ?? const [])) (r as num).toInt(),
    ],
    points: [
      for (final p in (j['points'] as List))
        KeyPoint.fromJson(p as Map<String, dynamic>),
    ],
    review: Review.fromJson(j['review'] as Map<String, dynamic>?),
  );

  Map<String, dynamic> toJson() => {
    'score': score,
    'runs': runs,
    'points': [for (final p in points) p.toJson()],
    'review': review.toJson(),
  };
}

class CreateSessionResponse {
  final String sessionId;
  final Grade grade;
  final String question;
  final String questionType;

  /// The question that was graded (its drafted title, for a custom question).
  final Question? questionInfo;

  const CreateSessionResponse({
    required this.sessionId,
    required this.grade,
    required this.question,
    required this.questionType,
    this.questionInfo,
  });

  factory CreateSessionResponse.fromJson(Map<String, dynamic> j) =>
      CreateSessionResponse(
        sessionId: j['session_id'] as String,
        grade: Grade.fromJson(j['grade'] as Map<String, dynamic>),
        question: j['question'] as String,
        questionType: j['question_type'] as String? ?? 'probe',
        questionInfo: j['question_info'] == null
            ? null
            : Question.fromJson(j['question_info'] as Map<String, dynamic>),
      );
}

class TurnResponse {
  final String? question;
  final String? questionType; // probe | what_if | trap
  final int round;
  final bool done;

  const TurnResponse({
    required this.question,
    required this.questionType,
    required this.round,
    required this.done,
  });

  factory TurnResponse.fromJson(Map<String, dynamic> j) => TurnResponse(
    question: j['question'] as String?,
    questionType: j['question_type'] as String?,
    round: (j['round'] as num).toInt(),
    done: j['done'] as bool,
  );
}

class Report {
  final String sessionId;
  final String questionId;
  final String title;
  final String questionPrompt;
  final String answerText;
  final String source;
  final int scoreBefore;
  final int scoreAfter;
  final List<int> gradingRuns;
  final Review review;
  final String bloomReached;
  final bool trapCaught;
  final String? trapExplanation;
  final String weakestKeyPoint;
  final List<KeyPoint> keyPoints;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> reviewNext;
  final int pasteFlags;

  const Report({
    required this.sessionId,
    required this.title,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.bloomReached,
    required this.trapCaught,
    required this.trapExplanation,
    required this.weakestKeyPoint,
    required this.keyPoints,
    required this.strengths,
    required this.gaps,
    required this.reviewNext,
    required this.pasteFlags,
    this.questionId = '',
    this.questionPrompt = '',
    this.answerText = '',
    this.source = 'typed',
    this.gradingRuns = const [],
    this.review = Review.none,
  });

  factory Report.fromJson(Map<String, dynamic> j) => Report(
    sessionId: j['session_id'] as String,
    questionId: j['question_id'] as String? ?? '',
    title: j['title'] as String,
    questionPrompt: j['question_prompt'] as String? ?? '',
    answerText: j['answer_text'] as String? ?? '',
    source: j['source'] as String? ?? 'typed',
    scoreBefore: (j['score_before'] as num).toInt(),
    scoreAfter: (j['score_after'] as num).toInt(),
    gradingRuns: [
      for (final r in (j['grading_runs'] as List? ?? const []))
        (r as num).toInt(),
    ],
    review: Review.fromJson(j['review'] as Map<String, dynamic>?),
    bloomReached: j['bloom_reached'] as String,
    trapCaught: j['trap_caught'] as bool,
    trapExplanation: j['trap_explanation'] as String?,
    weakestKeyPoint: j['weakest_key_point'] as String,
    keyPoints: (j['key_points'] as List)
        .map((e) => KeyPoint.fromJson(e as Map<String, dynamic>))
        .toList(),
    strengths: List<String>.from(j['strengths'] as List),
    gaps: List<String>.from(j['gaps'] as List),
    reviewNext: List<String>.from(j['review_next'] as List),
    pasteFlags: (j['paste_flags'] as num?)?.toInt() ?? 0,
  );
}

class SessionSummary {
  final String sessionId;
  final String student;
  final String questionId;
  final String questionTitle;
  final int scoreBefore;
  final int scoreAfter;
  final String bloomReached;
  final bool trapCaught;
  final String weakestKeyPoint;
  final String source;
  final bool needsReview;
  final List<ReviewReason> reviewReasons;
  final int? teacherScore;
  final bool sample;
  final DateTime finishedAt;

  const SessionSummary({
    required this.sessionId,
    required this.student,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.bloomReached,
    required this.trapCaught,
    required this.weakestKeyPoint,
    required this.sample,
    required this.finishedAt,
    this.questionId = '',
    this.questionTitle = '',
    this.source = 'typed',
    this.needsReview = false,
    this.reviewReasons = const [],
    this.teacherScore,
  });

  int get gain => scoreAfter - scoreBefore;

  /// Flagged and not yet looked at by a teacher.
  bool get inReviewQueue => needsReview && teacherScore == null;

  SessionSummary withTeacherScore(int score) => SessionSummary(
    sessionId: sessionId,
    student: student,
    questionId: questionId,
    questionTitle: questionTitle,
    scoreBefore: scoreBefore,
    scoreAfter: scoreAfter,
    bloomReached: bloomReached,
    trapCaught: trapCaught,
    weakestKeyPoint: weakestKeyPoint,
    source: source,
    needsReview: needsReview,
    reviewReasons: reviewReasons,
    teacherScore: score,
    sample: sample,
    finishedAt: finishedAt,
  );

  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
    sessionId: j['session_id'] as String,
    student: j['student'] as String,
    questionId: j['question_id'] as String? ?? '',
    questionTitle: j['question_title'] as String? ?? '',
    scoreBefore: (j['score_before'] as num).toInt(),
    scoreAfter: (j['score_after'] as num).toInt(),
    bloomReached: j['bloom_reached'] as String,
    trapCaught: j['trap_caught'] as bool,
    weakestKeyPoint: j['weakest_key_point'] as String,
    source: j['source'] as String? ?? 'typed',
    needsReview: j['needs_review'] as bool? ?? false,
    reviewReasons: [
      for (final r in (j['review_reasons'] as List? ?? const []))
        ReviewReason.fromJson(r as Map<String, dynamic>),
    ],
    teacherScore: (j['teacher_score'] as num?)?.toInt(),
    sample: j['sample'] as bool? ?? false,
    finishedAt: DateTime.parse(j['finished_at'] as String),
  );
}

/// How closely VivDuck's rubric scores match the teacher's own marks.
class Agreement {
  final int sampleSize;
  final double meanAbsDiff;
  final int within10Pct;

  const Agreement({
    required this.sampleSize,
    required this.meanAbsDiff,
    required this.within10Pct,
  });

  static const empty = Agreement(sampleSize: 0, meanAbsDiff: 0, within10Pct: 0);

  /// Computed from the sessions a teacher has scored.
  factory Agreement.of(Iterable<SessionSummary> sessions) {
    final diffs = [
      for (final s in sessions)
        if (s.teacherScore != null) (s.teacherScore! - s.scoreBefore).abs(),
    ];
    if (diffs.isEmpty) return empty;
    final mean = diffs.reduce((a, b) => a + b) / diffs.length;
    final within = diffs.where((d) => d <= 10).length;
    return Agreement(
      sampleSize: diffs.length,
      meanAbsDiff: (mean * 10).round() / 10,
      within10Pct: (within * 100 / diffs.length).round(),
    );
  }

  factory Agreement.fromJson(Map<String, dynamic>? j) => j == null
      ? empty
      : Agreement(
          sampleSize: (j['sample_size'] as num).toInt(),
          meanAbsDiff: (j['mean_abs_diff'] as num).toDouble(),
          within10Pct: (j['within_10_pct'] as num).toInt(),
        );
}

class WeakConcept {
  final String concept;
  final int count;
  final int total;

  const WeakConcept({
    required this.concept,
    required this.count,
    required this.total,
  });

  factory WeakConcept.fromJson(Map<String, dynamic> j) => WeakConcept(
    concept: j['concept'] as String,
    count: (j['count'] as num).toInt(),
    total: (j['total'] as num).toInt(),
  );
}

class TeacherSummary {
  final String assignment;
  final List<SessionSummary> sessions;
  final Agreement agreement;
  final List<WeakConcept> weakConcepts;

  const TeacherSummary({
    required this.assignment,
    required this.sessions,
    required this.weakConcepts,
    this.agreement = Agreement.empty,
  });

  factory TeacherSummary.fromJson(Map<String, dynamic> j) => TeacherSummary(
    assignment: j['assignment'] as String,
    sessions: (j['sessions'] as List)
        .map((e) => SessionSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
    agreement: Agreement.fromJson(j['agreement'] as Map<String, dynamic>?),
    weakConcepts: (j['weak_concepts'] as List)
        .map((e) => WeakConcept.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Bloom's taxonomy levels in ascending order (British spelling, as the backend uses).
const bloomLevels = [
  'Remember',
  'Understand',
  'Apply',
  'Analyse',
  'Evaluate',
  'Create',
];

int bloomIndex(String level) {
  final i = bloomLevels.indexWhere(
    (b) => b.toLowerCase() == level.toLowerCase(),
  );
  return i < 0 ? 0 : i;
}
