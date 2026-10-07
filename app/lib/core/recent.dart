import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class RecentViva {
  final String id;
  final String title;
  final int scoreBefore;
  final int scoreAfter;
  final DateTime at;

  const RecentViva({
    required this.id,
    required this.title,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.at,
  });

  factory RecentViva.fromJson(Map<String, dynamic> j) => RecentViva(
    id: j['id'] as String,
    title: j['title'] as String,
    scoreBefore: j['before'] as int,
    scoreAfter: j['after'] as int,
    at: DateTime.parse(j['at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'before': scoreBefore,
    'after': scoreAfter,
    'at': at.toIso8601String(),
  };
}

/// Vivas this user has finished on this device, newest first. Kept locally
/// so the sidebar can list them without a history endpoint.
class RecentVivas extends ValueNotifier<List<RecentViva>> {
  RecentVivas._() : super(const []);
  static final instance = RecentVivas._();

  static const _max = 30;
  String? _userId;

  String get _key => 'recent_vivas_${_userId ?? 'anon'}';

  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    value = const [];
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return;
      value = (jsonDecode(raw) as List)
          .map((e) => RecentViva.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Storage unavailable or corrupt: start empty.
    }
  }

  Future<void> add(Report r) async {
    final entry = RecentViva(
      id: r.sessionId,
      title: r.title,
      scoreBefore: r.scoreBefore,
      scoreAfter: r.scoreAfter,
      at: DateTime.now(),
    );
    value = [
      entry,
      ...value.where((v) => v.id != r.sessionId),
    ].take(_max).toList();
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(value.map((v) => v.toJson()).toList()),
      );
    } catch (_) {}
  }
}
