import 'package:flutter/material.dart';

import 'app_localizations.dart';

/// Global string lookup for layers that do not have a BuildContext.
class AppStrings {
  AppStrings._();

  static Locale _locale = const Locale('en');
  static Map<String, String> _localizedValues = <String, String>{};

  static Locale get locale => _locale;

  static Future<void> setLocale(Locale locale) async {
    final AppLocalizations localizations = await AppLocalizations.load(locale);
    _locale = localizations.locale;
    _localizedValues = Map<String, String>.from(localizations.rawValues);
  }

  static String tr(String key, {Map<String, String>? params}) {
    String value = _localizedValues[key] ?? key;
    if (params == null || params.isEmpty) {
      return value;
    }

    params.forEach((String placeholder, String replacement) {
      value = value.replaceAll('{$placeholder}', replacement);
    });
    return value;
  }
}
