import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

enum UserRole { student, teacher }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  /// How to greet the user: their first name, or the whole name when it
  /// starts with a title ("Ms. Rivera", not "Ms.").
  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.first.endsWith('.') && parts.length > 1
        ? parts.take(2).join(' ')
        : parts.first;
  }

  bool get isTeacher => role == UserRole.teacher;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] as String,
    name: j['name'] as String,
    email: j['email'] as String,
    role: j['role'] == 'teacher' ? UserRole.teacher : UserRole.student,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.name,
  };
}

class AuthResult {
  final String token;
  final AppUser user;
  const AuthResult(this.token, this.user);

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
    j['token'] as String,
    AppUser.fromJson(j['user'] as Map<String, dynamic>),
  );
}

abstract class AuthBackend {
  Future<AuthResult> login(String email, String password);
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? inviteCode,
  });
}

/// Holds the signed-in user and persists the session across restarts.
class Auth extends ValueNotifier<AppUser?> {
  Auth._(this._backend) : super(null);

  static final Auth instance = Auth._(
    apiBaseUrl.isEmpty ? MockAuthBackend() : HttpAuthBackend(apiBaseUrl),
  );

  static const _kToken = 'vd.token';
  static const _kUser = 'vd.user';

  final AuthBackend _backend;
  String? _token;

  String? get token => _token;
  AppUser? get user => value;
  bool get signedIn => value != null;

  /// Restore a saved session. Safe to call when storage is unavailable.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kUser);
      _token = prefs.getString(_kToken);
      if (raw != null && _token != null) {
        value = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // No storage (private window etc.) — start signed out.
    }
  }

  Future<AppUser> login(String email, String password) async =>
      _save(await _backend.login(email.trim().toLowerCase(), password));

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? inviteCode,
  }) async => _save(
    await _backend.register(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      password: password,
      role: role,
      inviteCode: inviteCode?.trim(),
    ),
  );

  bool get isDemo => _backend is MockAuthBackend;

  /// One-tap demo accounts (demo mode only; empty against a real backend).
  Future<List<({String email, String password, UserRole role})>>
  demoAccounts() async {
    final b = _backend;
    return b is MockAuthBackend ? b.demoAccounts() : const [];
  }

  Future<void> logout() async {
    _token = null;
    value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kToken);
      await prefs.remove(_kUser);
    } catch (_) {}
  }

  Future<AppUser> _save(AuthResult r) async {
    _token = r.token;
    value = r.user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, r.token);
      await prefs.setString(_kUser, jsonEncode(r.user.toJson()));
    } catch (_) {}
    return r.user;
  }
}

class HttpAuthBackend implements AuthBackend {
  final String base;
  HttpAuthBackend(this.base);

  Future<AuthResult> _post(String path, Map<String, dynamic> body) async {
    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('${base.replaceAll(RegExp(r'/$'), '')}$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const ApiException(
        "Can't reach the pond. Check your connection and try again.",
      );
    }
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode >= 200 && res.statusCode < 300 && json != null) {
      return AuthResult.fromJson(json);
    }
    throw ApiException(
      json?['error'] as String? ?? 'Something went wrong (${res.statusCode}).',
      status: res.statusCode,
    );
  }

  @override
  Future<AuthResult> login(String email, String password) =>
      _post('/auth/login', {'email': email, 'password': password});

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? inviteCode,
  }) => _post('/auth/register', {
    'name': name,
    'email': email,
    'password': password,
    'role': role.name,
    if (inviteCode != null && inviteCode.isNotEmpty) 'invite_code': inviteCode,
  });
}

/// Demo-mode accounts: seeded from assets/fixtures/demo_accounts.json, plus
/// anything registered this run (kept in memory only).
class MockAuthBackend implements AuthBackend {
  final _rand = Random();
  List<_MockAccount>? _accounts;
  List<_MockAccount> _seeded = const [];

  Future<List<_MockAccount>> _load() async {
    if (_accounts != null) return _accounts!;
    final raw = await rootBundle.loadString(
      'assets/fixtures/demo_accounts.json',
    );
    final list = (jsonDecode(raw) as Map<String, dynamic>)['accounts'] as List;
    _seeded = [
      for (final a in list.cast<Map<String, dynamic>>())
        _MockAccount(AppUser.fromJson(a), a['password'] as String),
    ];
    return _accounts = [..._seeded];
  }

  String _token() => 'tok_${_rand.nextInt(0x7fffffff).toRadixString(16)}';

  @override
  Future<AuthResult> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final accounts = await _load();
    final match = accounts.where(
      (a) => a.user.email == email && a.password == password,
    );
    if (match.isEmpty) {
      throw const ApiException(
        "That email and password don't match.",
        status: 401,
      );
    }
    return AuthResult(_token(), match.first.user);
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? inviteCode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final accounts = await _load();
    if (name.isEmpty || !email.contains('@') || password.length < 8) {
      throw const ApiException('request body is invalid', status: 400);
    }
    if (accounts.any((a) => a.user.email == email)) {
      throw const ApiException(
        'An account with this email already exists.',
        status: 409,
      );
    }
    final user = AppUser(
      id: 'u_${_rand.nextInt(0xFFFF).toRadixString(16)}',
      name: name,
      email: email,
      role: role,
    );
    accounts.add(_MockAccount(user, password));
    return AuthResult(_token(), user);
  }

  /// Demo accounts for the one-tap buttons on the login screen.
  Future<List<({String email, String password, UserRole role})>>
  demoAccounts() async {
    await _load();
    return [
      for (final a in _seeded)
        (email: a.user.email, password: a.password, role: a.user.role),
    ];
  }
}

class _MockAccount {
  final AppUser user;
  final String password;
  _MockAccount(this.user, this.password);
}
