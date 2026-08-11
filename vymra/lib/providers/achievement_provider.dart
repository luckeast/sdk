import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/achievement_record.dart';
import '../models/health_record.dart';
import '../repositories/achievement_repository.dart';

class _AchievementTemplate {
  final String code;
  final String title;
  final String description;
  final String iconKey;

  const _AchievementTemplate({
    required this.code,
    required this.title,
    required this.description,
    required this.iconKey,
  });
}

/// Provider for lightweight achievement progression.
class AchievementProvider extends ChangeNotifier {
  final AchievementRepository _repository;
  List<AchievementRecord> _achievements = <AchievementRecord>[];
  bool _isLoading = false;
  String? _error;
  String? _petId;

  AchievementProvider(this._repository);

  static const Map<String, _AchievementTemplate> _templates =
      <String, _AchievementTemplate>{
    'first_record': _AchievementTemplate(
      code: 'first_record',
      title: 'achievement.first_record.title',
      description: 'achievement.first_record.description',
      iconKey: 'paw',
    ),
    'first_weight_gain': _AchievementTemplate(
      code: 'first_weight_gain',
      title: 'achievement.first_weight_gain.title',
      description: 'achievement.first_weight_gain.description',
      iconKey: 'scale',
    ),
    'first_meal_scan': _AchievementTemplate(
      code: 'first_meal_scan',
      title: 'achievement.first_meal_scan.title',
      description: 'achievement.first_meal_scan.description',
      iconKey: 'scan',
    ),
    'first_reminder_done': _AchievementTemplate(
      code: 'first_reminder_done',
      title: 'achievement.first_reminder_done.title',
      description: 'achievement.first_reminder_done.description',
      iconKey: 'shield',
    ),
    'streak_three': _AchievementTemplate(
      code: 'streak_three',
      title: 'achievement.streak_three.title',
      description: 'achievement.streak_three.description',
      iconKey: 'flame',
    ),
    'level_two': _AchievementTemplate(
      code: 'level_two',
      title: 'achievement.level_two.title',
      description: 'achievement.level_two.description',
      iconKey: 'crown',
    ),
  };

  List<AchievementRecord> get achievements => List.unmodifiable(_achievements);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAchievements(String petId) async {
    _petId = petId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _achievements = await _repository.getAchievements(petId);
    } catch (e) {
      _achievements = <AchievementRecord>[];
      _error = AppStrings.tr('Failed to load achievements');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _achievements = <AchievementRecord>[];
    _petId = null;
    _error = null;
    notifyListeners();
  }

  Future<List<AchievementRecord>> evaluateRecordSaved({
    required HealthRecord record,
    required HealthRecord? previousRecord,
    required int totalRecordCount,
  }) async {
    final List<AchievementRecord> unlocked = <AchievementRecord>[];

    if (totalRecordCount == 1) {
      final AchievementRecord? achievement = await _unlock(
        code: 'first_record',
        imagePath: record.photoPath,
        detail: AppStrings.tr(
          '{recordType} logged at {value} {unit}.',
          params: <String, String>{
            'recordType': record.recordType,
            'value': '${record.value}',
            'unit': record.unit,
          },
        ),
      );
      if (achievement != null) {
        unlocked.add(achievement);
      }
    }

    if (record.recordType == 'weight' &&
        previousRecord != null &&
        record.value > previousRecord.value) {
      final AchievementRecord? achievement = await _unlock(
        code: 'first_weight_gain',
        imagePath: record.photoPath,
        detail: AppStrings.tr(
          'Weight increased from {fromValue} {fromUnit} to {toValue} {toUnit}.',
          params: <String, String>{
            'fromValue': previousRecord.value.toStringAsFixed(1),
            'fromUnit': previousRecord.unit,
            'toValue': record.value.toStringAsFixed(1),
            'toUnit': record.unit,
          },
        ),
      );
      if (achievement != null) {
        unlocked.add(achievement);
      }
    }

    return unlocked;
  }

  Future<List<AchievementRecord>> evaluateMealScan({
    required String imagePath,
    required String foodType,
  }) async {
    final AchievementRecord? achievement = await _unlock(
      code: 'first_meal_scan',
      imagePath: imagePath,
      detail: AppStrings.tr(
        'AI scan completed for {foodType}.',
        params: <String, String>{'foodType': foodType},
      ),
    );
    return achievement == null ? <AchievementRecord>[] : <AchievementRecord>[achievement];
  }

  Future<List<AchievementRecord>> evaluateReminderCompleted({
    required String reminderName,
  }) async {
    final AchievementRecord? achievement = await _unlock(
      code: 'first_reminder_done',
      detail: AppStrings.tr(
        'Completed reminder: {reminderName}.',
        params: <String, String>{'reminderName': reminderName},
      ),
    );
    return achievement == null ? <AchievementRecord>[] : <AchievementRecord>[achievement];
  }

  Future<List<AchievementRecord>> evaluateGrowth({
    required int level,
    required int streakDays,
    String imagePath = '',
  }) async {
    final List<AchievementRecord> unlocked = <AchievementRecord>[];

    if (level >= 2) {
      final AchievementRecord? levelAchievement = await _unlock(
        code: 'level_two',
        imagePath: imagePath,
        detail: AppStrings.tr(
          'Reached level {level}.',
          params: <String, String>{'level': '$level'},
        ),
      );
      if (levelAchievement != null) {
        unlocked.add(levelAchievement);
      }
    }

    if (streakDays >= 3) {
      final AchievementRecord? streakAchievement = await _unlock(
        code: 'streak_three',
        imagePath: imagePath,
        detail: AppStrings.tr(
          'Care streak reached {streakDays} days.',
          params: <String, String>{'streakDays': '$streakDays'},
        ),
      );
      if (streakAchievement != null) {
        unlocked.add(streakAchievement);
      }
    }

    return unlocked;
  }

  IconData iconFor(String iconKey) {
    switch (iconKey) {
      case 'paw':
        return Icons.pets_rounded;
      case 'scale':
        return Icons.monitor_weight_rounded;
      case 'scan':
        return Icons.camera_alt_rounded;
      case 'shield':
        return Icons.verified_rounded;
      case 'flame':
        return Icons.local_fire_department_rounded;
      case 'crown':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }

  Future<AchievementRecord?> _unlock({
    required String code,
    String imagePath = '',
    String detail = '',
  }) async {
    final String? petId = _petId;
    if (petId == null || _achievements.any((AchievementRecord item) => item.code == code)) {
      return null;
    }

    final _AchievementTemplate? template = _templates[code];
    if (template == null) {
      return null;
    }

    final AchievementRecord achievement = AchievementRecord(
      achievementId: 'achievement_${code}_${DateTime.now().millisecondsSinceEpoch}',
      petId: petId,
      code: template.code,
      title: AppStrings.tr(template.title),
      description: AppStrings.tr(template.description),
      iconKey: template.iconKey,
      unlockedAt: DateTime.now(),
      imagePath: imagePath,
      detail: detail,
    );

    _achievements.insert(0, achievement);
    await _repository.saveAchievements(petId, _achievements);
    notifyListeners();
    return achievement;
  }
}
