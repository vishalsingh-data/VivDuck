import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vivduck/core/api.dart';
import 'package:vivduck/core/models.dart';

Map<String, dynamic> _contract(String name) =>
    jsonDecode(File('../shared/contracts/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('models parse the shared contracts', () {
    test('turn', () {
      final t = TurnResponse.fromJson(_contract('02_turn')['response']);
      expect(t.questionType, 'what_if');
      expect(t.round, 2);
      expect(t.done, isFalse);
    });

    test('report', () {
      final r = Report.fromJson(_contract('03_report')['response']);
      expect(r.scoreAfter, 79);
      expect(r.keyPoints, hasLength(6));
      expect(r.keyPoints[3].status, KeyPointStatus.missing);
      expect(r.keyPoints[3].evidenceQuote, isNull);
      expect(bloomIndex(r.bloomReached), 3);
    });

    test('teacher summary', () {
      final s = TeacherSummary.fromJson(_contract('04_teacher_summary')['response']);
      expect(s.sessions, hasLength(6));
      expect(s.sessions.last.sample, isFalse);
      expect(s.weakConcepts.first.total, 6);
    });

    test('create session request uses wire field names', () {
      final req = CreateSessionRequest(
        studentName: 'Alice Nguyen',
        title: 'Binary search',
        kind: 'code',
        submission: 'x',
        language: 'python',
        sampleId: 'binary_search',
      ).toJson();
      expect(req.keys, containsAll(_contract('01_create_session')['request'].keys));
    });
  });

  group('MockVivaApi', () {
    test('runs a full viva: 3 questions then done, then a report', () async {
      final api = MockVivaApi();
      final id = await api.createSession(const CreateSessionRequest(
        studentName: 'Test Student',
        title: 'Binary search',
        kind: 'code',
        submission: 'def f(): pass',
      ));

      await expectLater(api.getReport(id), throwsA(isA<ApiException>()));

      final types = <String?>[];
      TurnResponse res;
      var i = 0;
      do {
        res = await api.submitTurn(id, 'answer ${i++}', pasted: i == 1);
        types.add(res.questionType);
      } while (!res.done);

      expect(types, ['probe', 'what_if', 'trap', null]);
      expect(res.round, 4);

      final report = await api.getReport(id);
      expect(report.sessionId, id);
      expect(report.pasteFlags, 1);

      final summary = await api.getTeacherSummary();
      expect(summary.sessions.map((s) => s.student), contains('Test Student'));
      expect(summary.weakConcepts.first.total, summary.sessions.length);
    });

    test('unknown session is a 404', () async {
      final api = MockVivaApi();
      expect(
        () => api.submitTurn('nope', 'hi', pasted: false),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });
  });
}
