import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivduck/core/theme.dart';
import 'package:vivduck/viva/session_controller.dart';
import 'package:vivduck/viva/viva_screen.dart';

import 'fake_api.dart';

void main() {
  group('looksPasted', () {
    test('typing one character at a time is not pasted', () {
      var len = 0;
      for (var i = 0; i < 300; i++) {
        expect(looksPasted(len, len + 1), isFalse);
        len++;
      }
    });

    test('adding 60 characters at once is pasted', () {
      expect(looksPasted(0, 60), isTrue);
      expect(looksPasted(100, 160), isTrue);
    });

    test('the limit is more than 40 characters', () {
      expect(looksPasted(0, 40), isFalse);
      expect(looksPasted(0, 41), isTrue);
    });

    test('deleting text is never a paste', () {
      expect(looksPasted(200, 0), isFalse);
    });
  });

  testWidgets('a pasted answer is flagged and sent with pasted true', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = FakeApi();
    final c = SessionController(api: api);
    await c.attach('s_1', testRequest(), testGrade, 'Question 1?');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: VivaScreen.withController(c),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Typed by hand: no flag.
    await tester.enterText(find.byType(TextField), 'I');
    await tester.enterText(find.byType(TextField), 'It');
    await tester.pump();
    expect(find.textContaining('Looks pasted'), findsNothing);

    // Sixty characters arrive in one change.
    await tester.enterText(
      find.byType(TextField),
      'It${' splits the list in half' * 3}',
    );
    await tester.pump();
    expect(find.textContaining('Looks pasted'), findsOneWidget);

    await tester.tap(find.byTooltip('Send'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.pastedFlags, [true]);
    expect(find.text('Pasted'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
