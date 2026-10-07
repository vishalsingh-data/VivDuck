import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import '../core/models.dart';

/// A single change that adds more than this many characters is a paste.
const pasteThreshold = 40;

/// True when the text grew by more than [pasteThreshold] characters in one
/// change. Typing, even fast, adds one or two characters at a time.
bool looksPasted(int lengthBefore, int lengthAfter) =>
    lengthAfter - lengthBefore > pasteThreshold;

/// Follow-up questions after the graded answer: probe, what-if, trap.
const totalRounds = followUpCount;

class VivaMessage {
  final bool fromDuck;
  final String text;
  final String? type; // opening | probe | what_if | trap | done
  final bool pasted;

  const VivaMessage.duck(this.text, this.type)
    : fromDuck = true,
      pasted = false;
  const VivaMessage.student(this.text, {this.pasted = false})
    : fromDuck = false,
      type = null;

  factory VivaMessage.fromJson(Map<String, dynamic> j) => j['duck'] == true
      ? VivaMessage.duck(j['text'] as String, j['type'] as String?)
      : VivaMessage.student(j['text'] as String, pasted: j['pasted'] == true);

  Map<String, dynamic> toJson() => {
    'duck': fromDuck,
    'text': text,
    if (type != null) 'type': type,
    if (pasted) 'pasted': true,
  };
}

/// What the Setup screen needs to offer "Continue your viva".
class SavedViva {
  final String title;
  final int round;
  const SavedViva(this.title, this.round);
}

/// The app's memory of one viva: the session, the chat, and whether a call
/// is in flight or failed. An unfinished viva is saved on the device so it
/// can be continued after the app is closed.
class SessionController extends ChangeNotifier {
  SessionController({VivaApi? api}) : _api = api ?? VivaApi.instance;

  static const _storeKey = 'viva_in_progress';

  final VivaApi _api;

  String? sessionId;
  CreateSessionRequest? request;

  /// The rubric grade of the written answer.
  Grade? grade;
  final List<VivaMessage> messages = [];
  int round = 0;
  bool loading = false;
  bool finished = false;
  String? error;

  /// The server no longer knows this session, so it can't be continued.
  bool expired = false;

  /// The last student message has no reply yet, so [retry] can resend it.
  bool get awaitingReply => messages.isNotEmpty && !messages.last.fromDuck;

  /// A failed answer can be sent again.
  bool get canRetry => awaitingReply && !loading && !expired;

  /// Grades the answer on the server, then opens the follow-up chat.
  Future<void> start(CreateSessionRequest req) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.createSession(req);
      loading = false;
      await attach(
        res.sessionId,
        req,
        res.grade,
        res.question,
        res.questionType,
      );
    } on ApiException catch (e) {
      loading = false;
      error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Opens the chat for an answer that was already graded.
  Future<void> attach(
    String id,
    CreateSessionRequest req,
    Grade grade,
    String firstQuestion, [
    String firstType = 'probe',
  ]) async {
    sessionId = id;
    request = req;
    this.grade = grade;
    messages
      ..clear()
      ..add(VivaMessage.duck(_opening(req), 'opening'))
      ..add(VivaMessage.duck(firstQuestion, firstType));
    round = 0;
    finished = false;
    error = null;
    notifyListeners();
    await _save();
  }

  static String _opening(CreateSessionRequest req) {
    final first = req.studentName.trim().split(' ').first;
    return "Hi $first. I've marked your answer on ${req.title.toLowerCase()} "
        'against the rubric. Three short questions now, to check you '
        'understand what you wrote. Your score can go up as you answer.';
  }

  Future<void> sendAnswer(String text, {required bool pasted}) async {
    final t = text.trim();
    if (t.isEmpty || loading || finished || expired || awaitingReply) return;
    messages.add(VivaMessage.student(t, pasted: pasted));
    await _send(t, pasted);
  }

  /// Sends the last unanswered message again after a failure.
  Future<void> retry() async {
    if (!canRetry) return;
    final last = messages.last;
    await _send(last.text, last.pasted);
  }

  Future<void> _send(String text, bool pasted) async {
    loading = true;
    error = null;
    notifyListeners();
    await _save();
    try {
      final res = await _api.submitTurn(sessionId!, text, pasted: pasted);
      round = res.round;
      if (res.done) {
        finished = true;
        messages.add(
          const VivaMessage.duck(
            "That's a wrap. Thanks for talking it through with me. "
                "I'm putting your report together now.",
            'done',
          ),
        );
        await _clearSaved();
      } else {
        messages.add(VivaMessage.duck(res.question ?? '…', res.questionType));
        await _save();
      }
    } on ApiException catch (e) {
      if (e.status == 404) {
        expired = true;
        error =
            'This session is no longer on the server. Please start a new one.';
        await _clearSaved();
      } else {
        error = e.message;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Clears everything, including the saved viva.
  Future<void> reset() async {
    sessionId = null;
    request = null;
    grade = null;
    messages.clear();
    round = 0;
    loading = false;
    finished = false;
    expired = false;
    error = null;
    notifyListeners();
    await _clearSaved();
  }

  // ── Saving and resuming ───────────────────────────────────────────────────

  Future<void> _save() async {
    if (sessionId == null || request == null || finished) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storeKey,
        jsonEncode({
          'session_id': sessionId,
          'request': request!.toStore(),
          'grade': grade?.toJson(),
          'round': round,
          'messages': [for (final m in messages) m.toJson()],
        }),
      );
    } catch (_) {
      // Storage unavailable: the viva still works, it just can't resume.
    }
  }

  static Future<void> _clearSaved() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_storeKey);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> _readSaved() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_storeKey);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      await _clearSaved();
      return null;
    }
  }

  /// The unfinished viva saved on this device, if any.
  static Future<SavedViva?> peekSaved() async {
    final j = await _readSaved();
    if (j == null) return null;
    final req = j['request'] as Map<String, dynamic>;
    final q = req['question'] as Map<String, dynamic>?;
    return SavedViva(
      q?['title'] as String? ?? 'Your answer',
      j['round'] as int,
    );
  }

  /// Restores the saved unfinished viva, or returns null if there is none.
  static Future<SessionController?> restore({VivaApi? api}) async {
    final j = await _readSaved();
    if (j == null) return null;
    try {
      final c = SessionController(api: api)
        ..sessionId = j['session_id'] as String
        ..request = CreateSessionRequest.fromStore(
          j['request'] as Map<String, dynamic>,
        )
        ..grade = j['grade'] == null
            ? null
            : Grade.fromJson(j['grade'] as Map<String, dynamic>)
        ..round = j['round'] as int;
      c.messages.addAll([
        for (final m in j['messages'] as List)
          VivaMessage.fromJson(m as Map<String, dynamic>),
      ]);
      if (c.awaitingReply) {
        c.error = "Your last answer wasn't sent. Send it again to continue.";
      }
      return c;
    } catch (_) {
      await _clearSaved();
      return null;
    }
  }

  /// Forgets the saved unfinished viva without opening it.
  static Future<void> discardSaved() => _clearSaved();
}
