import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivduck/core/api.dart';
import 'package:vivduck/core/auth.dart';

Map<String, dynamic> _contract(String name) =>
    jsonDecode(File('../shared/contracts/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('auth contracts parse', () {
    for (final name in ['05_register', '06_login']) {
      final r = AuthResult.fromJson(_contract(name)['response']);
      expect(r.user.role, UserRole.student);
      expect(r.token, isNotEmpty);
    }
  });

  group('MockAuthBackend', () {
    test('seeded demo accounts can log in; wrong password is 401', () async {
      final b = MockAuthBackend();
      final demo = await b.demoAccounts();
      expect(demo.map((d) => d.role), containsAll(UserRole.values));

      final teacher = demo.firstWhere((d) => d.role == UserRole.teacher);
      final ok = await b.login(teacher.email, teacher.password);
      expect(ok.user.isTeacher, isTrue);

      expect(
        () => b.login(teacher.email, 'wrong-password'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
    });

    test('register then log in; duplicate email is 409', () async {
      final b = MockAuthBackend();
      final r = await b.register(
        name: 'New Student',
        email: 'new@example.com',
        password: 'longenough',
        role: UserRole.student,
      );
      expect(r.user.name, 'New Student');
      expect(
        (await b.login('new@example.com', 'longenough')).user.id,
        r.user.id,
      );
      expect(
        () => b.register(
          name: 'Again',
          email: 'new@example.com',
          password: 'longenough',
          role: UserRole.teacher,
        ),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
      );
    });

    test('short password is rejected', () {
      expect(
        () => MockAuthBackend().register(
          name: 'X',
          email: 'x@example.com',
          password: 'short',
          role: UserRole.student,
        ),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
      );
    });
  });

  test('Auth persists and restores the session, and logout clears it', () async {
    final demo = await Auth.instance.demoAccounts();
    final student = demo.firstWhere((d) => d.role == UserRole.student);
    await Auth.instance.login(student.email.toUpperCase(), student.password);
    expect(Auth.instance.signedIn, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('vd.token'), Auth.instance.token);

    await Auth.instance.logout();
    expect(Auth.instance.user, isNull);
    expect(prefs.getString('vd.token'), isNull);

    await Auth.instance.restore();
    expect(Auth.instance.user, isNull);
  });
}
