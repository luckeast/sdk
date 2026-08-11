import '../models/growth_progress.dart';

/// Reward package granted on level up.
class GrowthReward {
  final int coins;
  final int freeAiUses;

  const GrowthReward({
    this.coins = 0,
    this.freeAiUses = 0,
  });

  bool get hasValue => coins > 0 || freeAiUses > 0;

  GrowthReward copyWith({
    int? coins,
    int? freeAiUses,
  }) {
    return GrowthReward(
      coins: coins ?? this.coins,
      freeAiUses: freeAiUses ?? this.freeAiUses,
    );
  }

  GrowthReward operator +(GrowthReward other) {
    return GrowthReward(
      coins: coins + other.coins,
      freeAiUses: freeAiUses + other.freeAiUses,
    );
  }
}

/// Result returned after growth XP changes or penalties.
class GrowthActivityResult {
  final GrowthProgress progress;
  final int xpDelta;
  final int previousLevel;
  final int currentLevel;
  final GrowthReward reward;
  final List<String> unlockedMilestones;

  const GrowthActivityResult({
    required this.progress,
    required this.xpDelta,
    required this.previousLevel,
    required this.currentLevel,
    this.reward = const GrowthReward(),
    this.unlockedMilestones = const <String>[],
  });

  bool get leveledUp => currentLevel > previousLevel;
  bool get gainedExperience => xpDelta > 0;
  bool get lostExperience => xpDelta < 0;
}

/// Service for calculating pet growth gamification logic.
class GrowthService {
  static const int xpPerMeal = 10;
  static const int xpPerExercise = 15;
  static const int xpPerCheckup = 50;
  static const int xpPerStreakDay = 5;
  static const int streakBonusThreshold = 7;
  static const int xpPenaltyPerMissedReminder = 8;

  /// Award XP for recording a meal.
  GrowthActivityResult awardMealXp(GrowthProgress progress) {
    return _applyExperienceChange(progress, xpPerMeal);
  }

  /// Award XP for recording exercise.
  GrowthActivityResult awardExerciseXp(GrowthProgress progress) {
    return _applyExperienceChange(progress, xpPerExercise);
  }

  /// Award XP for completing a health checkup/reminder.
  GrowthActivityResult awardCheckupXp(GrowthProgress progress) {
    return _applyExperienceChange(progress, xpPerCheckup);
  }

  /// Deduct XP for missed reminders.
  GrowthActivityResult applyMissedReminderPenalty(
    GrowthProgress progress, {
    int missedCount = 1,
  }) {
    return _applyExperienceChange(
      progress,
      -(xpPenaltyPerMissedReminder * missedCount),
    );
  }

  /// Check and update daily streak.
  GrowthActivityResult updateStreak(GrowthProgress progress) {
    final now = DateTime.now();
    final lastDate = progress.lastActivityDate;

    if (lastDate == null) {
      return GrowthActivityResult(
        progress: progress.copyWith(
          streakDays: 1,
          lastActivityDate: now,
        ),
        xpDelta: 0,
        previousLevel: progress.currentLevel,
        currentLevel: progress.currentLevel,
      );
    }

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final today = DateTime(now.year, now.month, now.day);

    if (lastDay == today) {
      // Already logged today, no streak change
      return GrowthActivityResult(
        progress: progress,
        xpDelta: 0,
        previousLevel: progress.currentLevel,
        currentLevel: progress.currentLevel,
      );
    } else if (lastDay == yesterday) {
      // Consecutive day
      final newStreak = progress.streakDays + 1;
      final bonusXp = newStreak >= streakBonusThreshold
          ? xpPerStreakDay * 2
          : xpPerStreakDay;
      return _applyExperienceChange(
        progress.copyWith(
          streakDays: newStreak,
          lastActivityDate: now,
        ),
        bonusXp,
      );
    } else {
      // Streak broken
      return _applyExperienceChange(
        progress.copyWith(
          streakDays: 1,
          lastActivityDate: now,
        ),
        xpPerStreakDay,
      );
    }
  }

  /// Get milestone title for a level.
  String getMilestoneTitle(int level) {
    final milestones = {
      5: 'Curious Explorer',
      10: 'Healthy Eater',
      15: 'Active Companion',
      20: 'Wellness Champion',
      25: 'Vet Visit Hero',
      30: 'Nutrition Master',
      35: 'Fitness Fanatic',
      40: 'Health Guru',
      45: 'Golden Guardian',
      50: 'Legendary Companion',
    };
    return milestones[level] ?? 'Level $level';
  }

  /// Get milestone description for a level.
  String getMilestoneDescription(int level) {
    final descriptions = {
      5: 'Your pet has started their wellness journey! Keep recording their meals and activities.',
      10: 'Great progress! Your consistent care is showing in your pet\'s healthy habits.',
      15: 'Your pet is becoming more active and energetic. The routine is paying off!',
      20: 'Amazing dedication! Your pet is now a wellness champion in the making.',
      25: 'Regular vet visits show you truly care about preventive health. Well done!',
      30: 'You\'ve mastered the art of pet nutrition. Your pet thrives on your care!',
      35: 'Your pet is in peak physical condition. The exercise routine is working wonders!',
      40: 'You and your pet are a health guru team. Other pet parents could learn from you!',
      45: 'Your years of dedicated care have created an unbreakable bond of health and trust.',
      50: 'LEGENDARY STATUS! Your pet is living their best life thanks to your extraordinary care.',
    };
    return descriptions[level] ?? 'Keep up the great work! Every healthy choice counts.';
  }

  /// Reward rule that scales with higher levels.
  GrowthReward rewardForLevel(int level) {
    return GrowthReward(
      coins: 20 + ((level - 1) * 10),
      freeAiUses: level % 5 == 0 ? 1 : 0,
    );
  }

  GrowthActivityResult _applyExperienceChange(GrowthProgress progress, int xpDelta) {
    final int previousLevel = progress.currentLevel;
    final int totalProgressBefore = _totalProgressFor(
      progress.currentLevel,
      progress.currentExperience,
    );
    final int totalProgressAfter = (totalProgressBefore + xpDelta).clamp(0, 1 << 30);
    final _ResolvedLevel resolvedLevel = _resolveLevel(totalProgressAfter);
    final List<String> newMilestones = List<String>.from(progress.milestones);
    final List<String> unlockedMilestones = <String>[];
    GrowthReward combinedReward = const GrowthReward();

    if (resolvedLevel.level > previousLevel) {
      for (int level = previousLevel + 1; level <= resolvedLevel.level; level++) {
        combinedReward = combinedReward + rewardForLevel(level);

        if (level % 5 == 0) {
          final String title = getMilestoneTitle(level);
          if (!newMilestones.contains(title)) {
            newMilestones.add(title);
            unlockedMilestones.add(title);
          }
        }
      }
    }

    return GrowthActivityResult(
      progress: progress.copyWith(
        currentLevel: resolvedLevel.level,
        currentExperience: resolvedLevel.currentExperience,
        totalExperienceEarned: progress.totalExperienceEarned + (xpDelta > 0 ? xpDelta : 0),
        milestones: newMilestones,
        updatedAt: DateTime.now(),
      ),
      xpDelta: xpDelta,
      previousLevel: previousLevel,
      currentLevel: resolvedLevel.level,
      reward: combinedReward,
      unlockedMilestones: unlockedMilestones,
    );
  }

  int _totalProgressFor(int level, int currentExperience) {
    int total = currentExperience;
    for (int currentLevel = 1; currentLevel < level; currentLevel++) {
      total += currentLevel * 10;
    }
    return total;
  }

  _ResolvedLevel _resolveLevel(int totalProgress) {
    int remaining = totalProgress;
    int level = 1;

    while (remaining >= level * 10) {
      remaining -= level * 10;
      level++;
    }

    return _ResolvedLevel(level: level, currentExperience: remaining);
  }
}

class _ResolvedLevel {
  final int level;
  final int currentExperience;

  const _ResolvedLevel({
    required this.level,
    required this.currentExperience,
  });
}
