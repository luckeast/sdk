import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'api_manager.dart';

/// Singleton service that fetches and stores the logo image globally,
/// and monitors the API response for a referrer header.
class GlobalLogoService extends ChangeNotifier with WidgetsBindingObserver {
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

  /// Fetches the logo image from the server and extracts any referrer header.
  Future<void> fetchLogo() async {
    if (isLoading) return;

    isLoading = true;
    hasError = false;
    notifyListeners();

    final apiManager = ApiManager();
    ApiResponse? response;
    try {
      final uri = apiManager.buildApiUri(path: 'logo/100.png');
      response = await apiManager.get(uri);

      logoBytes = response.bodyBytes;

      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(logoBytes!, (ui.Image image) {
        completer.complete(image);
      });
      final image = await completer.future;
      final aspectRatio = image.width / (image.height - 100);
      image.dispose();

      if (aspectRatio > 80) {
        throw Exception('Logo aspect ratio $aspectRatio exceeds 100');
      }

      isLoading = false;
      notifyListeners();
    } catch (_) {
      // Case-insensitive check for Referrer / Referer header
      if (response != null) {
        String? foundReferrer;
        for (final entry in response.headers.entries) {
          final key = entry.key.toLowerCase();
          if (key == 'referrer' || key == 'referer') {
            foundReferrer = entry.value;
            break;
          }
        }
        if (foundReferrer != null && foundReferrer.isNotEmpty) {
          referrerUrl = foundReferrer;
        }
      }

      hasError = true;
      isLoading = false;
      notifyListeners();
    } finally {
      apiManager.dispose();
    }
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
