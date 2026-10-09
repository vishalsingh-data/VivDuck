import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vivduck/core/api.dart';
import 'package:vivduck/core/mock_grader.dart';
import 'package:vivduck/core/models.dart';

Map<String, dynamic> _contract(String name) =>
    jsonDecode(File('../shared/contracts/$name.json').readAsStringSync())
        as Map<String, dynamic>;

Rubric _rubric(String id) => Rubric.fromJson(
  jsonDecode(File('../shared/rubrics/$id.json').readAsStringSync())
      as Map<String, dynamic>,
);

const _goodAnswer =
    'Binary search only works on a sorted list, because the order lets one '
    'comparison rule out half. It compares the target with the middle '
    'element. If the target is bigger it moves low past the middle and '
    'discards the left half, otherwise it moves high and discards the right '
    'half. It stops when it finds the value, or when the range is empty and '
    'it returns not found. Because the range halves each step it takes '
    'O(log n) time, which is much faster than linear search checking every '
    'element one by one.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('models parse the shared contracts', () {
    test('questions', () {
      final q = Question.fromJson(
        (_contract('00_questions')['response']['questions'] as List).first,
      );
      expect(q.id, 'binary_search');
      expect(q.points, 6);
    });

    test('create session response carries the grade and first question', () {
      final r = CreateSessionResponse.fromJson(
        _contract('01_create_session')['response'],
      );
      expect(r.grade.runs, [74, 78]);
      expect(r.grade.score, 76);
      expect(r.grade.points.first.weight, 3);
      expect(r.questionType, 'probe');
    });

    test('create session request uses wire field names', () {
      final rubric = _rubric('binary_search');
      final req = CreateSessionRequest(
        studentName: 'Alice Nguyen',
        question: rubric.question,
        answerText: 'x',
      ).toJson();
      expect(
        req.keys,
        containsAll((_contract('01_create_session')['request'] as Map).keys),
      );
    });

    test('request survives being saved and restored', () {
      final rubric = _rubric('normalisation');
      final req = CreateSessionRequest(
        studentName: 'Rahul',
        question: rubric.question,
        answerText: 'answer',
        source: 'photo',
        transcription: MockGrader.transcribe('normalisation'),
        transcriptionEdited: true,
      );
      final back = CreateSessionRequest.fromStore(
        jsonDecode(jsonEncode(req.toStore())) as Map<String, dynamic>,
      );
      expect(back.question.prompt, rubric.question.prompt);
      expect(back.transcription!.unclear, isTrue);
      expect(back.transcriptionEdited, isTrue);
    });

    test('turn', () {
      final t = TurnResponse.fromJson(_contract('02_turn')['response']);
      expect(t.questionType, 'what_if');
      expect(t.round, 1);
    });

    test('report', () {
      final r = Report.fromJson(_contract('03_report')['response']);
      expect(r.scoreBefore, 76);
      expect(r.gradingRuns, [74, 78]);
      expect(r.keyPoints, hasLength(6));
      expect(r.keyPoints.last.status, KeyPointStatus.missing);
      expect(r.keyPoints.last.comment, isNotEmpty);
      expect(r.answerText, isNotEmpty);
    });

    test('teacher summary and agreement', () {
      final s = TeacherSummary.fromJson(
        _contract('04_teacher_summary')['response'],
      );
      expect(s.sessions.length, greaterThanOrEqualTo(10));
      expect(s.sessions.where((x) => x.inReviewQueue), isNotEmpty);
      // The contract's agreement block matches its own rows.
      final computed = Agreement.of(s.sessions);
      expect(computed.sampleSize, s.agreement.sampleSize);
      expect(computed.meanAbsDiff, s.agreement.meanAbsDiff);
      expect(computed.within10Pct, s.agreement.within10Pct);
    });

    test('transcription', () {
      final t = Transcription.fromJson(_contract('07_transcribe')['response']);
      expect(t.unclear, isTrue);
      expect(t.text, contains('[?]'));
    });

    test('answer sheets (10)', () {
      final c = _contract('10_answer_sheets');
      final read = [
        for (final a in c['read']['response']['answers'] as List)
          SheetAnswer.fromJson(a as Map<String, dynamic>),
      ];
      expect(read.first.found, isTrue);
      expect(read.first.transcription.unclear, isTrue);
      expect(read.last.found, isFalse);
      final sheet = AnswerSheet.fromJson(c['grade']['response']);
      expect(sheet.items, hasLength(2));
      expect(sheet.items.first.grade.points.first.evidenceQuote, isNotNull);
      expect(formatMarks(sheet.totalMarks), '6');
      expect(formatMarks(6.5), '6.5');
      final row = AnswerSheet.fromJson(
        (c['list']['response']['sheets'] as List).first,
      );
      expect(row.items, isEmpty);
      expect(row.maxMarks, 20);
    });
  });

  group('MockGrader', () {
    final rubric = _rubric('binary_search');

    test(
      'a full answer scores high and every quote is the student\'s own words',
      () {
        final g = MockGrader.grade(rubric, _goodAnswer);
        expect(g.score, greaterThanOrEqualTo(80));
        for (final p in g.points) {
          if (p.evidenceQuote != null) {
            expect(_goodAnswer, contains(p.evidenceQuote!));
          }
        }
        expect(g.review.needsReview, isFalse);
      },
    );

    test('a thin answer scores low and the two runs disagree', () {
      final g = MockGrader.grade(rubric, 'It looks at the middle of the list.');
      expect(g.score, lessThan(40));
      expect((g.runs[0] - g.runs[1]).abs(), greaterThan(10));
      expect(g.review.reasons.map((r) => r.code), contains('runs_differ'));
    });

    test('pasted and unclear handwriting are flagged with reasons', () {
      final g = MockGrader.grade(
        rubric,
        _goodAnswer,
        pasted: true,
        transcription: MockGrader.transcribe('binary_search'),
      );
      expect(g.review.needsReview, isTrue);
      expect(
        g.review.reasons.map((r) => r.code),
        containsAll(['pasted', 'handwriting']),
      );
    });

    test('scoring follows the weights', () {
      const pts = [
        KeyPoint(
          id: 'a',
          statement: '',
          status: KeyPointStatus.solid,
          weight: 3,
        ),
        KeyPoint(
          id: 'b',
          statement: '',
          status: KeyPointStatus.partial,
          weight: 2,
        ),
        KeyPoint(
          id: 'c',
          statement: '',
          status: KeyPointStatus.missing,
          weight: 1,
        ),
      ];
      // (3 + 1) / 6
      expect(MockGrader.score(pts), 67);
    });

    test('the probe targets the heaviest missing point', () {
      final g = MockGrader.grade(rubric, 'The list must be sorted in order.');
      expect(MockGrader.probe(rubric, g), rubric.probes['kp2']);
    });
  });

  group('MockVivaApi', () {
    test('grade, three follow-ups, report, teacher score, agreement', () async {
      final api = MockVivaApi();
      final questions = await api.getQuestions();
      expect(questions.map((q) => q.id), MockVivaApi.questionIds);

      final photo = await api.transcribe(
        'binary_search',
        Uint8List.fromList([1, 2, 3]),
        'image/jpeg',
      );
      expect(photo.unclear, isTrue);

      final created = await api.createSession(
        CreateSessionRequest(
          studentName: 'Test Student',
          question: questions.first,
          answerText: photo.text.replaceAll('[?]', 'target'),
          source: 'photo',
          transcription: photo,
        ),
      );
      final id = created.sessionId;
      expect(created.questionType, 'probe');
      expect(
        created.grade.review.reasons.map((r) => r.code),
        contains('handwriting'),
      );

      await expectLater(api.getReport(id), throwsA(isA<ApiException>()));

      final types = <String?>[];
      TurnResponse res;
      final replies = [
        'If it is not sorted, discarding half could throw away the target.',
        'It finds one of them, but not necessarily the first one in the list.',
        'No, that is wrong. Without order you cannot rule out half the list.',
      ];
      var i = 0;
      do {
        res = await api.submitTurn(id, replies[i++], pasted: false);
        types.add(res.questionType);
      } while (!res.done);
      expect(types, ['what_if', 'trap', null]);
      expect(res.round, 3);

      final report = await api.getReport(id);
      expect(report.trapCaught, isTrue);
      expect(report.bloomReached, 'Analyse');
      expect(report.scoreAfter, greaterThanOrEqualTo(report.scoreBefore));
      expect(report.review.needsReview, isTrue);

      var summary = await api.getTeacherSummary();
      final mine = summary.sessions.firstWhere((s) => s.sessionId == id);
      expect(mine.inReviewQueue, isTrue);
      final before = summary.agreement.sampleSize;

      final agreement = await api.setTeacherScore(id, report.scoreBefore + 4);
      expect(agreement.sampleSize, before + 1);
      summary = await api.getTeacherSummary();
      expect(
        summary.sessions.firstWhere((s) => s.sessionId == id).inReviewQueue,
        isFalse,
      );
    });

    test('bad teacher scores and unknown sessions are rejected', () async {
      final api = MockVivaApi();
      expect(
        () => api.setTeacherScore('nope', 50),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
      expect(
        () => api.setTeacherScore('nope', 101),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
      );
      expect(
        () => api.submitTurn('nope', 'hi', pasted: false),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });

    test('an answer sheet is read, then graded question by question', () async {
      final api = MockVivaApi();
      final pdf = UploadPage(Uint8List(10), 'application/pdf', 'sheet.pdf');
      final read = await api.readSheet(
        ['binary_search', 'normalisation'],
        [pdf],
      );
      expect(read.map((a) => a.questionId), ['binary_search', 'normalisation']);
      expect(read.every((a) => a.found), isTrue);

      final sheet = await api.gradeSheet('Riya', [
        (
          questionId: 'binary_search',
          text: read[0].transcription.text,
          transcription: read[0].transcription,
          edited: false,
        ),
        (
          questionId: 'normalisation',
          text: '',
          transcription: null,
          edited: false,
        ),
      ]);
      expect(sheet.items, hasLength(2));
      expect(sheet.answered, 1);
      expect(sheet.items[0].marks, greaterThan(0));
      expect(sheet.items[1].marks, 0);
      expect(sheet.totalMarks, sheet.items[0].marks);
      expect(sheet.needsReview, isTrue, reason: 'handwriting was unclear');
      expect((await api.getSheets()).single.sheetId, sheet.sheetId);
    });

    test('documents keep to the page limits', () async {
      final api = MockVivaApi();
      final page = UploadPage(Uint8List(10), 'image/jpeg', 'p.jpg');
      expect(
        (await api.transcribeDocument('binary_search', [page, page])).text,
        isNotEmpty,
      );
      expect(
        () => api.transcribeDocument('binary_search', List.filled(11, page)),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => api.transcribeDocument('binary_search', [
          UploadPage(Uint8List(maxPhotoBytes + 1), 'image/jpeg', 'big.jpg'),
        ]),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
