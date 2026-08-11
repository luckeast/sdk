import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';

/// Manages user consent for sending images to third-party AI services (Doubao).
class AiConsentService {
  static const String _consentKey = 'vymra_ai_third_party_consent';

  /// Returns whether the user has previously consented.
  Future<bool> hasConsent() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  /// Persists the user's consent choice.
  Future<void> setConsent(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, value);
  }

  /// Shows the consent dialog and returns `true` if the user agreed.
  Future<bool> requestConsent(BuildContext context) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          dialogContext.tr('Third-Party AI Consent'),
          style: AppTextStyles.headline,
        ),
        content: Text(
          dialogContext.tr('Third-Party AI Consent Message'),
          style: AppTextStyles.body,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.tr('Agree & Continue')),
          ),
        ],
      ),
    );

    if (result == true) {
      await setConsent(true);
      return true;
    }
    return false;
  }

  /// Checks for existing consent; if missing, shows the dialog.
  /// Returns `true` when the user has consented (now or previously).
  Future<bool> ensureConsent(BuildContext context) async {
    // if (await hasConsent()) {
    //   return true;
    // }
    if (!context.mounted) {
      return false;
    }
    return requestConsent(context);
  }
}
