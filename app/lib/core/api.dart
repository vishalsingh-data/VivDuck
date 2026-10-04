import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'models.dart';

/// Base URL of the backend. Empty means "mock mode" (fixtures, no network).
/// Run with: flutter run --dart-define=API_BASE_URL=http://localhost:8000
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

class ApiException implements Exception {
  final int? status;
  final String message;
  const ApiException(this.message, {this.status});
  @override
  String toString() => message;
}

abstract class VivaApi {
  Future<String> createSession(CreateSessionRequest req);
  Future<TurnResponse> submitTurn(
    String sessionId,
    String text, {
    required bool pasted,
  });
  Future<Report> getReport(String sessionId);
  Future<TeacherSummary> getTeacherSummary();

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
      res = await call().timeout(const Duration(seconds: 60));
    } catch (_) {
      throw const ApiException(
        "Can't reach the pond. Check your connection and try again.",
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

  @override
  Future<String> createSession(CreateSessionRequest req) async {
    final b = await _send(
      () => _client.post(
        _u('/sessions'),
        headers: _json,
        body: jsonEncode(req.toJson()),
      ),
    );
    return b['session_id'] as String;
  }

  @override
  Future<TurnResponse> submitTurn(
    String sessionId,
    String text, {
    required bool pasted,
  }) async {
    final b = await _send(
      () => _client.post(
        _u('/sessions/$sessionId/turn'),
        headers: _json,
        body: jsonEncode({'text': text, 'pasted': pasted}),
      ),
    );
    return TurnResponse.fromJson(b);
  }

  @override
  Future<Report> getReport(String sessionId) async => Report.fromJson(
    await _send(
      () => _client.get(_u('/sessions/$sessionId/report'), headers: _json),
    ),
  );

  @override
  Future<TeacherSummary> getTeacherSummary() async => TeacherSummary.fromJson(
    await _send(() => _client.get(_u('/teacher/summary'), headers: _json)),
  );
}

/// Offline implementation that mirrors backend/ai stub behaviour using the
/// bundled fixtures, so the whole app is demoable without a server.
class MockVivaApi implements VivaApi {
  @override
  bool get isMock => true;

  final _rand = Random();
  final Map<String, _MockSession> _sessions = {};
  final List<SessionSummary> _finished = [];

  static const _questions = [
    (
      'probe',
      'Can you walk me through what happens in your code when the target value is not present in the array?',
    ),
    (
      'what_if',
      'What would happen to your algorithm if the input array were not sorted?',
    ),
    (
      'trap',
      'Your midpoint is computed as (lo + hi) // 2. Why might writing (lo + hi) / 2 cause a problem in languages like Java or C?',
    ),
  ];

  Future<Map<String, dynamic>> _fixture(String name) async {
    final raw = await rootBundle.loadString('assets/fixtures/$name.json');
    return (jsonDecode(raw) as Map<String, dynamic>)['response']
        as Map<String, dynamic>;
  }

  Future<void> _think([int min = 700, int spread = 900]) =>
      Future.delayed(Duration(milliseconds: min + _rand.nextInt(spread)));

  @override
  Future<String> createSession(CreateSessionRequest req) async {
    if (req.studentName.trim().isEmpty || req.submission.trim().isEmpty) {
      throw const ApiException('request body is invalid', status: 400);
    }
    await _think(500, 400);
    final id = 's_${_rand.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0')}';
    _sessions[id] = _MockSession(req);
    return id;
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
    s.round++;
    if (pasted) s.pasteFlags++;
    if (s.round >= 4) {
      s.done = true;
      _finished.add(
        SessionSummary(
          sessionId: sessionId,
          student: s.req.studentName,
          scoreBefore: 54,
          scoreAfter: 79,
          bloomReached: 'Analyse',
          trapCaught: true,
          weakestKeyPoint: 'Off-by-one and mid-point edge cases',
          sample: false,
          finishedAt: DateTime.now().toUtc(),
        ),
      );
      return TurnResponse(
        question: null,
        questionType: null,
        round: s.round,
        done: true,
      );
    }
    final (type, q) = _questions[s.round - 1];
    return TurnResponse(
      question: q,
      questionType: type,
      round: s.round,
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
    final j = await _fixture('03_report');
    return Report.fromJson({
      ...j,
      'session_id': sessionId,
      'title': s.req.title,
      'paste_flags': s.pasteFlags,
    });
  }

  @override
  Future<TeacherSummary> getTeacherSummary() async {
    await _think(400, 400);
    final base = TeacherSummary.fromJson(await _fixture('04_teacher_summary'));
    final sessions = [...base.sessions, ..._finished];
    // Recount weakest points so sessions finished in this run are included.
    final counts = <String, int>{};
    for (final s in sessions) {
      counts[s.weakestKeyPoint] = (counts[s.weakestKeyPoint] ?? 0) + 1;
    }
    final weak = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return TeacherSummary(
      assignment: base.assignment,
      sessions: sessions,
      weakConcepts: [
        for (final e in weak.take(3))
          WeakConcept(concept: e.key, count: e.value, total: sessions.length),
      ],
    );
  }
}

class _MockSession {
  final CreateSessionRequest req;
  int round = 0;
  int pasteFlags = 0;
  bool done = false;
  _MockSession(this.req);
}
