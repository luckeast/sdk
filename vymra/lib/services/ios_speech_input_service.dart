import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Streaming speech-to-text payload from the iOS native bridge.
class SpeechInputResult {
  final String text;
  final bool isFinal;

  const SpeechInputResult({required this.text, required this.isFinal});
}

/// Lightweight bridge for iOS native speech recognition.
class IosSpeechInputService {
  IosSpeechInputService._();

  static final IosSpeechInputService instance = IosSpeechInputService._();

  static const MethodChannel _methodChannel = MethodChannel(
    'vymra/ios_speech_input/methods',
  );
  static const EventChannel _eventChannel = EventChannel(
    'vymra/ios_speech_input/events',
  );

  final StreamController<SpeechInputResult> _resultController =
      StreamController<SpeechInputResult>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<bool> _listeningController =
      StreamController<bool>.broadcast();

  StreamSubscription<dynamic>? _eventSubscription;
  String? _activeClientId;

  bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Stream<SpeechInputResult> get results => _resultController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<bool> get listeningStates => _listeningController.stream;

  Future<bool> isSupported() async {
    if (!isSupportedPlatform) {
      return false;
    }

    final bool? supported = await _methodChannel.invokeMethod<bool>(
      'isSupported',
    );
    return supported ?? false;
  }

  Future<bool> requestPermissions() async {
    if (!isSupportedPlatform) {
      return false;
    }

    final bool? granted = await _methodChannel.invokeMethod<bool>(
      'requestPermissions',
    );
    return granted ?? false;
  }

  bool isActiveClient(String clientId) => _activeClientId == clientId;

  Future<bool> startListening({
    required String clientId,
    String? localeId,
  }) async {
    if (!isSupportedPlatform) {
      return false;
    }

    await _ensureEventSubscription();
    final bool? started = await _methodChannel.invokeMethod<bool>(
      'startListening',
      <String, Object?>{
        if (localeId != null && localeId.isNotEmpty) 'localeId': localeId,
      },
    );
    final bool didStart = started ?? false;
    if (didStart) {
      _activeClientId = clientId;
    }
    return didStart;
  }

  Future<void> stopListening() async {
    if (!isSupportedPlatform) {
      return;
    }

    await _methodChannel.invokeMethod<void>('stopListening');
  }

  Future<void> cancelListening() async {
    if (!isSupportedPlatform) {
      return;
    }

    await _methodChannel.invokeMethod<void>('cancelListening');
  }

  Future<void> _ensureEventSubscription() async {
    if (_eventSubscription != null) {
      return;
    }

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (Object error) {
        _activeClientId = null;
        _listeningController.add(false);
        _errorController.add('Speech input is temporarily unavailable.');
      },
    );
  }

  void _handleEvent(dynamic event) {
    if (event is! Map<Object?, Object?>) {
      return;
    }

    final String type = (event['type'] as String?) ?? '';

    if (type == 'state') {
      final bool listening = (event['isListening'] as bool?) ?? false;
      if (!listening) {
        _activeClientId = null;
      }
      _listeningController.add(listening);
      return;
    }

    if (type == 'result') {
      final String text = (event['text'] as String?) ?? '';
      final bool isFinal = (event['isFinal'] as bool?) ?? false;
      _resultController.add(SpeechInputResult(text: text, isFinal: isFinal));
      return;
    }

    if (type == 'error') {
      _activeClientId = null;
      _listeningController.add(false);
      _errorController.add(
        (event['message'] as String?) ?? 'Speech recognition failed.',
      );
    }
  }
}
