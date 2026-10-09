import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivduck/auth/profile_screen.dart';
import 'package:vivduck/core/auth.dart';
import 'package:vivduck/core/widgets.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the account menu opens the profile and the grading help', (
    tester,
  ) async {
    await tester.runAsync(
      () => Auth.instance.register(
        name: 'Menu Tester',
        email: 'menu@example.com',
        password: 'long-enough',
        role: UserRole.student,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AccountButton())),
      ),
    );

    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('How grading works'), findsOneWidget);

    await tester.tap(find.text('How grading works'));
    await tester.pumpAndSettle();
    expect(find.text('Graded twice'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    // The profile's ambient background animates forever: pump, don't settle.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Your activity'), findsOneWidget);
    expect(find.text('Change password'), findsWidgets);

    // Let the page's entrance timers finish before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
