// Data models mirroring shared/contracts/*.json. Field names match the wire format.

class CreateSessionRequest {
  final String studentName;
  final String title;
  final String kind; // "code" | "text"
  final String submission;
  final String? language;
  final String? sampleId;

  const CreateSessionRequest({
    required this.studentName,
    required this.title,
    required this.kind,
    required this.submission,
    this.language,
    this.sampleId,
  });

  Map<String, dynamic> toJson() => {
    'student_name': studentName,
    'title': title,
    'kind': kind,
    'submission': submission,
    if (language != null) 'language': language,
    if (sampleId != null) 'sample_id': sampleId,
  };
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

enum KeyPointStatus { solid, partial, missing }

class KeyPoint {
  final String id;
  final String statement;
  final KeyPointStatus status;
  final String? evidenceQuote;

  const KeyPoint({
    required this.id,
    required this.statement,
    required this.status,
    this.evidenceQuote,
  });

  factory KeyPoint.fromJson(Map<String, dynamic> j) => KeyPoint(
    id: j['id'] as String,
    statement: j['statement'] as String,
    status: KeyPointStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => KeyPointStatus.missing,
    ),
    evidenceQuote: j['evidence_quote'] as String?,
  );
}

class Report {
  final String sessionId;
  final String title;
  final int scoreBefore;
  final int scoreAfter;
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
  });

  factory Report.fromJson(Map<String, dynamic> j) => Report(
    sessionId: j['session_id'] as String,
    title: j['title'] as String,
    scoreBefore: (j['score_before'] as num).toInt(),
    scoreAfter: (j['score_after'] as num).toInt(),
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
  final int scoreBefore;
  final int scoreAfter;
  final String bloomReached;
  final bool trapCaught;
  final String weakestKeyPoint;
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
  });

  int get gain => scoreAfter - scoreBefore;

  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
    sessionId: j['session_id'] as String,
    student: j['student'] as String,
    scoreBefore: (j['score_before'] as num).toInt(),
    scoreAfter: (j['score_after'] as num).toInt(),
    bloomReached: j['bloom_reached'] as String,
    trapCaught: j['trap_caught'] as bool,
    weakestKeyPoint: j['weakest_key_point'] as String,
    sample: j['sample'] as bool? ?? false,
    finishedAt: DateTime.parse(j['finished_at'] as String),
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
  final List<WeakConcept> weakConcepts;

  const TeacherSummary({
    required this.assignment,
    required this.sessions,
    required this.weakConcepts,
  });

  factory TeacherSummary.fromJson(Map<String, dynamic> j) => TeacherSummary(
    assignment: j['assignment'] as String,
    sessions: (j['sessions'] as List)
        .map((e) => SessionSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
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
