import 'package:hive/hive.dart';
import '../models/vaccine_reminder.dart';

/// Repository interface for vaccine reminder CRUD operations.
abstract class VaccineReminderRepository {
  Future<List<VaccineReminder>> getRemindersByPet(String petId);
  Future<VaccineReminder?> getReminder(String reminderId);
  Future<void> saveReminder(VaccineReminder reminder);
  Future<void> deleteReminder(String reminderId);
  Future<List<VaccineReminder>> getActiveReminders(String petId);
  Future<List<VaccineReminder>> getOverdueReminders(String petId);
}

/// Hive implementation of VaccineReminderRepository.
class HiveVaccineReminderRepository implements VaccineReminderRepository {
  static const String _boxName = 'vaccine_reminders';
  Box<VaccineReminder>? _box;

  Future<Box<VaccineReminder>> get _boxInstance async {
    if (_box != null && !_box!.isOpen) {
      _box = null;
    }
    _box ??= await Hive.openBox<VaccineReminder>(_boxName);
    return _box!;
  }

  @override
  Future<List<VaccineReminder>> getRemindersByPet(String petId) async {
    final box = await _boxInstance;
    return box.values.where((r) => r.petId == petId).toList()
      ..sort((a, b) => (a.nextDate ?? DateTime(9999))
          .compareTo(b.nextDate ?? DateTime(9999)));
  }

  @override
  Future<VaccineReminder?> getReminder(String reminderId) async {
    final box = await _boxInstance;
    return box.get(reminderId);
  }

  @override
  Future<void> saveReminder(VaccineReminder reminder) async {
    final box = await _boxInstance;
    await box.put(reminder.reminderId, reminder);
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    final box = await _boxInstance;
    await box.delete(reminderId);
  }

  @override
  Future<List<VaccineReminder>> getActiveReminders(String petId) async {
    final all = await getRemindersByPet(petId);
    return all.where((r) => r.isActive && !r.isCompleted).toList();
  }

  @override
  Future<List<VaccineReminder>> getOverdueReminders(String petId) async {
    final all = await getRemindersByPet(petId);
    return all.where((r) => r.isOverdue && !r.isCompleted).toList();
  }
}
