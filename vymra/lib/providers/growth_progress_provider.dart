import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/growth_progress.dart';
import '../models/user_account.dart';
import '../models/vaccine_reminder.dart';
import '../repositories/growth_progress_repository.dart';
import '../repositories/purchase_record_repository.dart';
import '../repositories/user_account_repository.dart';
import '../services/growth_service.dart';

/// Provider for managing pet growth gamification state.
class GrowthProgressProvider extends ChangeNotifier {
  final GrowthProgressRepository _repository;
  final GrowthService _growthService;
  final PurchaseRecordRepository _purchaseRepository;
  final UserAccountRepository _userRepository;
  GrowthProgress? _progress;
  bool _isLoading = false;
  String? _error;

  GrowthProgressProvider(
    this._repository,
    this._growthService,
    this._purchaseRepository,
    this._userRepository,
  );

  GrowthProgress? get progress => _progress;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get currentLevel => _progress?.currentLevel ?? 1;
  int get currentXp => _progress?.currentExperience ?? 0;
  int get xpForNextLevel => _progress?.experienceForNextLevel ?? 10;
  double get levelProgress => _progress?.levelProgress ?? 0.0;
  int get streakDays => _progress?.streakDays ?? 0;
  List<String> get milestones => _progress?.milestones ?? [];

  Future<void> loadProgress(String petId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _progress = await _repository.getProgress(petId);
      if (_progress == null) {
        _progress = GrowthProgress(
          progressId: 'progress_$petId',
          petId: petId,
          updatedAt: DateTime.now(),
        );
        await _repository.saveProgress(_progress!);
      }
    } catch (e) {
      _progress = null;
      _error = AppStrings.tr('Failed to load growth progress');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _progress = null;
    _error = null;
    notifyListeners();
  }

  Future<GrowthActivityResult?> awardMealXp() async {
    if (_progress == null) return null;
    final GrowthActivityResult rewardResult = _growthService.awardMealXp(_progress!);
    return _applyActivityResult(rewardResult, updateStreak: true);
  }

  Future<GrowthActivityResult?> awardExerciseXp() async {
    if (_progress == null) return null;
    final GrowthActivityResult rewardResult = _growthService.awardExerciseXp(_progress!);
    return _applyActivityResult(rewardResult, updateStreak: true);
  }

  Future<GrowthActivityResult?> awardCheckupXp() async {
    if (_progress == null) return null;
    final GrowthActivityResult rewardResult = _growthService.awardCheckupXp(_progress!);
    return _applyActivityResult(rewardResult, updateStreak: true);
  }

  Future<GrowthActivityResult?> applyOverdueReminderPenalty(
    List<VaccineReminder> reminders,
  ) async {
    if (_progress == null) return null;

    final List<VaccineReminder> overdueReminders = reminders
        .where((VaccineReminder reminder) => reminder.isActive && !reminder.isCompleted && reminder.isOverdue)
        .toList();
    final List<String> newPenaltyKeys = overdueReminders
        .map(_buildPenaltyKey)
        .where((String key) => !_progress!.processedPenaltyKeys.contains(key))
        .toList();

    if (newPenaltyKeys.isEmpty) {
      return null;
    }

    final GrowthActivityResult penaltyResult = _growthService.applyMissedReminderPenalty(
      _progress!,
      missedCount: newPenaltyKeys.length,
    );
    _progress = penaltyResult.progress.copyWith(
      processedPenaltyKeys: <String>[
        ...penaltyResult.progress.processedPenaltyKeys,
        ...newPenaltyKeys,
      ],
    );
    await _repository.saveProgress(_progress!);
    notifyListeners();

    return GrowthActivityResult(
      progress: _progress!,
      xpDelta: penaltyResult.xpDelta,
      previousLevel: penaltyResult.previousLevel,
      currentLevel: penaltyResult.currentLevel,
      reward: penaltyResult.reward,
      unlockedMilestones: penaltyResult.unlockedMilestones,
    );
  }

  String getMilestoneTitle(int level) =>
      _growthService.getMilestoneTitle(level);
  String getMilestoneDescription(int level) =>
      _growthService.getMilestoneDescription(level);

  Future<GrowthActivityResult> _applyActivityResult(
    GrowthActivityResult result, {
    required bool updateStreak,
  }) async {
    GrowthActivityResult finalResult = result;
    _progress = result.progress;

    if (updateStreak) {
      final GrowthActivityResult streakResult = _growthService.updateStreak(_progress!);
      if (streakResult.xpDelta != 0 || streakResult.currentLevel != finalResult.currentLevel) {
        finalResult = GrowthActivityResult(
          progress: streakResult.progress,
          xpDelta: finalResult.xpDelta + streakResult.xpDelta,
          previousLevel: result.previousLevel,
          currentLevel: streakResult.currentLevel,
          reward: finalResult.reward + streakResult.reward,
          unlockedMilestones: <String>[
            ...finalResult.unlockedMilestones,
            ...streakResult.unlockedMilestones,
          ],
        );
      } else {
        finalResult = GrowthActivityResult(
          progress: streakResult.progress,
          xpDelta: finalResult.xpDelta,
          previousLevel: result.previousLevel,
          currentLevel: finalResult.currentLevel,
          reward: finalResult.reward,
          unlockedMilestones: finalResult.unlockedMilestones,
        );
      }
      _progress = streakResult.progress;
    }

    if (finalResult.reward.hasValue) {
      await _grantLevelRewards(finalResult.reward);
    }

    await _repository.saveProgress(_progress!);
    notifyListeners();
    return GrowthActivityResult(
      progress: _progress!,
      xpDelta: finalResult.xpDelta,
      previousLevel: finalResult.previousLevel,
      currentLevel: finalResult.currentLevel,
      reward: finalResult.reward,
      unlockedMilestones: finalResult.unlockedMilestones,
    );
  }

  Future<void> _grantLevelRewards(GrowthReward reward) async {
    if (reward.coins > 0) {
      await _purchaseRepository.addCoins(reward.coins);
    }

    if (reward.freeAiUses > 0) {
      final UserAccount? currentUser = await _userRepository.getCurrentUser();
      if (currentUser != null) {
        await _userRepository.saveUser(
          currentUser.copyWith(
            freeAiUses: currentUser.freeAiUses + reward.freeAiUses,
          ),
        );
      }
    }
  }

  String _buildPenaltyKey(VaccineReminder reminder) {
    final DateTime? nextDate = reminder.nextDate;
    final String cycle = nextDate?.toIso8601String() ?? 'no-date';
    return '${reminder.reminderId}_$cycle';
  }
}
