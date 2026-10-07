import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivduck/core/api.dart';
import 'package:vivduck/viva/session_controller.dart';

import 'fake_api.dart';

final _req = testRequest();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('start grades the answer, then three follow-ups finish it', () async {
    final c = SessionController(api: FakeApi());
    await c.start(_req);
    expect(c.sessionId, isNotNull);
    expect(c.grade!.score, 60);
    expect(c.messages.map((m) => m.type), ['opening', 'probe']);

    for (var i = 0; i < 3; i++) {
      await c.sendAnswer('answer $i', pasted: false);
    }
    expect(c.finished, isTrue);
    expect(c.messages.where((m) => m.fromDuck).map((m) => m.type), [
      'opening',
      'probe',
      'what_if',
      'trap',
      'done',
    ]);
  });

  test(
    'an unfinished viva is saved and restored; a finished one is not',
    () async {
      final api = FakeApi();
      final c = SessionController(api: api);
      await c.start(_req);
      await c.sendAnswer('It halves the range each time.', pasted: true);

      final saved = await SessionController.peekSaved();
      expect(saved?.title, 'Binary search');
      expect(saved?.round, 1);

      final r = (await SessionController.restore(api: api))!;
      expect(r.sessionId, c.sessionId);
      expect(r.request!.question.id, 'binary_search');
      expect(r.grade!.score, 60);
      expect(r.messages.map((m) => m.text), c.messages.map((m) => m.text));
      expect(r.messages[2].pasted, isTrue);
      expect(r.error, isNull);

      for (var i = 0; i < 2; i++) {
        await r.sendAnswer('more $i', pasted: false);
      }
      expect(r.finished, isTrue);
      expect(await SessionController.peekSaved(), isNull);
    },
  );

  test('a failed send keeps the answer and can be retried', () async {
    final api = FakeApi()..failNext = 1;
    final c = SessionController(api: api);
    await c.start(_req);
    await c.sendAnswer('My explanation', pasted: false);

    expect(c.error, isNotNull);
    expect(c.loading, isFalse);
    expect(c.awaitingReply, isTrue);
    expect(c.messages.last.text, 'My explanation');

    // A new answer can't jump the queue while one is unanswered.
    await c.sendAnswer('something else', pasted: false);
    expect(c.messages.where((m) => !m.fromDuck).length, 1);

    await c.retry();
    expect(c.error, isNull);
    expect(c.messages.last.type, 'what_if');
    expect(api.sent, ['My explanation', 'My explanation']);
  });

  test(
    'restoring a viva whose last answer was never answered offers a retry',
    () async {
      final api = FakeApi()..failNext = 1;
      final c = SessionController(api: api);
      await c.start(_req);
      await c.sendAnswer('Lost on the way', pasted: false);

      final r = (await SessionController.restore(api: api))!;
      expect(r.awaitingReply, isTrue);
      expect(r.error, isNotNull);
      await r.retry();
      expect(r.messages.last.fromDuck, isTrue);
    },
  );

  test(
    'a session the server forgot ends the viva instead of retrying',
    () async {
      final api = FakeApi();
      final c = SessionController(api: api);
      await c.start(_req);
      api.forgetSessions = true;
      await c.sendAnswer('Hello', pasted: false);

      expect(c.expired, isTrue);
      expect(c.canRetry, isFalse);
      expect(c.error, contains('start a new one'));
      expect(await SessionController.peekSaved(), isNull);

      await c.retry();
      expect(api.sent, ['Hello']);
    },
  );

  test('reset clears everything, including the saved viva', () async {
    final c = SessionController(api: FakeApi());
    await c.start(_req);
    await c.reset();
    expect(c.sessionId, isNull);
    expect(c.messages, isEmpty);
    expect(await SessionController.peekSaved(), isNull);
  });

  test('a failed start reports a readable error', () async {
    final c = SessionController(api: FakeApi()..failCreate = true);
    await expectLater(c.start(_req), throwsA(isA<ApiException>()));
    expect(c.error, 'The duck is having trouble thinking. Please try again.');
    expect(c.loading, isFalse);
  });
}
