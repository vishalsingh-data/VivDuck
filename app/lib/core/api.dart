import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        ValueNotifier,
        defaultTargetPlatform,
        kIsWeb,
        kReleaseMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'mock_grader.dart';
import 'models.dart';

/// Base URL of the backend. The app always talks to a real server unless it
/// is built with --dart-define=API_BASE_URL=mock (offline fixtures, for tests).
///   (not set)    web release: the server that served the page;
///                debug: the local server (Android emulator: 10.0.2.2)
///   same-origin  the server that served the page
///   any URL      that server, e.g. https://vivduck.onrender.com
const _apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');
final String apiBaseUrl = switch (_apiBaseUrlDefine) {
  'mock' => '',
  'same-origin' => Uri.base.origin,
  '' => _defaultServer(),
  final url => url,
};

String _defaultServer() {
  if (kIsWeb) return kReleaseMode ? Uri.base.origin : 'http://localhost:8000';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://localhost:8000';
}

/// Bumped whenever a teacher publishes or removes a question, so open
/// question lists reload.
final questionsChanged = ValueNotifier<int>(0);

/// Follow-up questions after the written answer: probe, what-if, trap.
const followUpCount = 3;

class ApiException implements Exception {
  final int? status;
  final String message;
  const ApiException(this.message, {this.status});
  @override
  String toString() => message;
}

abstract class VivaApi {
  Future<List<Question>> getQuestions();
  Future<Transcription> transcribe(
    String questionId,
    Uint8List image,
    String mimeType,
  );
  Future<CreateSessionResponse> createSession(CreateSessionRequest req);
  Future<TurnResponse> submitTurn(
    String sessionId,
    String text, {
    required bool pasted,
  });
  Future<Report> getReport(String sessionId);
  Future<TeacherSummary> getTeacherSummary();
  Future<Agreement> setTeacherScore(
    String sessionId,
    int score, {
    String? note,
  });

  /// Teacher only: drafts a rubric for any question with AI.
  Future<QuestionDraft> draftQuestion({
    required String prompt,
    String subject = '',
    int marks = 10,
    String modelAnswer = '',
  });

  /// Teacher only: publishes an edited draft so students can pick it.
  Future<Question> publishQuestion(QuestionDraft draft);

  /// Teacher only: hides a published question from students.
  Future<void> deleteQuestion(String id);

  bool get isMock;

  static final VivaApi instance = apiBaseUrl.isEmpty
      ? MockVivaApi()
      : HttpVivaApi(apiBaseUrl);
}

class HttpVivaApi implements VivaApi {
  final String base;
  final http.Client _client = http.Client();
  HttpVivaApi(this.base);

  @override
  bool get isMock => false;

  Uri _u(String path) =>
      Uri.parse('${base.replaceAll(RegExp(r'/$'), '')}$path');

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() call,
  ) async {
    http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 90));
    } catch (_) {
      throw const ApiException(
        "Can't reach the server. Check your connection and try again.",
      );
    }
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode >= 200 && res.statusCode < 300 && body != null) {
      return body;
    }
    throw ApiException(
      body?['error'] as String? ?? 'Something went wrong (${res.statusCode}).',
      status: res.statusCode,
    );
  }

  Map<String, String> get _json => {
    'Content-Type': 'application/json',
    if (Auth.instance.token != null)
      'Authorization': 'Bearer ${Auth.instance.token}',
  };

  Future<Map<String, dynamic>> _post(String path, Object body) => _send(
    () => _client.post(_u(path), headers: _json, body: jsonEncode(body)),
  );

  Future<Map<String, dynamic>> _get(String path) =>
      _send(() => _client.get(_u(path), headers: _json));

  @override
  Future<QuestionDraft> draftQuestion({
    required String prompt,
    String subject = '',
    int marks = 10,
    String modelAnswer = '',
  }) async => QuestionDraft.fromJson(
    (await _post('/questions/draft', {
          'prompt': prompt,
          if (subject.isNotEmpty) 'subject': subject,
          'marks': marks,
          if (modelAnswer.isNotEmpty) 'model_answer': modelAnswer,
        }))['draft']
        as Map<String, dynamic>,
  );

  @override
  Future<Question> publishQuestion(QuestionDraft draft) async {
    final q = Question.fromJson(
      (await _post('/questions', draft.toJson()))['question']
          as Map<String, dynamic>,
    );
    questionsChanged.value++;
    return q;
  }

  @override
  Future<void> deleteQuestion(String id) async {
    await _send(() => _client.delete(_u('/questions/$id'), headers: _json));
    questionsChanged.value++;
  }

  @override
  Future<List<Question>> getQuestions() async => [
    for (final q in (await _get('/questions'))['questions'] as List)
      Question.fromJson(q as Map<String, dynamic>),
  ];

  @override
  Future<Transcription> transcribe(
    String questionId,
    Uint8List image,
    String mimeType,
  ) async => Transcription.fromJson(
    await _post('/transcribe', {
      'question_id': questionId,
      'image_base64': base64Encode(image),
      'mime_type': mimeType,
    }),
  );

  @override
  Future<CreateSessionResponse> createSession(CreateSessionRequest req) async =>
      CreateSessionResponse.fromJson(await _post('/sessions', req.toJson()));

  @override
  Future<TurnResponse> submitTurn(
    String sessionId,
    String text, {
    required bool pasted,
  }) async => TurnResponse.fromJson(
    await _post('/sessions/$sessionId/turn', {'text': text, 'pasted': pasted}),
  );

  @override
  Future<Report> getReport(String sessionId) async =>
      Report.fromJson(await _get('/sessions/$sessionId/report'));

  @override
  Future<TeacherSummary> getTeacherSummary() async =>
      TeacherSummary.fromJson(await _get('/teacher/summary'));

  @override
  Future<Agreement> setTeacherScore(
    String sessionId,
    int score, {
    String? note,
  }) async {
    final b = await _post('/sessions/$sessionId/teacher_score', {
      'score': score,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return Agreement.fromJson(b['agreement'] as Map<String, dynamic>?);
  }
}

/// Offline implementation that follows the contracts in shared/contracts/,
/// grading against the bundled rubrics, so the whole app is demoable
/// without a server.
class MockVivaApi implements VivaApi {
  @override
  bool get isMock => true;

  static const questionIds = [
    'binary_search',
    'factorial_recursive',
    'normalisation',
  ];

  final _rand = Random();
  final Map<String, _MockSession> _sessions = {};
  final Map<String, int> _teacherScores = {};
  Map<String, Rubric>? _rubrics;
  List<SessionSummary>? _sampleRows;

  Future<Map<String, Rubric>> _loadRubrics() async => _rubrics ??= {
    for (final id in questionIds)
      id: Rubric.fromJson(
        jsonDecode(await rootBundle.loadString('assets/rubrics/$id.json'))
            as Map<String, dynamic>,
      ),
  };

  Future<Map<String, dynamic>> _fixture(String name) async {
    final raw = await rootBundle.loadString('assets/fixtures/$name.json');
    return (jsonDecode(raw) as Map<String, dynamic>)['response']
        as Map<String, dynamic>;
  }

  Future<void> _think([int min = 700, int spread = 900]) =>
      Future.delayed(Duration(milliseconds: min + _rand.nextInt(spread)));

  @override
  Future<List<Question>> getQuestions() async {
    final r = await _loadRubrics();
    return [for (final id in questionIds) r[id]!.question];
  }

  static const _needsServer = ApiException(
    'Writing your own questions needs the VivDuck server.',
    status: 503,
  );

  @override
  Future<QuestionDraft> draftQuestion({
    required String prompt,
    String subject = '',
    int marks = 10,
    String modelAnswer = '',
  }) async => throw _needsServer;

  @override
  Future<Question> publishQuestion(QuestionDraft draft) async =>
      throw _needsServer;

  @override
  Future<void> deleteQuestion(String id) async => throw _needsServer;

  @override
  Future<Transcription> transcribe(
    String questionId,
    Uint8List image,
    String mimeType,
  ) async {
    if (image.isEmpty) {
      throw const ApiException(
        'Please upload a JPEG or PNG photo under 5 MB.',
        status: 400,
      );
    }
    if (image.length > 5 * 1024 * 1024) {
      throw const ApiException(
        'Please upload a JPEG or PNG photo under 5 MB.',
        status: 400,
      );
    }
    await _think(1400, 800);
    return MockGrader.transcribe(questionId);
  }

  @override
  Future<CreateSessionResponse> createSession(CreateSessionRequest req) async {
    if (req.question.isCustom) throw _needsServer;
    final rubrics = await _loadRubrics();
    final rubric = rubrics[req.question.id];
    if (req.studentName.trim().isEmpty ||
        req.answerText.trim().isEmpty ||
        rubric == null) {
      throw const ApiException('request body is invalid', status: 400);
    }
    await _think(1200, 900);
    final grade = MockGrader.grade(
      rubric,
      req.answerText,
      pasted: req.pasted,
      transcription: req.transcription,
    );
    final id = 's_${_rand.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0')}';
    _sessions[id] = _MockSession(req, rubric, grade)
      ..pasteFlags = req.pasted ? 1 : 0;
    return CreateSessionResponse(
      sessionId: id,
      grade: grade,
      question: MockGrader.probe(rubric, grade),
      questionType: 'probe',
    );
  }

  @override
  Future<TurnResponse> submitTurn(
    String sessionId,
    String text, {
    required bool pasted,
  }) async {
    final s = _sessions[sessionId];
    if (s == null) throw const ApiException('session not found', status: 404);
    if (text.trim().isEmpty) {
      throw const ApiException('request body is invalid', status: 400);
    }
    await _think();
    s.replies.add(text);
    if (pasted) s.pasteFlags++;
    final round = s.replies.length;
    if (round >= followUpCount) {
      s.done = true;
      s.finishedAt = DateTime.now().toUtc();
      return TurnResponse(
        question: null,
        questionType: null,
        round: round,
        done: true,
      );
    }
    return round == 1
        ? TurnResponse(
            question: s.rubric.whatIf,
            questionType: 'what_if',
            round: round,
            done: false,
          )
        : TurnResponse(
            question: MockGrader.trapQuestion(s.rubric),
            questionType: 'trap',
            round: round,
            done: false,
          );
  }

  @override
  Future<Report> getReport(String sessionId) async {
    final s = _sessions[sessionId];
    if (s == null) throw const ApiException('session not found', status: 404);
    if (!s.done) {
      throw const ApiException('viva is still in progress', status: 409);
    }
    await _think(900, 600);
    return s.report(sessionId);
  }

  Future<List<SessionSummary>> _samples() async => _sampleRows ??=
      TeacherSummary.fromJson(await _fixture('04_teacher_summary')).sessions;

  @override
  Future<TeacherSummary> getTeacherSummary() async {
    await _think(400, 400);
    final rows = [
      for (final e in _sessions.entries)
        if (e.value.done) e.value.summary(e.key),
      ...await _samples(),
    ];
    final sessions = [
      for (final r in rows)
        _teacherScores.containsKey(r.sessionId)
            ? r.withTeacherScore(_teacherScores[r.sessionId]!)
            : r,
    ]..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    final counts = <String, int>{};
    for (final s in sessions) {
      counts[s.weakestKeyPoint] = (counts[s.weakestKeyPoint] ?? 0) + 1;
    }
    final weak = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return TeacherSummary(
      assignment: 'All questions',
      sessions: sessions,
      agreement: Agreement.of(sessions),
      weakConcepts: [
        for (final e in weak.take(4))
          WeakConcept(concept: e.key, count: e.value, total: sessions.length),
      ],
    );
  }

  @override
  Future<Agreement> setTeacherScore(
    String sessionId,
    int score, {
    String? note,
  }) async {
    if (score < 0 || score > 100) {
      throw const ApiException(
        'Score must be a whole number from 0 to 100.',
        status: 400,
      );
    }
    final known =
        _sessions.containsKey(sessionId) ||
        (await _samples()).any((s) => s.sessionId == sessionId);
    if (!known) throw const ApiException('session not found', status: 404);
    await _think(300, 300);
    _teacherScores[sessionId] = score;
    return (await getTeacherSummary()).agreement;
  }
}

class _MockSession {
  final CreateSessionRequest req;
  final Rubric rubric;
  final Grade grade;
  final List<String> replies = [];
  int pasteFlags = 0;
  bool done = false;
  DateTime finishedAt = DateTime.now().toUtc();

  _MockSession(this.req, this.rubric, this.grade);

  /// Re-grades with the answer plus the follow-up replies. A point can only
  /// go up: the follow-ups add evidence, they never take marks away.
  List<KeyPoint> get finalPoints => [
    for (var i = 0; i < rubric.points.length; i++)
      () {
        final before = grade.points[i];
        final after = MockGrader.gradePoint(rubric.points[i], [
          req.answerText,
          ...replies,
        ]);
        return after.status.index < before.status.index ? after : before;
      }(),
  ];

  bool get trapCaught =>
      replies.length >= 3 && MockGrader.caughtTrap(replies[2]);

  String get bloom {
    var level = 'Remember';
    if (replies.isNotEmpty && MockGrader.wordCount(replies[0]) >= 8) {
      level = 'Understand';
    }
    if (replies.length > 1 && MockGrader.wordCount(replies[1]) >= 8) {
      level = 'Apply';
    }
    if (trapCaught) level = 'Analyse';
    return level;
  }

  int get scoreAfter {
    final s = MockGrader.score(finalPoints);
    return s < grade.score ? grade.score : s;
  }

  String get weakestPoint {
    final pts = finalPoints;
    return pts.every((p) => p.status == KeyPointStatus.solid)
        ? 'None'
        : MockGrader.weakest(pts).statement;
  }

  SessionSummary summary(String id) => SessionSummary(
    sessionId: id,
    student: req.studentName,
    questionId: rubric.question.id,
    questionTitle: rubric.question.title,
    scoreBefore: grade.score,
    scoreAfter: scoreAfter,
    bloomReached: bloom,
    trapCaught: trapCaught,
    weakestKeyPoint: weakestPoint,
    source: req.source,
    needsReview: grade.review.needsReview,
    reviewReasons: grade.review.reasons,
    sample: false,
    finishedAt: finishedAt,
  );

  Report report(String id) {
    final pts = finalPoints;
    final solid = pts.where((p) => p.status == KeyPointStatus.solid).toList();
    final weak = pts.where((p) => p.status != KeyPointStatus.solid).toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));
    final hints = {for (final p in rubric.points) p.id: p.hint};
    return Report(
      sessionId: id,
      questionId: rubric.question.id,
      title: rubric.question.title,
      questionPrompt: rubric.question.prompt,
      answerText: req.answerText,
      source: req.source,
      scoreBefore: grade.score,
      scoreAfter: scoreAfter,
      gradingRuns: grade.runs,
      review: grade.review,
      bloomReached: bloom,
      trapCaught: trapCaught,
      trapExplanation: trapCaught
          ? 'You rejected the false claim. ${rubric.trapTruth}'
          : 'You went along with a false claim: “${rubric.trapClaim}” ${rubric.trapTruth}',
      weakestKeyPoint: weakestPoint,
      keyPoints: pts,
      strengths: [for (final p in solid.take(3)) p.statement],
      gaps: [for (final p in weak.take(3)) p.statement],
      reviewNext: [for (final p in weak.take(3)) hints[p.id]!],
      pasteFlags: pasteFlags,
    );
  }
}
