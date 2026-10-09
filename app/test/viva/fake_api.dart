import 'dart:typed_data';

import 'package:vivduck/core/api.dart';
import 'package:vivduck/core/models.dart';

const testQuestion = Question(
  id: 'binary_search',
  title: 'Binary search',
  subject: 'Algorithms',
  prompt: 'Explain how binary search works.',
  marks: 10,
  points: 2,
);

const testGrade = Grade(
  score: 60,
  runs: [58, 62],
  points: [
    KeyPoint(
      id: 'kp1',
      statement: 'The list must be sorted.',
      status: KeyPointStatus.solid,
      weight: 3,
      comment: 'Covered clearly.',
      evidenceQuote: 'It only works on a sorted list.',
    ),
    KeyPoint(
      id: 'kp2',
      statement: 'It runs in O(log n) time.',
      status: KeyPointStatus.missing,
      weight: 2,
      comment: 'Not covered.',
    ),
  ],
  review: Review.none,
);

CreateSessionRequest testRequest({
  String name = 'Alice Nguyen',
  String answer = 'It only works on a sorted list.',
}) => CreateSessionRequest(
  studentName: name,
  question: testQuestion,
  answerText: answer,
);

/// An instant, scriptable API for viva tests.
class FakeApi implements VivaApi {
  int failNext = 0;
  bool failCreate = false;

  /// Answer every turn with 404, as if the server forgot the session.
  bool forgetSessions = false;
  final List<String> sent = [];
  final List<bool> pastedFlags = [];
  final Map<String, int> _rounds = {};

  static const _error = ApiException(
    'The duck is having trouble thinking. Please try again.',
    status: 502,
  );

  @override
  bool get isMock => true;

  @override
  Future<List<Question>> getQuestions() async => [testQuestion];

  @override
  Future<Transcription> transcribe(
    String questionId,
    Uint8List image,
    String mimeType,
  ) async => const Transcription(
    text: 'Binary search needs a [?] list.',
    legibility: 'unclear',
    confidence: 0.7,
    unclearWords: 1,
  );

  @override
  Future<CreateSessionResponse> createSession(CreateSessionRequest req) async {
    if (failCreate) throw _error;
    final id = 's_${_rounds.length + 1}';
    _rounds[id] = 0;
    return CreateSessionResponse(
      sessionId: id,
      grade: testGrade,
      question: 'Question 1?',
      questionType: 'probe',
    );
  }

  @override
  Future<TurnResponse> submitTurn(
    String sessionId,
    String text, {
    required bool pasted,
  }) async {
    sent.add(text);
    pastedFlags.add(pasted);
    if (forgetSessions) {
      throw const ApiException('session not found', status: 404);
    }
    if (failNext > 0) {
      failNext--;
      throw _error;
    }
    final round = (_rounds[sessionId] ?? 0) + 1;
    _rounds[sessionId] = round;
    if (round >= followUpCount) {
      return TurnResponse(
        question: null,
        questionType: null,
        round: round,
        done: true,
      );
    }
    const types = ['what_if', 'trap'];
    return TurnResponse(
      question: 'Question ${round + 1}?',
      questionType: types[round - 1],
      round: round,
      done: false,
    );
  }

  @override
  Future<Report> getReport(String sessionId) => throw UnimplementedError();

  @override
  Future<QuestionDraft> draftQuestion({
    required String prompt,
    String subject = '',
    int marks = 10,
    String modelAnswer = '',
  }) => throw UnimplementedError();

  @override
  Future<Question> publishQuestion(QuestionDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> deleteQuestion(String id) => throw UnimplementedError();

  @override
  Future<Transcription> transcribeDocument(
    String questionId,
    List<UploadPage> pages,
  ) => throw UnimplementedError();

  @override
  Future<List<SheetAnswer>> readSheet(
    List<String> questionIds,
    List<UploadPage> pages,
  ) => throw UnimplementedError();

  @override
  Future<AnswerSheet> gradeSheet(
    String studentName,
    List<SheetAnswerInput> answers,
  ) => throw UnimplementedError();

  @override
  Future<List<AnswerSheet>> getSheets() => throw UnimplementedError();

  @override
  Future<AnswerSheet> getSheet(String id) => throw UnimplementedError();

  @override
  Future<TeacherSummary> getTeacherSummary() => throw UnimplementedError();

  @override
  Future<Agreement> setTeacherScore(
    String sessionId,
    int score, {
    String? note,
  }) async => Agreement.empty;
}
