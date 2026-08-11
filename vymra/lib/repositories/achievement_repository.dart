import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement_record.dart';

/// Repository for storing unlocked achievements.
abstract class AchievementRepository {
  Future<List<AchievementRecord>> getAchievements(String petId);
  Future<void> saveAchievements(String petId, List<AchievementRecord> achievements);
}

/// SharedPreferences-backed achievement repository.
class LocalAchievementRepository implements AchievementRepository {
  static const String _keyPrefix = 'vymra_achievements_';

  @override
  Future<List<AchievementRecord>> getAchievements(String petId) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? raw = preferences.getString('$_keyPrefix$petId');
    if (raw == null || raw.isEmpty) {
      return <AchievementRecord>[];
    }

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((dynamic value) =>
            AchievementRecord.fromJson(value as Map<String, dynamic>))
        .toList()
      ..sort(
        (AchievementRecord first, AchievementRecord second) =>
            second.unlockedAt.compareTo(first.unlockedAt),
      );
  }

  @override
  Future<void> saveAchievements(
    String petId,
    List<AchievementRecord> achievements,
  ) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String raw = jsonEncode(
      achievements.map((AchievementRecord item) => item.toJson()).toList(),
    );
    await preferences.setString('$_keyPrefix$petId', raw);
  }
}
