import 'package:hive/hive.dart';
import '../models/growth_progress.dart';

/// Repository interface for growth progress operations.
abstract class GrowthProgressRepository {
  Future<GrowthProgress?> getProgress(String petId);
  Future<void> saveProgress(GrowthProgress progress);
  Future<void> deleteProgress(String petId);
}

/// Hive implementation of GrowthProgressRepository.
class HiveGrowthProgressRepository implements GrowthProgressRepository {
  static const String _boxName = 'growth_progress';
  Box<GrowthProgress>? _box;

  Future<Box<GrowthProgress>> get _boxInstance async {
    if (_box != null && !_box!.isOpen) {
      _box = null;
    }
    _box ??= await Hive.openBox<GrowthProgress>(_boxName);
    return _box!;
  }

  @override
  Future<GrowthProgress?> getProgress(String petId) async {
    final box = await _boxInstance;
    return box.get(petId);
  }

  @override
  Future<void> saveProgress(GrowthProgress progress) async {
    final box = await _boxInstance;
    await box.put(progress.petId, progress);
  }

  @override
  Future<void> deleteProgress(String petId) async {
    final box = await _boxInstance;
    await box.delete(petId);
  }
}
