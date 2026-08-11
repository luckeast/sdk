import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../models/meal_analysis.dart';
import '../models/achievement_record.dart';
import '../providers/auth_provider.dart';
import '../providers/achievement_provider.dart';
import '../providers/meal_analysis_provider.dart';
import '../providers/growth_progress_provider.dart';
import '../providers/purchase_provider.dart';
import '../services/growth_service.dart';
import '../services/ai_analysis_service.dart';
import '../services/ai_consent_service.dart';
import '../services/image_service.dart';
import 'store_screen.dart';
import '../widgets/achievement_feedback_overlay.dart';
import '../theme/app_theme.dart';
import '../utils/debug_logger.dart';
import '../widgets/growth_feedback_overlay.dart';
import '../widgets/gradient_button.dart';

/// Screen for capturing and analyzing pet meal photos.
class CaptureScreen extends StatefulWidget {
  final String petId;

  const CaptureScreen({super.key, required this.petId});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  static const int _analysisCost = 10;

  final ImageService _imageService = ImageService();
  final AiAnalysisService _analysisService = AiAnalysisService();
  final AiConsentService _consentService = AiConsentService();
  File? _imageFile;
  String _foodType = 'Dry Food';
  AiScanMode _scanMode = AiScanMode.foodRecognition;
  final TextEditingController _customPromptController = TextEditingController();
  bool _isAnalyzing = false;
  MealAnalysis? _analysis;
  AiScanResult? _scanResult;

  final List<String> _foodTypes = [
    'Dry Food',
    'Wet Food',
    'Homemade',
    'Treats',
    'Raw Food',
  ];

  Future<void> _capturePhoto() async {
    final file = await _imageService.captureImage();
    if (file != null) {
      setState(() {
        _imageFile = file;
        _analysis = null;
        _scanResult = null;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await _imageService.pickFromGallery();
    if (file != null) {
      setState(() {
        _imageFile = file;
        _analysis = null;
        _scanResult = null;
      });
    }
  }

  Future<void> _runScan() async {
    if (_imageFile == null) return;

    final bool hasConsent = await _consentService.ensureConsent(context);
    if (!hasConsent || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final achievementProvider = context.read<AchievementProvider>();
    final purchaseProvider = context.read<PurchaseProvider>();
    final mealAnalysisProvider = context.read<MealAnalysisProvider>();
    final growthProvider = context.read<GrowthProgressProvider>();
    final bool hasFreeAiUse = authProvider.freeAiUses > 0;
    if (!hasFreeAiUse && purchaseProvider.balance < _analysisCost) {
      _showInsufficientCoinsDialog();
      return;
    }
    if (!hasFreeAiUse) {
      final bool confirmed = await _showCoinSpendConfirmationDialog();
      if (!confirmed || !mounted) {
        return;
      }
    }

    setState(() => _isAnalyzing = true);

    DebugLogger.log(
      hypothesisId: 'AI_SCAN',
      location: 'capture_screen.dart:_runScan:start',
      message: 'AIScan started',
      data: {
        'petId': widget.petId,
        'scanMode': _scanMode.name,
        'foodType': _foodType,
        'imagePath': _imageFile!.path,
        'coinBalance': purchaseProvider.balance,
        'customPromptLength': _customPromptController.text.trim().length,
      },
    );

    try {
      if (hasFreeAiUse) {
        await authProvider.consumeFreeAiUse();
      } else {
        DebugLogger.log(
          hypothesisId: 'AI_SCAN',
          location: 'capture_screen.dart:_runScan:spendCoins',
          message: 'Spending coins for AIScan',
          data: {
            'analysisCost': _analysisCost,
            'balanceBeforeSpend': purchaseProvider.balance,
          },
        );
        await purchaseProvider.spendCoins(_analysisCost);
      }

      final relativePath = await _imageService.saveImage(
        _imageFile!,
        'meal_photos',
        widget.petId,
      );

      DebugLogger.log(
        hypothesisId: 'AI_SCAN',
        location: 'capture_screen.dart:_runScan:imageSaved',
        message: 'AIScan image saved',
        data: {'relativePath': relativePath, 'scanMode': _scanMode.name},
      );

      if (_scanMode == AiScanMode.foodRecognition) {
        DebugLogger.log(
          hypothesisId: 'AI_SCAN',
          location: 'capture_screen.dart:_runScan:analyzeMeal',
          message: 'Calling analyzeMeal()',
          data: {
            'petId': widget.petId,
            'photoPath': relativePath,
            'foodType': _foodType,
          },
        );
        final analysis = await _analysisService.analyzeMeal(
          petId: widget.petId,
          photoPath: relativePath,
          foodType: _foodType,
        );

        DebugLogger.log(
          hypothesisId: 'AI_SCAN',
          location: 'capture_screen.dart:_runScan:analyzeMealSuccess',
          message: 'analyzeMeal() completed',
          data: {
            'nutritionScore': analysis.nutritionScore,
            'estimatedCalories': analysis.estimatedCalories,
            'portionSize': analysis.portionSize,
          },
        );

        await mealAnalysisProvider.addAnalysis(analysis);
        await achievementProvider.loadAchievements(widget.petId);
        final List<AchievementRecord> achievementUnlocks =
            await achievementProvider.evaluateMealScan(
              imagePath: relativePath,
              foodType: _foodType,
            );

        if (growthProvider.progress != null) {
          final GrowthActivityResult? result = await growthProvider
              .awardMealXp();
          if (!mounted) {
            return;
          }
          if (result != null && result.reward.freeAiUses > 0) {
            await authProvider.refreshCurrentUser();
            if (!mounted) {
              return;
            }
          }
          if (result != null) {
            achievementUnlocks.addAll(
              await achievementProvider.evaluateGrowth(
                level: result.currentLevel,
                streakDays: growthProvider.streakDays,
                imagePath: relativePath,
              ),
            );
          }
          if (!mounted) {
            return;
          }
          await GrowthFeedbackOverlay.showForResult(
            context,
            result,
            label: hasFreeAiUse
                ? context.tr('Free AI used')
                : context.tr('Meal analyzed'),
          );
        }
        if (!mounted) {
          return;
        }
        if (achievementUnlocks.isNotEmpty) {
          AchievementFeedbackOverlay.showAll(
            context,
            achievementProvider,
            achievementUnlocks,
          );
        }

        if (!mounted) {
          return;
        }
        setState(() {
          _analysis = analysis;
          _scanResult = null;
          _isAnalyzing = false;
        });
        return;
      }

      DebugLogger.log(
        hypothesisId: 'AI_SCAN',
        location: 'capture_screen.dart:_runScan:analyzeScan',
        message: 'Calling analyzeScan()',
        data: {
          'photoPath': relativePath,
          'mode': _scanMode.name,
          'customPrompt': _customPromptController.text.trim(),
        },
      );
      final result = await _analysisService.analyzeScan(
        photoPath: relativePath,
        mode: _scanMode,
        customPrompt: _customPromptController.text.trim(),
      );

      DebugLogger.log(
        hypothesisId: 'AI_SCAN',
        location: 'capture_screen.dart:_runScan:analyzeScanSuccess',
        message: 'analyzeScan() completed',
        data: {
          'title': result.title,
          'tagsCount': result.tags.length,
          'highlightsCount': result.highlights.length,
          'rawTextLength': result.rawText.length,
        },
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _analysis = null;
        _scanResult = result;
        _isAnalyzing = false;
      });
    } catch (e, stackTrace) {
      DebugLogger.log(
        hypothesisId: 'AI_SCAN',
        location: 'capture_screen.dart:_runScan:catch',
        message: 'AIScan failed',
        data: {
          'error': e.toString(),
          'stackTrace': stackTrace.toString(),
          'scanMode': _scanMode.name,
          'foodType': _foodType,
          'imagePath': _imageFile?.path,
          'customPrompt': _customPromptController.text.trim(),
        },
      );
      if (!mounted) {
        return;
      }
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Analysis failed. Please try again.')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _customPromptController.dispose();
    super.dispose();
  }

  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.tr('Insufficient PawCoins'),
          style: AppTextStyles.headline,
        ),
        content: Text(
          context.tr(
            'AI Meal Analysis costs {coins} PawCoins. You need more coins to continue.',
            params: <String, String>{'coins': '$_analysisCost'},
          ),
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreScreen()),
              );
            },
            child: Text(context.tr('Get Coins')),
          ),
        ],
      ),
    );
  }

  Future<bool> _showCoinSpendConfirmationDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.tr('Confirm PawCoin Spend'),
          style: AppTextStyles.headline,
        ),
        content: Text(
          context.tr(
            'Using AIScan will spend {coins} PawCoins. Do you want to continue?',
            params: <String, String>{'coins': '$_analysisCost'},
          ),
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Continue')),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('AIScan'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_imageFile == null) ...[
              _PhotoSelector(
                onCamera: _capturePhoto,
                onGallery: _pickFromGallery,
              ),
            ] else ...[
              _PhotoPreview(
                imageFile: _imageFile!,
                onRetake: () => setState(() {
                  _imageFile = null;
                  _analysis = null;
                  _scanResult = null;
                }),
              ),
              const SizedBox(height: 16),
              _ScanModeSelector(
                selectedMode: _scanMode,
                onChanged: (mode) => setState(() {
                  _scanMode = mode;
                  _analysis = null;
                  _scanResult = null;
                }),
              ),
              if (_scanMode == AiScanMode.foodRecognition) ...[
                const SizedBox(height: 16),
                _FoodTypeSelector(
                  selectedType: _foodType,
                  types: _foodTypes,
                  onChanged: (type) => setState(() => _foodType = type),
                ),
              ],
              if (_scanMode == AiScanMode.custom) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _customPromptController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.tr('Custom request'),
                    hintText: context.tr(
                      'Example: identify the toy, explain body language, or summarize what is visible.',
                    ),
                  ),
                  onChanged: (_) => setState(() {
                    _scanResult = null;
                  }),
                ),
              ],
              const SizedBox(height: 20),
              if (_analysis == null && _scanResult == null) ...[
                Text(
                  context.tr(
                    'AIScan costs {coins} PawCoins per use.',
                    params: <String, String>{'coins': '$_analysisCost'},
                  ),
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (context.watch<AuthProvider>().freeAiUses > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'You have free AI uses available, so this scan will not spend PawCoins first.',
                    ),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                GradientButton(
                  text: context.tr(
                    _scanMode == AiScanMode.foodRecognition
                        ? 'Analyze Food · {coins} PawCoins'
                        : 'Run AIScan · {coins} PawCoins',
                    params: <String, String>{'coins': '$_analysisCost'},
                  ),
                  onPressed: _isAnalyzing ? null : _runScan,
                  isLoading: _isAnalyzing,
                  icon: Icons.auto_awesome,
                ),
              ] else if (_analysis != null)
                _AnalysisResult(analysis: _analysis!),
              if (_scanResult != null) _ScanResultCard(result: _scanResult!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoSelector extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _PhotoSelector({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            context.tr('Snap a Photo for AIScan'),
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Recognize food, breeds, mood, or any custom pet-related request',
            ),
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.camera_alt),
                label: Text(context.tr('Camera')),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library),
                label: Text(context.tr('Gallery')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanModeSelector extends StatelessWidget {
  final AiScanMode selectedMode;
  final ValueChanged<AiScanMode> onChanged;

  const _ScanModeSelector({
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = <({AiScanMode mode, String label})>[
      (mode: AiScanMode.foodRecognition, label: context.tr('Food')),
      (mode: AiScanMode.breedRecognition, label: context.tr('Breed')),
      (mode: AiScanMode.petMood, label: context.tr('Mood')),
      (mode: AiScanMode.custom, label: context.tr('Custom')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('What would you like AIScan to do?'),
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedMode == option.mode;
            return ChoiceChip(
              label: Text(option.label),
              selected: isSelected,
              onSelected: (_) => onChanged(option.mode),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  final File imageFile;
  final VoidCallback onRetake;

  const _PhotoPreview({required this.imageFile, required this.onRetake});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.file(
            imageFile,
            width: double.infinity,
            height: 300,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: onRetake,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

class _FoodTypeSelector extends StatelessWidget {
  final String selectedType;
  final List<String> types;
  final ValueChanged<String> onChanged;

  const _FoodTypeSelector({
    required this.selectedType,
    required this.types,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Food Type'),
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((type) {
            final isSelected = type == selectedType;
            return ChoiceChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (_) => onChanged(type),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AnalysisResult extends StatelessWidget {
  final MealAnalysis analysis;

  const _AnalysisResult({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScoreCard(score: analysis.nutritionScore),
        const SizedBox(height: 16),
        _NutritionBreakdown(analysis: analysis),
        const SizedBox(height: 16),
        _AdviceCard(advice: analysis.feedingAdvice),
        const SizedBox(height: 24),
        GradientButton(
          text: context.tr('Save Analysis'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int score;

  const _ScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    Color scoreColor;
    if (score >= 80) {
      scoreColor = AppColors.success;
    } else if (score >= 60) {
      scoreColor = AppColors.accent;
    } else {
      scoreColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor.withOpacity(0.15), scoreColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('Nutrition Score'), style: AppTextStyles.title),
                const SizedBox(height: 4),
                Text(
                  score >= 80
                      ? 'Excellent nutrition balance!'
                      : score >= 60
                      ? 'Good, but could be better'
                      : 'Needs improvement',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionBreakdown extends StatelessWidget {
  final MealAnalysis analysis;

  const _NutritionBreakdown({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Nutrition Breakdown'), style: AppTextStyles.title),
          const SizedBox(height: 16),
          _NutrientBar(
            label: 'Protein',
            value: analysis.proteinPercent,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 12),
          _NutrientBar(
            label: 'Carbs',
            value: analysis.carbsPercent,
            color: AppColors.accent,
          ),
          const SizedBox(height: 12),
          _NutrientBar(
            label: 'Fat',
            value: analysis.fatPercent,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Calories:',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${analysis.estimatedCalories} kcal',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Portion Size:',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                analysis.portionSize,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NutrientBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _NutrientBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.caption),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _AdviceCard extends StatelessWidget {
  final String advice;

  const _AdviceCard({required this.advice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Feeding Advice',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(advice, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _ScanResultCard extends StatelessWidget {
  final AiScanResult result;

  const _ScanResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.title,
                style: AppTextStyles.title.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                result.summary,
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (result.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: result.tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        if (result.tags.isNotEmpty) const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Key Observations'), style: AppTextStyles.title),
              const SizedBox(height: 12),
              ...result.highlights.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: Icon(
                          Icons.circle,
                          size: 8,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item, style: AppTextStyles.body)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AdviceCard(advice: result.advice),
        const SizedBox(height: 24),
        GradientButton(text: 'Done', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
