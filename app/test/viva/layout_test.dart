import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivduck/core/auth.dart';
import 'package:vivduck/core/theme.dart';
import 'package:vivduck/viva/session_controller.dart';
import 'package:vivduck/viva/submit_screen.dart';
import 'package:vivduck/viva/viva_screen.dart';

import 'fake_api.dart';

final _longName = 'Venkata Lakshmi Narasimha Subrahmanyam R'; // 40 characters
final _longCode = [
  for (var i = 1; i <= 300; i++)
    '    total_value_$i = compute_something_long(alpha, beta, gamma, $i)',
].join('\n');

/// Lets the chat scroll to the newest message.
Future<void> _settleChat(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Chat bubbles are selectable, so they aren't plain Text widgets.
Finder _chat(String text) =>
    find.byWidgetPredicate((w) => w is SelectableText && w.data == text);

Future<void> _setSize(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Setup and Viva are only reachable signed in.
  Auth.instance.value = const AppUser(
    id: 'u1',
    name: 'Alice Nguyen',
    email: 'a@example.com',
    role: UserRole.student,
  );
  addTearDown(() => Auth.instance.value = null);
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
}

Future<SessionController> _controller(FakeApi api) async {
  final c = SessionController(api: api);
  await c.attach(
    's_1',
    testRequest(name: _longName, answer: _longCode),
    testGrade,
    'Question 1?',
  );
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [390.0, 1280.0]) {
    testWidgets('setup screen fits at ${width.toInt()} px with long input', (
      tester,
    ) async {
      await _setSize(tester, width);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const SubmitScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // The questions load from the bundled rubrics.
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Choose a question'), findsOneWidget);
      await tester.tap(find.text('Binary search').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField).last, _longCode);
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('3 follow-up questions'), findsOneWidget);
      expect(find.text('Grade my answer'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Your answer')), findsWidgets);
      semantics.dispose();
      await _teardown(tester);
    });

    testWidgets('viva screen fits at ${width.toInt()} px with long input', (
      tester,
    ) async {
      await _setSize(tester, width);
      final semantics = tester.ensureSemantics();
      final api = FakeApi();
      final c = await _controller(api);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: VivaScreen.withController(c),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Side-by-side at laptop width, "View my work" on a phone.
      expect(
        find.byTooltip('View my answer'),
        width < 900 ? findsOneWidget : findsNothing,
      );

      await tester.enterText(find.byType(TextField), 'word ' * 60);
      await tester.pump();
      expect(_chat('Question 1?'), findsOneWidget);
      await tester.tap(find.byTooltip('Send'));
      await _settleChat(tester);
      expect(_chat('Question 2?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(RegExp('Your answer')), findsWidgets);

      if (width < 900) {
        await tester.tap(find.byTooltip('View my answer'));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      }
      semantics.dispose();
      await _teardown(tester);
    });
  }

  testWidgets('Enter sends; Shift+Enter does not', (tester) async {
    await _setSize(tester, 1280);
    final api = FakeApi();
    final c = await _controller(api);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: VivaScreen.withController(c),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField), 'first line');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(api.sent, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settleChat(tester);
    expect(api.sent, hasLength(1));
    await _teardown(tester);
  });

  testWidgets('a failed answer shows Try again, which resends it', (
    tester,
  ) async {
    await _setSize(tester, 390);
    final api = FakeApi()..failNext = 1;
    final c = await _controller(api);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: VivaScreen.withController(c),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField), 'my answer');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await _settleChat(tester);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.getSize(find.text('Try again')).height, lessThan(44));
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Try again')).height,
      greaterThanOrEqualTo(44),
    );

    await tester.tap(find.text('Try again'));
    await _settleChat(tester);
    expect(api.sent, ['my answer', 'my answer']);
    expect(_chat('Question 2?'), findsOneWidget);
    await _teardown(tester);
  });
}
