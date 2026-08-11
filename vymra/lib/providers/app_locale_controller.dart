import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_localizations.dart';
import '../localization/app_strings.dart';

/// Stores and updates the app-wide locale preference.
class AppLocaleController extends ChangeNotifier {
  AppLocaleController._(this._locale);

  static const String _preferenceKey = 'vymra_app_locale';

  Locale _locale;

  Locale get locale => _locale;

  static Future<AppLocaleController> create({Locale? deviceLocale}) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? savedLanguageCode = preferences.getString(_preferenceKey);
    final Locale locale = savedLanguageCode == null
        ? AppLocalizations.resolveSupportedLocale(
            deviceLocale ?? WidgetsBinding.instance.platformDispatcher.locale,
          )
        : AppLocalizations.resolveSupportedLocale(Locale(savedLanguageCode));
    await AppStrings.setLocale(locale);

    return AppLocaleController._(locale);
  }

  Future<void> setLocale(Locale locale) async {
    final Locale resolvedLocale = AppLocalizations.resolveSupportedLocale(
      locale,
    );
    if (_locale == resolvedLocale) {
      return;
    }

    _locale = resolvedLocale;
    await AppStrings.setLocale(resolvedLocale);
    notifyListeners();

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, resolvedLocale.languageCode);
  }
}
