import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'agent/app_navigation_service.dart';
import 'agent/voice_agent_controller.dart';
import 'localization/app_localizations.dart';
import 'models/models.dart';
import 'providers/providers.dart';
import 'repositories/repositories.dart';
import 'services/services.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/voice_agent_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  _registerHiveAdapters();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Ensure a stable secure-storage device ID exists before app startup.
  await DeviceIdService().getOrCreateDeviceId();

  // Initialize repositories
  final petProfileRepo = HivePetProfileRepository();
  final healthRecordRepo = HiveHealthRecordRepository();
  final mealAnalysisRepo = HiveMealAnalysisRepository();
  final growthProgressRepo = HiveGrowthProgressRepository();
  final achievementRepo = LocalAchievementRepository();
  final vaccineReminderRepo = HiveVaccineReminderRepository();
  final aiChatRepo = HiveAiChatRepository();
  final userAccountRepo = SecureStorageUserRepository();
  final purchaseRecordRepo = HivePurchaseRecordRepository();

  // Initialize services
  final authService = AuthService(
    userAccountRepo,
    purchaseRepository: purchaseRecordRepo,
  );
  final iapService = IapService(
    purchaseRecordRepo,
    IapVerificationService(),
    IapAccountService(),
  );
  final purchaseProvider = PurchaseProvider(purchaseRecordRepo, iapService);
  final growthService = GrowthService();
  final localeController = await AppLocaleController.create();

  // Check login status
  final isLoggedIn = await authService.checkAutoLogin();
  final currentUser = isLoggedIn ? await authService.getCurrentUser() : null;

  final logoService = GlobalLogoService();
  try {
    await logoService.fetchLogo();
  } catch (_) {
    // Best-effort: do not block startup on logo fetch failures
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authService,
            initialUser: currentUser,
            initialLoggedIn: isLoggedIn && currentUser != null,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PetProfileProvider(petProfileRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => HealthDataProvider(healthRecordRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => MealAnalysisProvider(mealAnalysisRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => GrowthProgressProvider(
            growthProgressRepo,
            growthService,
            purchaseRecordRepo,
            userAccountRepo,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AchievementProvider(achievementRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => VaccineReminderProvider(vaccineReminderRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => AiChatProvider(aiChatRepo, AiVetService()),
        ),
        ChangeNotifierProvider(
          create: (_) {
            unawaited(purchaseProvider.initialize());
            return purchaseProvider;
          },
          lazy: false,
        ),
        ChangeNotifierProvider(create: (_) => VoiceAgentController()),
        ChangeNotifierProvider<AppLocaleController>.value(
          value: localeController,
        ),
        ChangeNotifierProvider(create: (_) => logoService),
      ],
      child: VymraApp(isLoggedIn: isLoggedIn && currentUser != null),
    ),
  );

  WidgetsBinding.instance.addObserver(logoService);
}

void _registerHiveAdapters() {
  Hive.registerAdapter(PetMediaAssetAdapter());
  Hive.registerAdapter(PetProfileAdapter());
  Hive.registerAdapter(HealthRecordAdapter());
  Hive.registerAdapter(MealAnalysisAdapter());
  Hive.registerAdapter(GrowthProgressAdapter());
  Hive.registerAdapter(VaccineReminderAdapter());
  Hive.registerAdapter(AiChatRecordAdapter());
  Hive.registerAdapter(UserAccountAdapter());
  Hive.registerAdapter(PurchaseRecordAdapter());
}

/// Root app widget.
class VymraApp extends StatelessWidget {
  final bool isLoggedIn;

  const VymraApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final AppLocaleController localeController = context
        .watch<AppLocaleController>();

    return MaterialApp(
      title: 'Vymra',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigationService.instance.navigatorKey,
      theme: AppTheme.lightTheme,
      locale: localeController.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) {
        return VoiceAgentOverlay(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: SplashScreen(isLoggedIn: isLoggedIn),
    );
  }
}
