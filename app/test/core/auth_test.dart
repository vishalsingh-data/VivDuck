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
    final me = _contract('11_profile')['update']['response']['user'];
    expect(AppUser.fromJson(me as Map<String, dynamic>).initials, 'RS');
    for (final name in ['05_register', '06_login']) {
      final r = AuthResult.fromJson(_contract(name)['response']);
      expect(r.user.role, UserRole.student);
      expect(r.token, isNotEmpty);
    }
  });

  group('MockAuthBackend', () {
    test(
      'profile: rename and change password; demo accounts are locked',
      () async {
        final b = MockAuthBackend();
        final r = await b.register(
          name: 'Riya',
          email: 'riya@example.com',
          password: 'first-pass',
          role: UserRole.student,
        );
        final renamed = await b.updateName(r.token, r.user, 'Riya Sharma');
        expect(renamed.name, 'Riya Sharma');
        expect(renamed.initials, 'RS');

        expect(
          () => b.changePassword(r.token, r.user, 'wrong', 'second-pass'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
        );
        await b.changePassword(r.token, r.user, 'first-pass', 'second-pass');
        expect(
          (await b.login('riya@example.com', 'second-pass')).user.name,
          'Riya Sharma',
        );

        final demo = (await b.demoAccounts()).first;
        final d = await b.login(demo.email, demo.password);
        expect(d.user.isDemoAccount, isTrue);
        expect(
          () => b.updateName(d.token, d.user, 'Hacked'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
        );
      },
    );

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

  test(
    'Auth persists and restores the session, and logout clears it',
    () async {
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
    },
  );
}
