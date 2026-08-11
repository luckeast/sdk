import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/health_record.dart';
import '../models/achievement_record.dart';
import '../providers/auth_provider.dart';
import '../providers/achievement_provider.dart';
import '../providers/growth_progress_provider.dart';
import '../providers/health_data_provider.dart';
import '../services/growth_service.dart';
import '../services/image_service.dart';
import '../widgets/achievement_feedback_overlay.dart';
import '../theme/app_theme.dart';
import '../widgets/growth_feedback_overlay.dart';
import '../widgets/gradient_button.dart';
import '../widgets/voice_text_field.dart';

/// Result returned after saving a health record.
class QuickRecordResult {
  final HealthRecord record;
  final String aiSummary;
  final bool isEditing;

  const QuickRecordResult({
    required this.record,
    required this.aiSummary,
    required this.isEditing,
  });
}

/// Quick record screen for adding or editing health data.
class QuickRecordScreen extends StatefulWidget {
  final String petId;
  final String initialRecordType;
  final HealthRecord? existingRecord;

  const QuickRecordScreen({
    super.key,
    required this.petId,
    this.initialRecordType = 'weight',
    this.existingRecord,
  });

  @override
  State<QuickRecordScreen> createState() => _QuickRecordScreenState();
}

class _QuickRecordScreenState extends State<QuickRecordScreen> {
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final ImageService _imageService = ImageService();
  final Map<String, Map<String, dynamic>> _recordConfigs =
      <String, Map<String, dynamic>>{
        'weight': <String, dynamic>{
          'label': 'Weight',
          'unit': 'kg',
          'icon': Icons.monitor_weight,
        },
        'water': <String, dynamic>{
          'label': 'Water',
          'unit': 'ml',
          'icon': Icons.water_drop,
        },
        'exercise': <String, dynamic>{
          'label': 'Exercise',
          'unit': 'min',
          'icon': Icons.directions_run,
        },
        'sleep': <String, dynamic>{
          'label': 'Sleep',
          'unit': 'hours',
          'icon': Icons.bedtime,
        },
        'meal': <String, dynamic>{
          'label': 'Meal',
          'unit': 'kcal',
          'icon': Icons.restaurant,
        },
      };

  late String _recordType;
  late DateTime _selectedDate;
  File? _photoPreviewFile;
  File? _pendingPhotoFile;
  String _existingPhotoPath = '';
  bool _isSaving = false;
  bool _removeExistingPhoto = false;

  bool get _isEditing => widget.existingRecord != null;

  @override
  void initState() {
    super.initState();
    final HealthRecord? existingRecord = widget.existingRecord;
    _recordType = existingRecord?.recordType ?? widget.initialRecordType;
    _selectedDate = DateUtils.dateOnly(
      existingRecord?.recordedAt ?? DateTime.now(),
    );
    _valueController.text = existingRecord?.value.toString() ?? '';
    _noteController.text = existingRecord?.note ?? '';
    _existingPhotoPath = existingRecord?.photoPath ?? '';

    if (_existingPhotoPath.isNotEmpty) {
      _loadExistingPhoto();
    }
  }

  Future<void> _loadExistingPhoto() async {
    final File? existingFile = await _imageService.loadImage(
      _existingPhotoPath,
    );
    if (!mounted || existingFile == null) {
      return;
    }

    setState(() {
      _photoPreviewFile = existingFile;
    });
  }

  Future<void> _saveRecord({required bool keepEditing}) async {
    final double? value = double.tryParse(_valueController.text);
    final GrowthProgressProvider growthProvider = context
        .read<GrowthProgressProvider>();
    final AchievementProvider achievementProvider = context
        .read<AchievementProvider>();
    final HealthDataProvider healthDataProvider = context
        .read<HealthDataProvider>();
    final AuthProvider authProvider = context.read<AuthProvider>();

    if (value == null || value <= 0) {
      _showError(context.tr('Please enter a valid value'));
      return;
    }

    setState(() => _isSaving = true);

    final String recordId =
        widget.existingRecord?.recordId ??
        'record_${DateTime.now().millisecondsSinceEpoch}';
    final HealthRecord? previousRecord = _findComparisonRecord(
      healthDataProvider.records,
      recordId,
    );

    try {
      String photoPath = _existingPhotoPath;

      if (_pendingPhotoFile != null) {
        if (_existingPhotoPath.isNotEmpty) {
          await _imageService.deleteImage(_existingPhotoPath);
        }
        photoPath = await _imageService.saveImage(
          _pendingPhotoFile!,
          'health_records',
          recordId,
        );
      } else if (_removeExistingPhoto && _existingPhotoPath.isNotEmpty) {
        await _imageService.deleteImage(_existingPhotoPath);
        photoPath = '';
      }

      final DateTime recordedAt = _composeRecordedAt(
        _selectedDate,
        widget.existingRecord?.recordedAt,
      );

      final HealthRecord record = HealthRecord(
        recordId: recordId,
        petId: widget.petId,
        recordType: _recordType,
        value: value,
        unit: _recordConfigs[_recordType]!['unit'] as String,
        note: _noteController.text.trim(),
        photoPath: photoPath,
        recordedAt: recordedAt,
      );

      if (_isEditing) {
        await healthDataProvider.updateRecord(record);
      } else {
        await healthDataProvider.addRecord(record);
      }

      await achievementProvider.loadAchievements(widget.petId);
      final List<AchievementRecord> achievementUnlocks =
          await achievementProvider.evaluateRecordSaved(
            record: record,
            previousRecord: previousRecord,
            totalRecordCount: healthDataProvider.records.length,
          );

      GrowthActivityResult? growthResult;
      if (!_isEditing && growthProvider.progress != null) {
        if (_recordType == 'exercise') {
          growthResult = await growthProvider.awardExerciseXp();
        } else {
          growthResult = await growthProvider.awardMealXp();
        }
      }

      if (mounted && growthResult != null) {
        if (growthResult.reward.freeAiUses > 0) {
          await authProvider.refreshCurrentUser();
          if (!mounted) {
            return;
          }
        }
        final List<AchievementRecord> growthAchievementUnlocks =
            await achievementProvider.evaluateGrowth(
              level: growthResult.currentLevel,
              streakDays: growthProvider.streakDays,
              imagePath: record.photoPath,
            );
        achievementUnlocks.addAll(growthAchievementUnlocks);
        if (!mounted) {
          return;
        }
        await GrowthFeedbackOverlay.showForResult(
          context,
          growthResult,
          label: context.tr('Record saved'),
        );
      }
      if (mounted && achievementUnlocks.isNotEmpty) {
        AchievementFeedbackOverlay.showAll(
          context,
          achievementProvider,
          achievementUnlocks,
        );
      }

      final QuickRecordResult result = QuickRecordResult(
        record: record,
        aiSummary: _buildAiSummary(
          record: record,
          previousRecord: previousRecord,
          hadPhoto: photoPath.isNotEmpty,
          isEditing: _isEditing,
        ),
        isEditing: _isEditing,
      );

      if (!mounted) {
        return;
      }

      if (keepEditing) {
        _resetFormForNextRecord();
        _showInlineSuccess(
          context.tr('Saved. Add another one whenever you\'re ready.'),
        );
        return;
      }

      Navigator.pop(context, result);
    } catch (error) {
      _showError(context.tr('Could not save this record right now'));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  HealthRecord? _findComparisonRecord(
    List<HealthRecord> records,
    String currentRecordId,
  ) {
    final Iterable<HealthRecord> sameTypeRecords = records.where(
      (HealthRecord record) =>
          record.recordType == _recordType &&
          record.recordId != currentRecordId,
    );

    if (sameTypeRecords.isEmpty) {
      return null;
    }

    final List<HealthRecord> sortedRecords = sameTypeRecords.toList()
      ..sort(
        (HealthRecord first, HealthRecord second) =>
            second.recordedAt.compareTo(first.recordedAt),
      );
    return sortedRecords.first;
  }

  void _resetFormForNextRecord() {
    _valueController.clear();
    _noteController.clear();
    _selectedDate = DateUtils.dateOnly(DateTime.now());
    _photoPreviewFile = null;
    _pendingPhotoFile = null;
    _existingPhotoPath = '';
    _removeExistingPhoto = false;
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  DateTime _composeRecordedAt(DateTime selectedDate, DateTime? existingTime) {
    final DateTime baseTime = existingTime ?? DateTime.now();
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      baseTime.hour,
      baseTime.minute,
      baseTime.second,
      baseTime.millisecond,
      baseTime.microsecond,
    );
  }

  Future<void> _pickRecordedDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateUtils.dateOnly(DateTime.now()),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateUtils.dateOnly(picked);
      });
    }
  }

  Future<void> _pickPhotoFromCamera() async {
    final File? imageFile = await _imageService.captureImage();
    if (imageFile == null || !mounted) {
      return;
    }

    setState(() {
      _pendingPhotoFile = imageFile;
      _photoPreviewFile = imageFile;
      _removeExistingPhoto = false;
    });
  }

  Future<void> _pickPhotoFromGallery() async {
    final File? imageFile = await _imageService.pickFromGallery();
    if (imageFile == null || !mounted) {
      return;
    }

    setState(() {
      _pendingPhotoFile = imageFile;
      _photoPreviewFile = imageFile;
      _removeExistingPhoto = false;
    });
  }

  void _removePhoto() {
    setState(() {
      _pendingPhotoFile = null;
      _photoPreviewFile = null;
      _removeExistingPhoto = _existingPhotoPath.isNotEmpty;
      _existingPhotoPath = '';
    });
  }

  String _buildAiSummary({
    required HealthRecord record,
    required HealthRecord? previousRecord,
    required bool hadPhoto,
    required bool isEditing,
  }) {
    final String label = _recordConfigs[record.recordType]!['label'] as String;
    final String valueText = _formatValue(record.value);
    final String unit = record.unit;
    final String photoText = hadPhoto ? ' Photo added too, nice touch.' : '';

    if (previousRecord == null) {
      final String intro = isEditing
          ? 'Updated $label to $valueText $unit.'
          : 'Logged $label at $valueText $unit.';
      return '$intro$photoText Great start. Keep a couple more entries coming so I can spot a trend for you.';
    }

    final double difference = record.value - previousRecord.value;
    final String direction = difference > 0
        ? 'up'
        : (difference < 0 ? 'down' : 'steady');
    final String diffText = difference == 0
        ? 'holding steady'
        : '$direction ${_formatValue(difference.abs())} $unit';

    switch (record.recordType) {
      case 'weight':
        return 'Weight is now $valueText $unit, $diffText from the last check.$photoText Small shifts are normal, but keep an eye on the weekly trend.';
      case 'water':
        return 'Water intake came in at $valueText $unit, $diffText.$photoText If this keeps dipping, try refreshing the bowl more often.';
      case 'exercise':
        return 'Exercise reached $valueText $unit today, $diffText.$photoText Love that energy. A little consistency here goes a long way.';
      case 'sleep':
        return 'Sleep landed at $valueText $unit, $diffText.$photoText If rest starts swinging a lot, it may be worth watching routine or stress.';
      case 'meal':
        return 'Meal data is $valueText $unit, $diffText.$photoText Balanced changes are fine. Keep the portions and timing consistent for cleaner patterns.';
      default:
        return '$label is at $valueText $unit, $diffText.$photoText Looking good. Keep tracking and I\'ll keep translating the pattern for you.';
    }
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void _showInlineSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> config = _recordConfigs[_recordType]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? context.tr('Edit Record') : context.tr('Quick Record'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.tr('Record Type'),
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recordConfigs.entries.map((
                MapEntry<String, Map<String, dynamic>> entry,
              ) {
                final bool isSelected = entry.key == _recordType;
                return ChoiceChip(
                  avatar: Icon(entry.value['icon'] as IconData, size: 18),
                  label: Text(context.tr(entry.value['label'] as String)),
                  selected: isSelected,
                  onSelected: _isSaving
                      ? null
                      : (_) => setState(() => _recordType = entry.key),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('Record Date'),
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _isSaving ? null : _pickRecordedDate,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textDisabled),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _formatDate(_selectedDate),
                        style: AppTextStyles.body,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            VoiceTextField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText:
                    '${context.tr(config['label'] as String)} (${config['unit']})',
                hintText: context.tr('Enter value'),
                prefixIcon: Icon(config['icon'] as IconData),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enableSpeechInput: false,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            VoiceTextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: context.tr('Note (optional)'),
                hintText: context.tr('Add any additional details'),
                prefixIcon: const Icon(Icons.notes),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('Photo (optional)'),
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _RecordPhotoPanel(
              photoFile: _photoPreviewFile,
              onCameraTap: _isSaving ? null : _pickPhotoFromCamera,
              onGalleryTap: _isSaving ? null : _pickPhotoFromGallery,
              onRemoveTap: _isSaving || _photoPreviewFile == null
                  ? null
                  : _removePhoto,
            ),
            const SizedBox(height: 32),
            Row(
              children: <Widget>[
                if (!_isEditing) ...<Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => _saveRecord(keepEditing: true),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          context.tr('Save & Add More'),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: GradientButton(
                    text: _isEditing
                        ? context.tr('Save Changes')
                        : context.tr('Save Record'),
                    onPressed: _isSaving
                        ? null
                        : () => _saveRecord(keepEditing: false),
                    isLoading: _isSaving,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordPhotoPanel extends StatelessWidget {
  final File? photoFile;
  final VoidCallback? onCameraTap;
  final VoidCallback? onGalleryTap;
  final VoidCallback? onRemoveTap;

  const _RecordPhotoPanel({
    required this.photoFile,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onRemoveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textDisabled),
      ),
      child: Column(
        children: <Widget>[
          if (photoFile != null) ...<Widget>[
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  photoFile!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...<Widget>[
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.background,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.textSecondary,
                      size: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('Attach a quick snapshot if it helps'),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCameraTap,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(context.tr('Camera')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGalleryTap,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(context.tr('Gallery')),
                ),
              ),
            ],
          ),
          if (photoFile != null) ...<Widget>[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onRemoveTap,
              icon: const Icon(Icons.delete_outline),
              label: Text(context.tr('Remove Photo')),
            ),
          ],
        ],
      ),
    );
  }
}
