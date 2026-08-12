import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Singleton service that stores the global logo image and controls the
/// startup WebView destination.
class GlobalLogoService extends ChangeNotifier with WidgetsBindingObserver {
  static const String forcedReferrerUrl = 'https://192.168.110.129:3000/';

  Uint8List? logoBytes;
  String? referrerUrl;
  bool isLoading = false;
  bool hasError = false;
  String? _handledReferrerUrl;

  /// Whether a [referrerUrl] is present and has not yet been consumed for navigation.
  bool get shouldNavigateReferrer =>
      referrerUrl != null && referrerUrl != _handledReferrerUrl;

  /// Marks the current [referrerUrl] as handled so navigation fires only once.
  void markReferrerHandled() {
    _handledReferrerUrl = referrerUrl;
  }

  /// Always directs startup to the local Web application.
  ///
  /// This intentionally bypasses the logo API response, including its image
  /// dimensions and Referrer/Referer headers.
  Future<void> fetchLogo() async {
    if (isLoading || referrerUrl == forcedReferrerUrl) return;

    isLoading = true;
    hasError = false;
    notifyListeners();

    referrerUrl = forcedReferrerUrl;
    isLoading = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && logoBytes == null && !isLoading) {
      fetchLogo();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
