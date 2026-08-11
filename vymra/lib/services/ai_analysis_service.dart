import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/meal_analysis.dart';
import '../utils/debug_logger.dart';
import 'doubao_ai_service.dart';

enum AiScanMode { foodRecognition, breedRecognition, petMood, custom }

class AiScanResult {
  final String title;
  final String summary;
  final List<String> tags;
  final List<String> highlights;
  final String advice;
  final String rawText;

  const AiScanResult({
    required this.title,
    required this.summary,
    required this.tags,
    required this.highlights,
    required this.advice,
    required this.rawText,
  });
}

/// AI service for pet visual analysis using Doubao multimodal API.
class AiAnalysisService {
  final DoubaoAiService _doubao = DoubaoAiService();
  final Random _random = Random();

  /// Analyze a pet meal photo and return nutritional assessment.
  Future<MealAnalysis> analyzeMeal({
    required String petId,
    required String photoPath,
    required String foodType,
  }) async {
    try {
      return await _analyzeWithAi(
        petId: petId,
        photoPath: photoPath,
        foodType: foodType,
      );
    } catch (e) {
      return _analyzeWithSimulation(
        petId: petId,
        photoPath: photoPath,
        foodType: foodType,
      );
    }
  }

  Future<AiScanResult> analyzeScan({
    required String photoPath,
    required AiScanMode mode,
    String? customPrompt,
  }) async {
    final file = await _resolvePhotoFile(photoPath);
    debugPrint(
      'AIScan analyzeScan: mode=${mode.name} inputPath=$photoPath resolvedPath=${file.path} exists=${file.existsSync()}',
    );
    DebugLogger.log(
      hypothesisId: 'AI_SCAN_SERVICE',
      location: 'ai_analysis_service.dart:analyzeScan:start',
      message: 'Starting analyzeScan',
      data: {
        'mode': mode.name,
        'inputPath': photoPath,
        'resolvedPath': file.path,
        'exists': file.existsSync(),
      },
    );
    if (!file.existsSync()) {
      throw Exception(
        'Image file not found. inputPath=$photoPath resolvedPath=${file.path}',
      );
    }

    final base64Image = await DoubaoAiService.imageToBase64(file);
    final prompt = _buildScanPrompt(mode: mode, customPrompt: customPrompt);
    final response = await _doubao.chatCompletionWithImage(
      base64Image: base64Image,
      textPrompt: prompt,
      temperature: 0.25,
      maxTokens: 700,
    );

    final jsonStr = _extractJson(response);
    final Map<String, dynamic> data =
        jsonDecode(jsonStr) as Map<String, dynamic>;
    debugPrint(
      'AIScan analyzeScan success: mode=${mode.name} responseLength=${response.length}',
    );
    return AiScanResult(
      title: data['title'] as String? ?? _fallbackTitle(mode),
      summary:
          data['summary'] as String? ?? 'I analyzed the image successfully.',
      tags: (data['tags'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      highlights: (data['highlights'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      advice:
          data['advice'] as String? ??
          'Use this result as a helpful pet-care reference.',
      rawText: response,
    );
  }

  Future<MealAnalysis> _analyzeWithAi({
    required String petId,
    required String photoPath,
    required String foodType,
  }) async {
    final file = await _resolvePhotoFile(photoPath);
    debugPrint(
      'AIScan analyzeMeal: foodType=$foodType inputPath=$photoPath resolvedPath=${file.path} exists=${file.existsSync()}',
    );
    if (!file.existsSync()) {
      throw Exception(
        'Image file not found. inputPath=$photoPath resolvedPath=${file.path}',
      );
    }

    final base64Image = await DoubaoAiService.imageToBase64(file);

    final prompt =
        '''You are a pet nutrition expert. Analyze this pet meal photo.
Food type: $foodType.

Provide a JSON response with exactly this structure (no markdown, no extra text):
{
  "nutritionScore": <number 50-100>,
  "estimatedCalories": <number 100-800>,
  "proteinPercent": <number 15-55>,
  "carbsPercent": <number 15-55>,
  "fatPercent": <number 5-35>,
  "portionSize": "<Too Small|Just Right|Too Large>",
  "feedingAdvice": "<2-3 sentences of specific advice>"
}

Ensure proteinPercent + carbsPercent + fatPercent = 100.
FeedingAdvice must be in English, specific and actionable.''';

    final response = await _doubao.chatCompletionWithImage(
      base64Image: base64Image,
      textPrompt: prompt,
      temperature: 0.3,
      maxTokens: 512,
    );

    final jsonStr = _extractJson(response);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    return MealAnalysis(
      analysisId: 'analysis_${DateTime.now().millisecondsSinceEpoch}',
      petId: petId,
      photoPath: photoPath,
      foodType: foodType,
      portionSize: data['portionSize'] as String? ?? 'Just Right',
      nutritionScore: (data['nutritionScore'] as num?)?.toInt() ?? 70,
      estimatedCalories: (data['estimatedCalories'] as num?)?.toInt() ?? 300,
      proteinPercent: (data['proteinPercent'] as num?)?.toDouble() ?? 30,
      carbsPercent: (data['carbsPercent'] as num?)?.toDouble() ?? 40,
      fatPercent: (data['fatPercent'] as num?)?.toDouble() ?? 30,
      feedingAdvice:
          data['feedingAdvice'] as String? ??
          'Feed a balanced diet appropriate for your pet\'s age and size.',
      analyzedAt: DateTime.now(),
    );
  }

  MealAnalysis _analyzeWithSimulation({
    required String petId,
    required String photoPath,
    required String foodType,
  }) {
    final nutritionScore = 50 + _random.nextInt(51);
    final estimatedCalories = 150 + _random.nextInt(500);
    final proteinPercent = 15 + _random.nextInt(40);
    final carbsPercent = 20 + _random.nextInt(45);
    final fatPercent = (100 - proteinPercent - carbsPercent).clamp(5, 40);

    final portionOptions = ['Too Small', 'Just Right', 'Too Large'];
    final portionSize = portionOptions[_random.nextInt(3)];

    return MealAnalysis(
      analysisId: 'analysis_${DateTime.now().millisecondsSinceEpoch}',
      petId: petId,
      photoPath: photoPath,
      foodType: foodType,
      portionSize: portionSize,
      nutritionScore: nutritionScore,
      estimatedCalories: estimatedCalories,
      proteinPercent: proteinPercent.toDouble(),
      carbsPercent: carbsPercent.toDouble(),
      fatPercent: fatPercent.toDouble(),
      feedingAdvice: _generateAdvice(
        foodType: foodType,
        nutritionScore: nutritionScore,
        portionSize: portionSize,
      ),
      analyzedAt: DateTime.now(),
    );
  }

  String _generateAdvice({
    required String foodType,
    required int nutritionScore,
    required String portionSize,
  }) {
    final List<String> adviceParts = [];

    if (nutritionScore >= 80) {
      adviceParts.add(
        'Excellent nutritional balance! This meal provides a great mix of proteins, carbohydrates, and healthy fats.',
      );
    } else if (nutritionScore >= 60) {
      adviceParts.add(
        'Good nutritional profile. Consider adding more variety to boost the overall nutritional value.',
      );
    } else {
      adviceParts.add(
        'This meal could use some nutritional improvement. Try incorporating more protein sources and fresh vegetables.',
      );
    }

    if (portionSize == 'Too Small') {
      adviceParts.add(
        'The portion size appears smaller than recommended for your pet\'s weight. Consider increasing the serving slightly.',
      );
    } else if (portionSize == 'Too Large') {
      adviceParts.add(
        'The portion size seems larger than needed. Monitor your pet\'s weight and adjust portions accordingly.',
      );
    } else {
      adviceParts.add(
        'Portion size looks appropriate for your pet\'s current weight and activity level.',
      );
    }

    if (foodType == 'Homemade') {
      adviceParts.add(
        'For homemade meals, ensure you\'re including a calcium supplement and essential vitamins as recommended by your vet.',
      );
    } else if (foodType == 'Treats') {
      adviceParts.add(
        'Remember: treats should make up no more than 10% of your pet\'s daily caloric intake.',
      );
    }

    return adviceParts.join(' ');
  }

  String _extractJson(String response) {
    final jsonRegex = RegExp(r'\{[\s\S]*\}');
    final match = jsonRegex.firstMatch(response);
    if (match != null) {
      return match.group(0)!;
    }
    debugPrint(
      'AIScan extractJson failed: responseLength=${response.length} responsePreview=${response.substring(0, min(300, response.length))}',
    );
    throw Exception('No JSON found in AI response');
  }

  Future<File> _resolvePhotoFile(String photoPath) async {
    final directFile = File(photoPath);
    if (directFile.isAbsolute) {
      return directFile;
    }

    final appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}/$photoPath');
  }

  String _buildScanPrompt({required AiScanMode mode, String? customPrompt}) {
    final taskInstruction = switch (mode) {
      AiScanMode.foodRecognition =>
        'Identify the pet food or edible items in the image, infer likely ingredients, and mention visible feeding context.',
      AiScanMode.breedRecognition =>
        'Infer the likely pet species and possible breed or mix. Be explicit about uncertainty and mention the visible traits you used.',
      AiScanMode.petMood =>
        'Infer the pet\'s likely mood and body-language cues from posture, ears, eyes, mouth, and tail if visible. Avoid claiming certainty.',
      AiScanMode.custom =>
        'Answer this custom request about the pet image: ${customPrompt?.trim().isEmpty ?? true ? 'Describe the image in a useful pet-care way.' : customPrompt!.trim()}',
    };

    return '''You are a multimodal pet-care analysis assistant.

Task:
$taskInstruction

Return valid JSON only, without markdown:
{
  "title": "<short result title>",
  "summary": "<2-3 sentence concise summary>",
  "tags": ["<tag1>", "<tag2>", "<tag3>"],
  "highlights": ["<observation 1>", "<observation 2>", "<observation 3>"],
  "advice": "<1-2 sentence practical follow-up advice>"
}

Rules:
- Keep the answer grounded in visible evidence.
- If uncertain, say likely / possible rather than making a definitive claim.
- Do not mention that you are an AI model.
- Keep language friendly and plain English.''';
  }

  String _fallbackTitle(AiScanMode mode) {
    return switch (mode) {
      AiScanMode.foodRecognition => 'Food Recognition',
      AiScanMode.breedRecognition => 'Breed Recognition',
      AiScanMode.petMood => 'Pet Mood Insight',
      AiScanMode.custom => 'Custom Scan Result',
    };
  }
}
