import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivduck/core/auth.dart';
import 'package:vivduck/core/theme.dart';
import 'package:vivduck/shell/app_shell.dart';

void main() {
  testWidgets(
    'shell: sidebar toggles and picking a question shows its prompt',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const user = AppUser(
        id: 'u1',
        name: 'Alice Nguyen',
        email: 'a@example.com',
        role: UserRole.student,
      );
      Auth.instance.value = user;
      addTearDown(() => Auth.instance.value = null);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const AppShell(user: user),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('New answer'), findsOneWidget);
      expect(find.textContaining('Alice'), findsWidgets);

      // Questions load from the bundled rubrics; picking one shows its prompt.
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Binary search').first);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.textContaining('Explain how binary search finds a value'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Close sidebar'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Open sidebar'), findsOneWidget);

      // Let the duck's blink timer fire before the tree is torn down.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    },
  );
}
