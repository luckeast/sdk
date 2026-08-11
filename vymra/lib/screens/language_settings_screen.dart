import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../providers/app_locale_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_widget.dart';

class LanguageOption {
  const LanguageOption({
    required this.locale,
    required this.englishName,
    required this.nativeName,
  });

  final Locale locale;
  final String englishName;
  final String nativeName;
}

/// Language picker for switching the app locale.
class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  final List<LanguageOption> _options = const <LanguageOption>[
    LanguageOption(
      locale: Locale('en'),
      englishName: 'English',
      nativeName: 'English',
    ),
    LanguageOption(
      locale: Locale('hi'),
      englishName: 'Hindi',
      nativeName: 'हिन्दी',
    ),
    LanguageOption(
      locale: Locale('es'),
      englishName: 'Spanish',
      nativeName: 'Español',
    ),
    LanguageOption(
      locale: Locale('fr'),
      englishName: 'French',
      nativeName: 'Français',
    ),
    LanguageOption(
      locale: Locale('ar'),
      englishName: 'Arabic',
      nativeName: 'العربية',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocaleController localeController = context.watch<AppLocaleController>();
    final Locale activeLocale = localeController.locale;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Language')),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (BuildContext context, int index) {
          final LanguageOption option = _options[index];
          final bool isSelected =
              option.locale.languageCode == activeLocale.languageCode;

          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: isSelected
                  ? null
                  : () => _handleLanguageSelection(context, option),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.sketchInk.withValues(alpha: 0.08),
                    width: isSelected ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            option.nativeName,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.sketchInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option.englishName,
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.chevron_right_rounded,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textDisabled,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemCount: _options.length,
      ),
    );
  }

  Future<void> _handleLanguageSelection(
    BuildContext context,
    LanguageOption option,
  ) async {
    final NavigatorState navigator = Navigator.of(context);
    final AppLocaleController localeController = context
        .read<AppLocaleController>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: <Widget>[
                const LoadingWidget(size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    context.tr('Switching language...'),
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await localeController.setLocale(option.locale);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    if (navigator.mounted) {
      navigator.pop();
      navigator.pop();
    }
  }
}
