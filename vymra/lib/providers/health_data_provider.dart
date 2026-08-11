import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/health_record.dart';
import '../repositories/health_record_repository.dart';

/// Provider for managing health records and trend data.
class HealthDataProvider extends ChangeNotifier {
  final HealthRecordRepository _repository;
  List<HealthRecord> _records = [];
  bool _isLoading = false;
  String? _error;

  HealthDataProvider(this._repository);

  List<HealthRecord> get records => List.unmodifiable(_records);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<HealthRecord> getRecordsByType(String type) {
    return _records.where((r) => r.recordType == type).toList();
  }

  Future<void> loadRecords(String petId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _records = await _repository.getRecordsByPet(petId);
    } catch (e) {
      _records = [];
      _error = AppStrings.tr('Failed to load health records');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _records = [];
    _error = null;
    notifyListeners();
  }

  Future<void> addRecord(HealthRecord record) async {
    try {
      await _repository.saveRecord(record);
      _upsertLocalRecord(record);
      notifyListeners();
    } catch (e) {
      _error = AppStrings.tr('Failed to add health record');
      notifyListeners();
    }
  }

  Future<void> updateRecord(HealthRecord record) async {
    try {
      await _repository.saveRecord(record);
      _upsertLocalRecord(record);
      notifyListeners();
    } catch (e) {
      _error = AppStrings.tr('Failed to update health record');
      notifyListeners();
    }
  }

  Future<void> deleteRecord(String recordId) async {
    try {
      await _repository.deleteRecord(recordId);
      _records.removeWhere((r) => r.recordId == recordId);
      notifyListeners();
    } catch (e) {
      _error = AppStrings.tr('Failed to delete record');
      notifyListeners();
    }
  }

  /// Detect abnormal patterns (e.g., water intake drop >30%).
  List<String> detectAnomalies() {
    final anomalies = <String>[];

    final waterRecords = getRecordsByType('water');
    if (waterRecords.length >= 7) {
      final recent = waterRecords.take(7).map((r) => r.value).toList();
      final previous = waterRecords
          .skip(7)
          .take(7)
          .map((r) => r.value)
          .toList();

      if (previous.isNotEmpty) {
        final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
        final prevAvg = previous.reduce((a, b) => a + b) / previous.length;
        final change = (recentAvg - prevAvg) / prevAvg;

        if (change < -0.30) {
          anomalies.add(
            AppStrings.tr(
              'Water intake dropped {percent}% this week. Consider checking water freshness or consulting your vet.',
              params: <String, String>{
                'percent': '${(change.abs() * 100).toInt()}',
              },
            ),
          );
        }
      }
    }

    final weightRecords = getRecordsByType('weight');
    if (weightRecords.length >= 2) {
      final latest = weightRecords.first.value;
      final previous = weightRecords[1].value;
      final change = (latest - previous) / previous;

      if (change.abs() > 0.10) {
        final String direction = change > 0
            ? AppStrings.tr('increased')
            : AppStrings.tr('decreased');
        anomalies.add(
          AppStrings.tr(
            'Weight {direction} by {percent}% since last measurement.',
            params: <String, String>{
              'direction': direction,
              'percent': '${(change.abs() * 100).toInt()}',
            },
          ),
        );
      }
    }

    return anomalies;
  }

  /// Get trend data for chart display.
  List<MapEntry<DateTime, double>> getTrendData(String recordType) {
    final typeRecords = getRecordsByType(recordType);
    return typeRecords.map((r) => MapEntry(r.recordedAt, r.value)).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  void _upsertLocalRecord(HealthRecord record) {
    final int existingIndex = _records.indexWhere(
      (r) => r.recordId == record.recordId,
    );
    if (existingIndex >= 0) {
      _records[existingIndex] = record;
    } else {
      _records.insert(0, record);
    }

    _records.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }
}
