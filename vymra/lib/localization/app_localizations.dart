import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Loads localized string resources and exposes lookup helpers.
class AppLocalizations {
  AppLocalizations._(this.locale, this._localizedValues);

  final Locale locale;
  final Map<String, String> _localizedValues;

  Map<String, String> get rawValues =>
      Map<String, String>.unmodifiable(_localizedValues);

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('es'),
    Locale('fr'),
    Locale('ar'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final AppLocalizations? localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'AppLocalizations not found in context.');
    return localizations!;
  }

  static Locale resolveSupportedLocale(Locale? locale) {
    if (locale == null) {
      return supportedLocales.first;
    }

    for (final Locale supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return supportedLocale;
      }
    }

    return supportedLocales.first;
  }

  static Future<AppLocalizations> load(Locale locale) async {
    final Locale resolvedLocale = resolveSupportedLocale(locale);
    final Map<String, dynamic> baseValues =
        json.decode(await rootBundle.loadString('assets/i18n/en.json'))
            as Map<String, dynamic>;
    final Map<String, dynamic> localeValues =
        resolvedLocale.languageCode == 'en'
        ? baseValues
        : json.decode(
                await rootBundle.loadString(
                  'assets/i18n/${resolvedLocale.languageCode}.json',
                ),
              )
              as Map<String, dynamic>;
    final Map<String, dynamic> decoded = <String, dynamic>{
      ...baseValues,
      ...localeValues,
    };

    return AppLocalizations._(
      resolvedLocale,
      decoded.map(
        (String key, dynamic value) => MapEntry(key, value.toString()),
      ),
    );
  }

  String tr(String key, {Map<String, String>? params}) {
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

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (Locale supportedLocale) =>
          supportedLocale.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return AppLocalizations.load(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}

extension AppLocalizationsContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String tr(String key, {Map<String, String>? params}) {
    return l10n.tr(key, params: params);
  }
}
