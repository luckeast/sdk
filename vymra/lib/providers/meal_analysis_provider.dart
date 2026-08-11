import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/meal_analysis.dart';
import '../repositories/meal_analysis_repository.dart';

/// Provider for managing meal analysis records.
class MealAnalysisProvider extends ChangeNotifier {
  final MealAnalysisRepository _repository;
  List<MealAnalysis> _analyses = [];
  bool _isLoading = false;
  String? _error;

  MealAnalysisProvider(this._repository);

  List<MealAnalysis> get analyses => List.unmodifiable(_analyses);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAnalyses(String petId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _analyses = await _repository.getAnalysesByPet(petId);
    } catch (e) {
      _analyses = [];
      _error = AppStrings.tr('Failed to load meal analyses');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _analyses = [];
    _error = null;
    notifyListeners();
  }

  Future<void> addAnalysis(MealAnalysis analysis) async {
    try {
      await _repository.saveAnalysis(analysis);
      _analyses.insert(0, analysis);
      _analyses.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
      notifyListeners();
    } catch (e) {
      _error = AppStrings.tr('Failed to save analysis');
      notifyListeners();
    }
  }

  Future<void> deleteAnalysis(String analysisId) async {
    try {
      await _repository.deleteAnalysis(analysisId);
      _analyses.removeWhere((a) => a.analysisId == analysisId);
      notifyListeners();
    } catch (e) {
      _error = AppStrings.tr('Failed to delete analysis');
      notifyListeners();
    }
  }
}
