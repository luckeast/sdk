import 'package:hive/hive.dart';
import '../models/health_record.dart';

/// Repository interface for health record CRUD operations.
abstract class HealthRecordRepository {
  Future<List<HealthRecord>> getRecordsByPet(String petId);
  Future<List<HealthRecord>> getRecordsByType(String petId, String recordType);
  Future<HealthRecord?> getRecord(String recordId);
  Future<void> saveRecord(HealthRecord record);
  Future<void> deleteRecord(String recordId);
  Future<List<HealthRecord>> getRecentRecords(String petId, {int limit = 30});
}

/// Hive implementation of HealthRecordRepository.
class HiveHealthRecordRepository implements HealthRecordRepository {
  static const String _boxName = 'health_records';
  Box<HealthRecord>? _box;

  Future<Box<HealthRecord>> get _boxInstance async {
    if (_box != null && !_box!.isOpen) {
      _box = null;
    }
    _box ??= await Hive.openBox<HealthRecord>(_boxName);
    return _box!;
  }

  @override
  Future<List<HealthRecord>> getRecordsByPet(String petId) async {
    final box = await _boxInstance;
    return box.values
        .where((r) => r.petId == petId)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  @override
  Future<List<HealthRecord>> getRecordsByType(String petId, String recordType) async {
    final box = await _boxInstance;
    return box.values
        .where((r) => r.petId == petId && r.recordType == recordType)
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  @override
  Future<HealthRecord?> getRecord(String recordId) async {
    final box = await _boxInstance;
    return box.get(recordId);
  }

  @override
  Future<void> saveRecord(HealthRecord record) async {
    final box = await _boxInstance;
    await box.put(record.recordId, record);
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    final box = await _boxInstance;
    await box.delete(recordId);
  }

  @override
  Future<List<HealthRecord>> getRecentRecords(String petId, {int limit = 30}) async {
    final all = await getRecordsByPet(petId);
    return all.take(limit).toList();
  }
}
