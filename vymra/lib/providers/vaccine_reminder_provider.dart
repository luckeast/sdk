import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/vaccine_reminder.dart';
import '../repositories/vaccine_reminder_repository.dart';

/// Provider for managing vaccine and health reminders.
class VaccineReminderProvider extends ChangeNotifier {
  final VaccineReminderRepository _repository;
  List<VaccineReminder> _reminders = [];
  bool _isLoading = false;
  String? _error;

  VaccineReminderProvider(this._repository);

  List<VaccineReminder> get reminders => List.unmodifiable(_reminders);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<VaccineReminder> get activeReminders =>
      _reminders.where((r) => r.isActive && !r.isCompleted).toList();

  List<VaccineReminder> get overdueReminders =>
      _reminders.where((r) => r.isOverdue && !r.isCompleted).toList();

  Future<void> loadReminders(String petId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _reminders = await _repository.getRemindersByPet(petId);
    } catch (e) {
      _reminders = [];
      _error = AppStrings.tr('Failed to load reminders');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _reminders = [];
    _error = null;
    notifyListeners();
  }

  Future<void> addReminder(VaccineReminder reminder) async {
    try {
      await _repository.saveReminder(reminder);
      _reminders.add(reminder);
      _reminders.sort((a, b) => (a.nextDate ?? DateTime(9999))
          .compareTo(b.nextDate ?? DateTime(9999)));
      notifyListeners();
    } catch (e) {
      _error = AppStrings.tr('Failed to add reminder');
      notifyListeners();
    }
  }

  Future<void> updateReminder(VaccineReminder reminder) async {
    try {
      await _repository.saveReminder(reminder);
      final index = _reminders.indexWhere((r) => r.reminderId == reminder.reminderId);
      if (index >= 0) {
        _reminders[index] = reminder;
        notifyListeners();
      }
    } catch (e) {
      _error = AppStrings.tr('Failed to update reminder');
      notifyListeners();
    }
  }

  Future<void> markCompleted(String reminderId) async {
    final index = _reminders.indexWhere((r) => r.reminderId == reminderId);
    if (index < 0) return;

    final reminder = _reminders[index];
    final now = DateTime.now();
    final nextDate = now.add(Duration(days: reminder.intervalDays));

    final updated = reminder.copyWith(
      lastDate: now,
      nextDate: nextDate,
      isCompleted: false,
    );

    await updateReminder(updated);
  }

  Future<void> deleteReminder(String reminderId) async {
    try {
      await _repository.deleteReminder(reminderId);
      _reminders.removeWhere((r) => r.reminderId == reminderId);
      notifyListeners();
    } catch (e) {
      _error = AppStrings.tr('Failed to delete reminder');
      notifyListeners();
    }
  }
}
