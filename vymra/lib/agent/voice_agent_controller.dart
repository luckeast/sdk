import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_strings.dart';
import '../models/ai_chat_record.dart';
import '../models/health_record.dart';
import '../models/pet_profile.dart';
import '../models/vaccine_reminder.dart';
import '../providers/achievement_provider.dart';
import '../providers/ai_chat_provider.dart';
import '../providers/growth_progress_provider.dart';
import '../providers/health_data_provider.dart';
import '../providers/pet_profile_provider.dart';
import '../providers/vaccine_reminder_provider.dart';
import '../screens/ai_time_screen.dart';
import '../screens/ai_vet_screen.dart';
import '../screens/pet_games_screen.dart';
import '../screens/pet_profile_screen.dart';
import '../screens/quick_record_screen.dart';
import '../screens/store_screen.dart';
import '../services/ios_speech_input_service.dart';
import 'app_navigation_service.dart';

class _VoiceAgentOutcome {
  final String toolName;
  final String message;

  const _VoiceAgentOutcome({required this.toolName, required this.message});
}

/// Global voice assistant controller that powers the in-app voice assistant UI.
class VoiceAgentController extends ChangeNotifier {
  VoiceAgentController() : _speechService = IosSpeechInputService.instance {
    _resultSubscription = _speechService.results.listen(_handleSpeechResult);
    _errorSubscription = _speechService.errors.listen(_handleSpeechError);
    _listeningSubscription = _speechService.listeningStates.listen((
      bool listening,
    ) {
      if (_isListening != listening) {
        _isListening = listening;
        if (!listening && _statusMessage == AppStrings.tr('Listening...')) {
          _statusMessage = _lastTranscript.trim().isEmpty
              ? AppStrings.tr('Speech paused. Tap Listening to continue.')
              : AppStrings.tr('Recognized your request.');
        }
        notifyListeners();
      }
    });
  }

  final IosSpeechInputService _speechService;

  StreamSubscription<SpeechInputResult>? _resultSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _listeningSubscription;

  bool _isVisible = false;
  bool _isListening = false;
  bool _isExecuting = false;
  String _lastTranscript = '';
  String _statusMessage = 'Open the voice assistant from the Home header.';
  String _resultSummary = '';

  bool get isVisible => _isVisible;
  bool get isListening => _isListening;
  bool get isExecuting => _isExecuting;
  String get greeting => AppStrings.tr('Hi, I am your Vymra voice assistant.');
  String get lastTranscript => _lastTranscript;
  String get statusMessage => _statusMessage;
  String get resultSummary => _resultSummary;
  bool get hasAssistantReply => _resultSummary.trim().isNotEmpty;
  bool get supportsSpeech => _speechService.isSupportedPlatform;

  Future<void> showAssistant({bool autoStartListening = true}) async {
    _isVisible = true;
    _lastTranscript = '';
    _resultSummary = '';
    _statusMessage = AppStrings.tr('Voice assistant ready.');
    notifyListeners();

    if (autoStartListening) {
      await startListening();
    }
  }

  Future<void> dismiss() async {
    if (_isListening) {
      await _speechService.cancelListening();
    }
    _isVisible = false;
    notifyListeners();
  }

  Future<void> startListening() async {
    final BuildContext? navigatorContext =
        AppNavigationService.instance.context;
    final String? localeId = navigatorContext != null
        ? Localizations.localeOf(navigatorContext).toLanguageTag()
        : null;

    if (!_speechService.isSupportedPlatform) {
      _statusMessage = AppStrings.tr(
        'Voice capture is currently available on iPhone and iPad in this build.',
      );
      notifyListeners();
      return;
    }

    final bool supported = await _speechService.isSupported();
    if (!supported) {
      _statusMessage = AppStrings.tr(
        'Speech recognition is unavailable on this device.',
      );
      notifyListeners();
      return;
    }

    final bool granted = await _speechService.requestPermissions();
    if (!granted) {
      _statusMessage = AppStrings.tr(
        'Please allow microphone and speech recognition access first.',
      );
      notifyListeners();
      return;
    }

    _statusMessage = AppStrings.tr('Listening...');
    notifyListeners();

    final bool started = await _speechService.startListening(
      clientId: 'voice_agent_overlay',
      localeId: localeId,
    );
    if (!started) {
      _statusMessage = AppStrings.tr('I could not start listening just now.');
      notifyListeners();
    }
  }

  Future<void> pauseListening() async {
    if (!_isListening) {
      return;
    }

    await _speechService.cancelListening();
    _statusMessage = AppStrings.tr('Voice input paused.');
    notifyListeners();
  }

  Future<void> toggleListening() async {
    if (_isListening) {
      await pauseListening();
      return;
    }
    await startListening();
  }

  Future<void> executeTranscript(String transcript) async {
    final String trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      _statusMessage = AppStrings.tr('I did not catch a request yet.');
      notifyListeners();
      return;
    }

    final BuildContext? context = AppNavigationService.instance.context;
    if (context == null) {
      _statusMessage = AppStrings.tr(
        'The app is not ready for navigation yet.',
      );
      notifyListeners();
      return;
    }

    _lastTranscript = trimmed;
    _isExecuting = true;
    _statusMessage = AppStrings.tr(
      'Running a tool for: {text}',
      params: <String, String>{'text': trimmed},
    );
    notifyListeners();

    try {
      final _VoiceAgentOutcome outcome = await _routeCommand(trimmed, context);
      _resultSummary = outcome.message;
      _statusMessage = AppStrings.tr('Done.');
    } catch (error) {
      _statusMessage = AppStrings.tr('Execution failed.');
      _resultSummary = AppStrings.tr(
        'I ran into a problem while handling that request. Please try a simpler phrasing.',
      );
    } finally {
      _isExecuting = false;
      notifyListeners();
    }
  }

  Future<_VoiceAgentOutcome> _routeCommand(
    String command,
    BuildContext context,
  ) async {
    final String normalized = _normalize(command);

    if (_matchesHelpIntent(normalized)) {
      return _VoiceAgentOutcome(
        toolName: AppStrings.tr('Tool Directory'),
        message: AppStrings.tr(
          'You can ask me to create a pet, open Home Health Growth Settings, open games, open AI vet, log weight water exercise sleep meal, add reminders, or complete the next reminder.',
        ),
      );
    }

    if (_matchesCreatePetIntent(normalized)) {
      return _createOrRefreshPet(command, context, createNew: true);
    }

    if (_matchesCompleteReminderIntent(normalized)) {
      return _completeReminder(context, normalized);
    }

    if (_matchesAddReminderIntent(normalized)) {
      return _addReminder(command, context, normalized);
    }

    if (_matchesHealthRecordIntent(normalized)) {
      return _addHealthRecord(command, context, normalized);
    }

    if (_matchesAiVetIntent(normalized)) {
      return _askAiVet(command, context);
    }

    if (_matchesGamesIntent(normalized)) {
      return _openGames();
    }

    if (_matchesAiTimeIntent(normalized)) {
      return _openAiTime(context);
    }

    if (_matchesQuickRecordIntent(normalized)) {
      return _openQuickRecord(context, normalized);
    }

    if (_matchesPetProfileIntent(normalized)) {
      return _openPetProfile(context);
    }

    if (_matchesStoreIntent(normalized)) {
      return _openStore();
    }

    if (_matchesHomeIntent(normalized)) {
      AppNavigationService.instance.selectMainTab(0);
      return _VoiceAgentOutcome(
        toolName: AppStrings.tr('Open Home'),
        message: AppStrings.tr('Switched to the Home tab.'),
      );
    }

    if (_matchesHealthTabIntent(normalized)) {
      AppNavigationService.instance.selectMainTab(1);
      return _VoiceAgentOutcome(
        toolName: AppStrings.tr('Open Health'),
        message: AppStrings.tr('Switched to the Health tab.'),
      );
    }

    if (_matchesGrowthIntent(normalized)) {
      AppNavigationService.instance.selectMainTab(2);
      return _VoiceAgentOutcome(
        toolName: AppStrings.tr('Open Growth'),
        message: AppStrings.tr('Switched to the Growth tab.'),
      );
    }

    if (_matchesSettingsIntent(normalized)) {
      AppNavigationService.instance.selectMainTab(3);
      return _VoiceAgentOutcome(
        toolName: AppStrings.tr('Open Settings'),
        message: AppStrings.tr('Switched to the Settings tab.'),
      );
    }

    return _VoiceAgentOutcome(
      toolName: AppStrings.tr('No Match'),
      message: AppStrings.tr('voice_agent_try_commands_examples'),
    );
  }

  Future<_VoiceAgentOutcome> _createOrRefreshPet(
    String command,
    BuildContext context, {
    bool createNew = false,
  }) async {
    final PetProfileProvider petProvider = context.read<PetProfileProvider>();
    await petProvider.loadDefaultProfile();

    final String name = _extractPetName(command) ?? AppStrings.tr('Buddy');
    final String species = _detectSpecies(command);
    final String breed = _extractBreed(command, species);
    final double weight = _extractNumber(command) ?? 3.5;
    final String gender = _detectGender(command);

    if (!createNew && petProvider.hasProfile) {
      final PetProfile current = petProvider.profile!;
      await petProvider.saveProfile(
        current.copyWith(
          name: name,
          species: species,
          breed: breed,
          gender: gender,
          currentWeight: weight,
          targetWeight: weight,
          updatedAt: DateTime.now(),
        ),
      );
      return _VoiceAgentOutcome(
        toolName: AppStrings.tr('Refresh Pet Profile'),
        message: AppStrings.tr(
          'Updated the active pet profile to {name}, a {species}.',
          params: <String, String>{'name': name, 'species': species},
        ),
      );
    }

    await petProvider.createDefaultProfile(
      name: name,
      species: species,
      breed: breed,
      birthDate: DateTime.now().subtract(const Duration(days: 180)),
      weight: weight,
      gender: gender,
    );

    return _VoiceAgentOutcome(
      toolName: AppStrings.tr('Create Pet Profile'),
      message: AppStrings.tr(
        'Created a new pet profile for {name} the {species}.',
        params: <String, String>{'name': name, 'species': species},
      ),
    );
  }

  Future<_VoiceAgentOutcome> _addHealthRecord(
    String command,
    BuildContext context,
    String normalized,
  ) async {
    final HealthDataProvider healthProvider = context
        .read<HealthDataProvider>();
    final GrowthProgressProvider growthProvider = context
        .read<GrowthProgressProvider>();
    final AchievementProvider achievementProvider = context
        .read<AchievementProvider>();
    final PetProfileProvider petProvider = context.read<PetProfileProvider>();
    final PetProfile profile = await _ensurePet(context);

    final String recordType = _detectRecordType(normalized);
    final double? value = _extractNumber(command);
    if (value == null || value <= 0) {
      return const _VoiceAgentOutcome(
        toolName: 'Record Health',
        message:
            'I recognized the health tool but missed the number. Try saying "记录体重 4.2 公斤" or "记录喝水 280 毫升".',
      );
    }

    await healthProvider.loadRecords(profile.petId);
    await growthProvider.loadProgress(profile.petId);
    await achievementProvider.loadAchievements(profile.petId);

    final List<HealthRecord> sameTypeRecords = healthProvider.getRecordsByType(
      recordType,
    );
    final HealthRecord? previousRecord = sameTypeRecords.isEmpty
        ? null
        : sameTypeRecords.first;

    final Map<String, String> units = <String, String>{
      'weight': 'kg',
      'water': 'ml',
      'exercise': 'min',
      'sleep': 'hours',
      'meal': 'kcal',
    };

    final HealthRecord record = HealthRecord(
      recordId: 'record_${DateTime.now().millisecondsSinceEpoch}',
      petId: profile.petId,
      recordType: recordType,
      value: value,
      unit: units[recordType] ?? 'unit',
      note: command.trim(),
      recordedAt: DateTime.now(),
    );

    await healthProvider.addRecord(record);
    await achievementProvider.evaluateRecordSaved(
      record: record,
      previousRecord: previousRecord,
      totalRecordCount: healthProvider.records.length,
    );

    String growthNote = '';
    if (recordType == 'exercise') {
      final result = await growthProvider.awardExerciseXp();
      if (result != null) {
        growthNote = AppStrings.tr(
          ' Earned {xp} XP.',
          params: <String, String>{'xp': '${result.xpDelta}'},
        );
      }
    } else {
      final result = await growthProvider.awardMealXp();
      if (result != null) {
        growthNote = AppStrings.tr(
          ' Earned {xp} XP.',
          params: <String, String>{'xp': '${result.xpDelta}'},
        );
      }
    }

    if (recordType == 'weight') {
      await petProvider.saveProfile(
        profile.copyWith(currentWeight: value, updatedAt: DateTime.now()),
      );
    }

    AppNavigationService.instance.selectMainTab(1);
    return _VoiceAgentOutcome(
      toolName: 'Record Health',
      message: AppStrings.tr(
        'Saved a {recordType} entry for {value} {unit}.{growthNote}',
        params: <String, String>{
          'recordType': recordType == 'meal'
              ? AppStrings.tr('meal intake')
              : recordType,
          'value': value.toStringAsFixed(1),
          'unit': record.unit,
          'growthNote': growthNote.trimLeft(),
        },
      ),
    );
  }

  Future<_VoiceAgentOutcome> _addReminder(
    String command,
    BuildContext context,
    String normalized,
  ) async {
    final VaccineReminderProvider reminderProvider = context
        .read<VaccineReminderProvider>();
    final PetProfile profile = await _ensurePet(context);
    await reminderProvider.loadReminders(profile.petId);

    final String type = _detectReminderType(normalized);
    final int intervalDays = _extractReminderInterval(command, type);
    final String name = _extractReminderName(command, type);
    final DateTime now = DateTime.now();

    final VaccineReminder reminder = VaccineReminder(
      reminderId: 'reminder_${now.millisecondsSinceEpoch}',
      petId: profile.petId,
      reminderType: type,
      name: name,
      lastDate: now,
      nextDate: now.add(Duration(days: intervalDays)),
      intervalDays: intervalDays,
      notes: command.trim(),
      isActive: true,
      isCompleted: false,
    );

    await reminderProvider.addReminder(reminder);
    AppNavigationService.instance.selectMainTab(1);

    return _VoiceAgentOutcome(
      toolName: AppStrings.tr('Add Reminder'),
      message: AppStrings.tr(
        'Added "{name}" with a {days}-day interval. The next reminder is scheduled automatically.',
        params: <String, String>{'name': name, 'days': '$intervalDays'},
      ),
    );
  }

  Future<_VoiceAgentOutcome> _completeReminder(
    BuildContext context,
    String normalized,
  ) async {
    final VaccineReminderProvider reminderProvider = context
        .read<VaccineReminderProvider>();
    final AchievementProvider achievementProvider = context
        .read<AchievementProvider>();
    final PetProfile profile = await _ensurePet(context);
    await reminderProvider.loadReminders(profile.petId);
    await achievementProvider.loadAchievements(profile.petId);

    final String targetType = _detectReminderType(normalized);
    final VaccineReminder? reminder = reminderProvider.activeReminders
        .cast<VaccineReminder?>()
        .firstWhere(
          (VaccineReminder? item) =>
              item != null &&
              (targetType == 'vaccine' || item.reminderType == targetType),
          orElse: () => reminderProvider.activeReminders.isEmpty
              ? null
              : reminderProvider.activeReminders.first,
        );

    if (reminder == null) {
      return _VoiceAgentOutcome(
        toolName: AppStrings.tr('Complete Reminder'),
        message: AppStrings.tr('There is no active reminder to complete yet.'),
      );
    }

    await reminderProvider.markCompleted(reminder.reminderId);
    await achievementProvider.evaluateReminderCompleted(
      reminderName: reminder.name,
    );

    return _VoiceAgentOutcome(
      toolName: AppStrings.tr('Complete Reminder'),
      message: AppStrings.tr(
        'Marked "{name}" as handled and rolled it forward to the next cycle.',
        params: <String, String>{'name': reminder.name},
      ),
    );
  }

  Future<_VoiceAgentOutcome> _askAiVet(
    String command,
    BuildContext context,
  ) async {
    final AiChatProvider aiProvider = context.read<AiChatProvider>();
    final PetProfile profile = await _ensurePet(context);

    final String question = _stripAiVetPrefix(command);
    if (question.isEmpty) {
      await AppNavigationService.instance.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AiVetScreen(petId: profile.petId),
        ),
      );
      return _VoiceAgentOutcome(
        toolName: AppStrings.tr('Open AI Vet'),
        message: AppStrings.tr('Opened the AI vet assistant.'),
      );
    }

    final AiChatRecord? answer = await aiProvider.askQuestionAndGetAnswer(
      profile.petId,
      question,
    );
    await AppNavigationService.instance.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AiVetScreen(petId: profile.petId),
      ),
    );

    return _VoiceAgentOutcome(
      toolName: AppStrings.tr('AI Vet'),
      message:
          answer?.answer ??
          AppStrings.tr('Asked the AI vet and opened the chat history.'),
    );
  }

  Future<_VoiceAgentOutcome> _openGames() async {
    AppNavigationService.instance.selectMainTab(0);
    await AppNavigationService.instance.push<void>(
      MaterialPageRoute<void>(builder: (_) => const PetGamesScreen()),
    );
    return _VoiceAgentOutcome(
      toolName: AppStrings.tr('Open Games'),
      message: AppStrings.tr('Opened the pet playroom.'),
    );
  }

  Future<_VoiceAgentOutcome> _openAiTime(BuildContext context) async {
    final PetProfile profile = await _ensurePet(context);
    await AppNavigationService.instance.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AiTimeScreen(petId: profile.petId),
      ),
    );
    return _VoiceAgentOutcome(
      toolName: AppStrings.tr('Open AI Studio'),
      message: AppStrings.tr('Opened the AI image studio.'),
    );
  }

  Future<_VoiceAgentOutcome> _openQuickRecord(
    BuildContext context,
    String normalized,
  ) async {
    final String recordType = _detectRecordType(normalized);
    final PetProfile profile = await _ensurePet(context);
    await AppNavigationService.instance.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => QuickRecordScreen(
          petId: profile.petId,
          initialRecordType: recordType,
        ),
      ),
    );
    return _VoiceAgentOutcome(
      toolName: AppStrings.tr('Open Quick Record'),
      message: AppStrings.tr(
        'Opened quick record for {recordType}.',
        params: <String, String>{'recordType': recordType},
      ),
    );
  }

  Future<_VoiceAgentOutcome> _openPetProfile(BuildContext context) async {
    await _ensurePet(context);
    await AppNavigationService.instance.push<void>(
      MaterialPageRoute<void>(builder: (_) => const PetProfileScreen()),
    );
    return _VoiceAgentOutcome(
      toolName: AppStrings.tr('Open Pet Profile'),
      message: AppStrings.tr('Opened the pet profile screen.'),
    );
  }

  Future<_VoiceAgentOutcome> _openStore() async {
    await AppNavigationService.instance.push<void>(
      MaterialPageRoute<void>(builder: (_) => const StoreScreen()),
    );
    return _VoiceAgentOutcome(
      toolName: AppStrings.tr('Open Store'),
      message: AppStrings.tr('Opened the PawCoin store.'),
    );
  }

  Future<PetProfile> _ensurePet(BuildContext context) async {
    final PetProfileProvider petProvider = context.read<PetProfileProvider>();
    if (!petProvider.hasProfile) {
      await petProvider.loadDefaultProfile();
    }
    if (!petProvider.hasProfile) {
      await petProvider.createDefaultProfile(
        name: AppStrings.tr('Buddy'),
        species: AppStrings.tr('Cat'),
        breed: AppStrings.tr('Mixed Breed'),
        birthDate: DateTime.now().subtract(const Duration(days: 180)),
        weight: 3.5,
        gender: AppStrings.tr('Male'),
      );
      await petProvider.loadDefaultProfile();
    }
    return petProvider.profile!;
  }

  void _handleSpeechResult(SpeechInputResult result) {
    _lastTranscript = result.text.trim();
    notifyListeners();

    if (result.isFinal && !_isExecuting && _lastTranscript.isNotEmpty) {
      executeTranscript(_lastTranscript);
    }
  }

  void _handleSpeechError(String message) {
    _statusMessage = message;
    _isListening = false;
    notifyListeners();
  }

  String _normalize(String input) {
    String normalized = input.toLowerCase().trim();
    const Map<String, String> latinFolds = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'æ': 'ae',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'œ': 'oe',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
    };
    latinFolds.forEach((String source, String target) {
      normalized = normalized.replaceAll(source, target);
    });
    return normalized.replaceAll(RegExp(r"""[\s,.;:!?，。；：！？'"()\-_/]+"""), '');
  }

  bool _containsAny(String input, List<String> keywords) {
    return keywords.any(input.contains);
  }

  bool _matchesHelpIntent(String normalized) {
    return _containsAny(normalized, <String>[
      '你能做什么',
      '帮助',
      '能做啥',
      'help',
      'whatcanyoudo',
      'ayuda',
      'aide',
      'مساعدة',
      'ساعدني',
      'मदद',
    ]);
  }

  bool _matchesCreatePetIntent(String normalized) {
    final bool hasPetTopic = _containsAny(normalized, <String>[
      '宠物',
      'pet',
      'mascota',
      'animal',
      'mascotte',
      'حيوان',
      'حيواناليف',
      'पालतू',
    ]);
    final bool hasVerb = _containsAny(normalized, <String>[
      '新建',
      '创建',
      '添加',
      '新增',
      'create',
      'add',
      'new',
      'crear',
      'agregar',
      'anadir',
      'creer',
      'ajouter',
      'nouveau',
      'انشاء',
      'اضافة',
      'جديد',
      'बनाओ',
      'जोड़ो',
      'नया',
    ]);
    return (hasPetTopic && hasVerb) ||
        _containsAny(normalized, <String>[
          'createpet',
          'addpet',
          'newpet',
          'crearmascota',
          'agregarmascota',
          'anadirmascota',
          'nuevamascota',
          'creeranimal',
          'ajouteranimal',
          'nouvelanimal',
          'nouveaumascotte',
          'انشاءحيوان',
          'اضافةحيوان',
          'حيواناليفجديد',
          'पालतूबनाओ',
          'पालतूजोड़ो',
          'नयापालतू',
        ]);
  }

  bool _matchesCompleteReminderIntent(String normalized) {
    return _containsAny(normalized, <String>[
      '完成提醒',
      '处理提醒',
      '完成疫苗',
      '完成驱虫',
      'completereminder',
      'finishreminder',
      'markreminderdone',
      'completerecordatorio',
      'finalizarrecordatorio',
      'completarrappel',
      'terminerrappel',
      'اكمالتذكير',
      'انهاءتذكير',
      'रिमाइंडरपूराकरें',
      'रिमाइंडरसमाप्तकरें',
    ]);
  }

  bool _matchesAddReminderIntent(String normalized) {
    final bool hasTopic = _containsAny(normalized, <String>[
      '提醒',
      '疫苗',
      '驱虫',
      '体检',
      'reminder',
      'vaccine',
      'deworm',
      'checkup',
      'recordatorio',
      'vacuna',
      'desparasit',
      'chequeo',
      'rappel',
      'vaccin',
      'vermif',
      'controle',
      'تذكير',
      'لقاح',
      'تطعيم',
      'فحص',
      'रिमाइंडर',
      'वैक्सीन',
      'टीका',
      'चेकअप',
    ]);
    final bool hasVerb = _containsAny(normalized, <String>[
      '添加',
      '新增',
      '创建',
      '设置',
      'add',
      'create',
      'set',
      'agregar',
      'crear',
      'configurar',
      'ajouter',
      'creer',
      'definir',
      'اضافة',
      'انشاء',
      'تعيين',
      'जोड़ो',
      'बनाओ',
      'सेट',
    ]);
    return hasTopic && hasVerb;
  }

  bool _matchesHealthRecordIntent(String normalized) {
    final bool hasVerb = _containsAny(normalized, <String>[
      '记录',
      '新增',
      'log',
      'record',
      'registrar',
      'anotar',
      'enregistrer',
      'noter',
      'سجل',
      'اضف',
      'रिकॉर्ड',
      'लॉग',
    ]);
    final bool hasType = _containsAny(normalized, <String>[
      '体重',
      '喝水',
      '饮水',
      '运动',
      '睡眠',
      '进食',
      '喂食',
      'weight',
      'water',
      'exercise',
      'sleep',
      'meal',
      'peso',
      'agua',
      'ejercicio',
      'sueno',
      'comida',
      'poids',
      'eau',
      'exercice',
      'sommeil',
      'repas',
      'وزن',
      'ماء',
      'تمرين',
      'نوم',
      'وجبة',
      'वजन',
      'पानी',
      'व्यायाम',
      'नींद',
      'खाना',
    ]);
    return hasVerb && hasType;
  }

  bool _matchesAiVetIntent(String normalized) {
    return _containsAny(normalized, <String>[
      '问医生',
      '问问医生',
      'ai医生',
      'ai问诊',
      '兽医',
      'aivet',
      'askthevet',
      'vet',
      'veterinario',
      'preguntaalveterinario',
      'veterinaire',
      'demandeauveterinaire',
      'طبيببيطري',
      'اسالالطبيب',
      'पशुचिकित्सक',
      'डॉक्टरसेपूछो',
    ]);
  }

  bool _matchesGamesIntent(String normalized) {
    return _containsAny(normalized, <String>[
      '游戏',
      'playroom',
      'petgames',
      'games',
      'juegos',
      'jeux',
      'العاب',
      'गेम',
    ]);
  }

  bool _matchesAiTimeIntent(String normalized) {
    return _containsAny(normalized, <String>[
      'ai创作',
      '海报',
      '图片创作',
      'aistudio',
      'aiart',
      'imagestudio',
      'estudioai',
      'arteai',
      'studioia',
      'artia',
      'استوديوالذكاء',
      'انشاءصور',
      'एआईस्टूडियो',
      'एआईआर्ट',
    ]);
  }

  bool _matchesQuickRecordIntent(String normalized) {
    return _containsAny(normalized, <String>[
      '快速记录',
      'recordscreen',
      'quickrecord',
      'registrorapido',
      'enregistrementrapide',
      'تسجيلسريع',
      'त्वरितरिकॉर्ड',
    ]);
  }

  bool _matchesPetProfileIntent(String normalized) {
    return _containsAny(normalized, <String>[
      '宠物档案',
      '宠物资料',
      'petprofile',
      'profile',
      'perfildemascota',
      'profilanimal',
      'ملفالحيوان',
      'पालतूप्रोफाइल',
    ]);
  }

  bool _matchesStoreIntent(String normalized) {
    return _containsAny(normalized, <String>[
      '商店',
      'store',
      'pawcoin',
      'tienda',
      'boutique',
      'متجر',
      'स्टोर',
    ]);
  }

  bool _matchesHomeIntent(String normalized) {
    return _containsAny(normalized, <String>[
      '首页',
      'home',
      'inicio',
      'accueil',
      'الرئيسية',
      'होम',
    ]);
  }

  bool _matchesHealthTabIntent(String normalized) {
    return _containsAny(normalized, <String>[
      '健康',
      'health',
      'salud',
      'sante',
      'الصحة',
      'स्वास्थ्य',
    ]);
  }

  bool _matchesGrowthIntent(String normalized) {
    return _containsAny(normalized, <String>[
      '成长',
      'growth',
      'crecimiento',
      'croissance',
      'النمو',
      'विकास',
    ]);
  }

  bool _matchesSettingsIntent(String normalized) {
    return _containsAny(normalized, <String>[
      '设置',
      'settings',
      'configuracion',
      'parametres',
      'الإعدادات',
      'सेटिंग्स',
    ]);
  }

  String _detectSpecies(String input) {
    final String normalized = _normalize(input);
    if (_containsAny(normalized, <String>[
      '狗',
      'dog',
      'puppy',
      'perro',
      'chien',
      'كلب',
      'कुत्ता',
    ])) {
      return AppStrings.tr('Dog');
    }
    if (_containsAny(normalized, <String>[
      '兔',
      'rabbit',
      'conejo',
      'lapin',
      'أرنب',
      'खरगोश',
    ])) {
      return AppStrings.tr('Rabbit');
    }
    if (_containsAny(normalized, <String>[
      '仓鼠',
      'hamster',
      'hamster',
      'hamster',
      'هامستر',
      'हैम्स्टर',
    ])) {
      return AppStrings.tr('Hamster');
    }
    return AppStrings.tr('Cat');
  }

  String _extractBreed(String input, String species) {
    final List<RegExp> patterns = <RegExp>[
      RegExp(r'(品种|breed)(是|叫|is)?\s*([^，。,.\n]+)', caseSensitive: false),
      RegExp(r'(raza|race)\s*(es|is)?\s*([^,.\n]+)', caseSensitive: false),
      RegExp(r'(السلالة)\s*(هي)?\s*([^،。,.\n]+)'),
      RegExp(r'(नस्ल)\s*(है)?\s*([^,.\n]+)'),
    ];

    for (final RegExp pattern in patterns) {
      final RegExpMatch? match = pattern.firstMatch(input);
      if (match != null) {
        return match.group(match.groupCount)!.trim();
      }
    }
    return species == AppStrings.tr('Dog')
        ? AppStrings.tr('Mixed Breed Dog')
        : AppStrings.tr('Mixed Breed');
  }

  String _detectGender(String input) {
    final String normalized = _normalize(input);
    if (_containsAny(normalized, <String>[
      '母',
      'female',
      'girl',
      'hembra',
      'femelle',
      'انثى',
      'मादा',
    ])) {
      return AppStrings.tr('Female');
    }
    return AppStrings.tr('Male');
  }

  String? _extractPetName(String input) {
    final List<RegExp> patterns = <RegExp>[
      RegExp(r'(叫|名字是|名叫)\s*([A-Za-z0-9\u4e00-\u9fa5_-]+)'),
      RegExp(
        r'(pet\s*name|name|named|called)\s*(is)?\s*([A-Za-z0-9\u4e00-\u9fa5_-]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'(nombre|llamado|llamada)\s*(es)?\s*([A-Za-z0-9\u4e00-\u9fa5_-]+)',
        caseSensitive: false,
      ),
      RegExp(
        r"""(nom|nomme|nommee|nommé|nommée|s'appelle)\s*(est)?\s*([A-Za-z0-9\u4e00-\u9fa5_-]+)""",
        caseSensitive: false,
      ),
      RegExp(r'(اسمه|اسمها|اسم)\s*([A-Za-z0-9\u0600-\u06FF_-]+)'),
      RegExp(r'(नाम|नामहै)\s*([A-Za-z0-9\u0900-\u097F_-]+)'),
    ];

    for (final RegExp pattern in patterns) {
      final RegExpMatch? match = pattern.firstMatch(input);
      if (match != null) {
        return match.group(match.groupCount)!.trim();
      }
    }
    return null;
  }

  double? _extractNumber(String input) {
    final RegExpMatch? match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(input);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(1)!);
  }

  String _detectRecordType(String normalized) {
    if (_containsAny(normalized, <String>[
      '体重',
      'weight',
      'peso',
      'poids',
      'وزن',
      'वजन',
    ])) {
      return 'weight';
    }
    if (_containsAny(normalized, <String>[
      '喝水',
      '饮水',
      'water',
      'agua',
      'eau',
      'ماء',
      'पानी',
    ])) {
      return 'water';
    }
    if (_containsAny(normalized, <String>[
      '运动',
      'exercise',
      'ejercicio',
      'exercice',
      'تمرين',
      'व्यायाम',
    ])) {
      return 'exercise';
    }
    if (_containsAny(normalized, <String>[
      '睡眠',
      'sleep',
      'sueno',
      'sommeil',
      'نوم',
      'नींद',
    ])) {
      return 'sleep';
    }
    return 'meal';
  }

  String _detectReminderType(String normalized) {
    if (_containsAny(normalized, <String>[
      '体检',
      'checkup',
      'chequeo',
      'controle',
      'فحص',
      'चेकअप',
    ])) {
      return 'checkup';
    }
    if (_containsAny(normalized, <String>[
      '外驱',
      'external',
      '体外',
      'externo',
      'externe',
      'خارجي',
      'बाहरी',
    ])) {
      return 'deworm-external';
    }
    if (_containsAny(normalized, <String>[
      '内驱',
      'internal',
      '体内',
      'interno',
      'interne',
      'داخلي',
      'आंतरिक',
    ])) {
      return 'deworm-internal';
    }
    return 'vaccine';
  }

  int _extractReminderInterval(String input, String type) {
    final RegExpMatch? dayMatch = RegExp(
      r'(\d+)\s*(天|day|days|dia|dias|jour|jours|يوم|दिन)',
      caseSensitive: false,
    ).firstMatch(input);
    if (dayMatch != null) {
      return int.parse(dayMatch.group(1)!);
    }

    final RegExpMatch? monthMatch = RegExp(
      r'(\d+)\s*(个月|month|months|mes|meses|mois|شهر|महीना|महीने)',
      caseSensitive: false,
    ).firstMatch(input);
    if (monthMatch != null) {
      return int.parse(monthMatch.group(1)!) * 30;
    }

    final RegExpMatch? yearMatch = RegExp(
      r'(\d+)\s*(年|year|years|ano|anos|an|ans|سنة|عام|साल)',
      caseSensitive: false,
    ).firstMatch(input);
    if (yearMatch != null) {
      return int.parse(yearMatch.group(1)!) * 365;
    }

    switch (type) {
      case 'checkup':
        return 180;
      case 'deworm-external':
        return 30;
      case 'deworm-internal':
        return 90;
      default:
        return 365;
    }
  }

  String _extractReminderName(String input, String type) {
    final List<RegExp> patterns = <RegExp>[
      RegExp(r'(提醒|项目|名称)(是|叫)?\s*([^，。,.\n]+)'),
      RegExp(r'(name|title)\s*(is)?\s*([^,.\n]+)', caseSensitive: false),
      RegExp(r'(nombre)\s*(es)?\s*([^,.\n]+)', caseSensitive: false),
      RegExp(r'(nom)\s*(est)?\s*([^,.\n]+)', caseSensitive: false),
      RegExp(r'(اسم)\s*([^،。,.\n]+)'),
      RegExp(r'(नाम)\s*([^,.\n]+)'),
    ];
    for (final RegExp pattern in patterns) {
      final RegExpMatch? match = pattern.firstMatch(input);
      if (match != null) {
        return match.group(match.groupCount)!.trim();
      }
    }

    switch (type) {
      case 'checkup':
        return AppStrings.tr('Health Checkup');
      case 'deworm-external':
        return AppStrings.tr('External Deworming');
      case 'deworm-internal':
        return AppStrings.tr('Internal Deworming');
      default:
        return AppStrings.tr('Vaccination');
    }
  }

  String _stripAiVetPrefix(String command) {
    final List<RegExp> prefixes = <RegExp>[
      RegExp(r'^(问医生|问问医生|ai医生|ai问诊|兽医)\s*'),
      RegExp(r'^(ask\s*(the)?\s*vet|ai\s*vet|vet)\s*', caseSensitive: false),
      RegExp(
        r'^(pregunta\s*al\s*veterinario|veterinario)\s*',
        caseSensitive: false,
      ),
      RegExp(
        r'^(demande\s*au\s*veterinaire|veterinaire)\s*',
        caseSensitive: false,
      ),
      RegExp(r'^(اسال\s*الطبيب|طبيب\s*بيطري)\s*'),
      RegExp(r'^(डॉक्टर\s*से\s*पूछो|पशुचिकित्सक)\s*'),
    ];
    String question = command.trim();
    for (final RegExp prefix in prefixes) {
      question = question.replaceFirst(prefix, '').trim();
    }
    return question;
  }

  @override
  void dispose() {
    _resultSubscription?.cancel();
    _errorSubscription?.cancel();
    _listeningSubscription?.cancel();
    super.dispose();
  }
}
