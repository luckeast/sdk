import 'package:hive/hive.dart';
import '../models/meal_analysis.dart';

/// Repository interface for meal analysis CRUD operations.
abstract class MealAnalysisRepository {
  Future<List<MealAnalysis>> getAnalysesByPet(String petId);
  Future<MealAnalysis?> getAnalysis(String analysisId);
  Future<void> saveAnalysis(MealAnalysis analysis);
  Future<void> deleteAnalysis(String analysisId);
}

/// Hive implementation of MealAnalysisRepository.
class HiveMealAnalysisRepository implements MealAnalysisRepository {
  static const String _boxName = 'meal_analyses';
  Box<MealAnalysis>? _box;

  Future<Box<MealAnalysis>> get _boxInstance async {
    if (_box != null && !_box!.isOpen) {
      _box = null;
    }
    _box ??= await Hive.openBox<MealAnalysis>(_boxName);
    return _box!;
  }

  @override
  Future<List<MealAnalysis>> getAnalysesByPet(String petId) async {
    final box = await _boxInstance;
    return box.values
        .where((a) => a.petId == petId)
        .toList()
      ..sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
  }

  @override
  Future<MealAnalysis?> getAnalysis(String analysisId) async {
    final box = await _boxInstance;
    return box.get(analysisId);
  }

  @override
  Future<void> saveAnalysis(MealAnalysis analysis) async {
    final box = await _boxInstance;
    await box.put(analysis.analysisId, analysis);
  }

  @override
  Future<void> deleteAnalysis(String analysisId) async {
    final box = await _boxInstance;
    await box.delete(analysisId);
  }
}
