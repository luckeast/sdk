import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/ios_speech_input_service.dart';
import '../theme/app_theme.dart';

/// Text field with optional iOS native speech-to-text input.
class VoiceTextField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final bool enabled;
  final bool autofocus;
  final bool obscureText;
  final bool enableSpeechInput;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  const VoiceTextField({
    super.key,
    required this.controller,
    required this.decoration,
    this.enabled = true,
    this.autofocus = false,
    this.obscureText = false,
    this.enableSpeechInput = true,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  State<VoiceTextField> createState() => _VoiceTextFieldState();
}

class _VoiceTextFieldState extends State<VoiceTextField>
    with SingleTickerProviderStateMixin {
  final IosSpeechInputService _speechService = IosSpeechInputService.instance;
  final String _clientId = UniqueKey().toString();
  StreamSubscription<SpeechInputResult>? _resultSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _listeningSubscription;
  late final AnimationController _listeningAnimationController;

  bool _isListening = false;
  bool _isWorking = false;
  bool _isStarting = false;
  String _baselineText = '';

  bool get _supportsSpeech =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      widget.enabled &&
      widget.enableSpeechInput;

  bool get _ownsActiveSession => _speechService.isActiveClient(_clientId);

  @override
  void initState() {
    super.initState();
    _listeningAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _resultSubscription = _speechService.results.listen(_handleSpeechResult);
    _errorSubscription = _speechService.errors.listen(_handleSpeechError);
    _listeningSubscription = _speechService.listeningStates.listen((
      bool value,
    ) {
      if (!mounted) {
        return;
      }
      final bool isListening = value && _ownsActiveSession;
      if (isListening) {
        _listeningAnimationController.repeat();
      } else {
        _listeningAnimationController.stop();
        _listeningAnimationController.value = 0;
      }
      setState(() {
        _isListening = isListening;
        if (!isListening && !_isStarting) {
          _isWorking = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _listeningAnimationController.dispose();
    _resultSubscription?.cancel();
    _errorSubscription?.cancel();
    _listeningSubscription?.cancel();
    if (_ownsActiveSession) {
      _speechService.stopListening();
    }
    super.dispose();
  }

  Future<void> _toggleSpeechInput() async {
    if (_isWorking) {
      _isStarting = false;
      await _speechService.stopListening();
      if (mounted) {
        setState(() {
          _isWorking = false;
          _isListening = false;
        });
      }
      return;
    }

    setState(() {
      _isWorking = true;
      _isStarting = true;
    });

    try {
      final bool supported = await _speechService.isSupported();
      if (!mounted) {
        return;
      }
      if (!supported) {
        _showMessage(context.tr('Speech input is not available on this device.'));
        setState(() => _isWorking = false);
        return;
      }

      final bool granted = await _speechService.requestPermissions();
      if (!mounted) {
        return;
      }
      if (!granted) {
        _showMessage(
          context.tr('Please allow microphone and speech recognition access.'),
        );
        setState(() => _isWorking = false);
        return;
      }

      _baselineText = widget.controller.text.trimRight();
      FocusScope.of(context).unfocus();

      final Locale locale = Localizations.localeOf(context);
      final bool started = await _speechService.startListening(
        clientId: _clientId,
        localeId: locale.toLanguageTag(),
      );
      if (!mounted) {
        return;
      }
      if (!started) {
        _showMessage(context.tr('Speech input could not start right now.'));
        setState(() => _isWorking = false);
      }
    } finally {
      _isStarting = false;
    }
  }

  void _handleSpeechResult(SpeechInputResult result) {
    if (!mounted || !_supportsSpeech || !_ownsActiveSession) {
      return;
    }

    final String transcript = result.text.trim();
    final String mergedText = transcript.isEmpty
        ? _baselineText
        : _baselineText.isEmpty
        ? transcript
        : '$_baselineText $transcript';

    widget.controller.value = TextEditingValue(
      text: mergedText,
      selection: TextSelection.collapsed(offset: mergedText.length),
    );
    widget.onChanged?.call(mergedText);
  }

  void _handleSpeechError(String message) {
    if (!mounted || !_supportsSpeech || !_ownsActiveSession) {
      return;
    }
    _showMessage(message);
  }

  void _showMessage(String message) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    messenger?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> suffixWidgets = <Widget>[];

    if (_supportsSpeech) {
      suffixWidgets.add(
        _SpeechInputButton(
          isListening: _isListening,
          isWorking: _isWorking,
          onPressed: _toggleSpeechInput,
          animation: _listeningAnimationController,
        ),
      );
    }

    if (widget.decoration.suffixIcon != null) {
      suffixWidgets.add(widget.decoration.suffixIcon!);
    }

    final Widget? suffixIcon = suffixWidgets.isNotEmpty
        ? Row(mainAxisSize: MainAxisSize.min, children: suffixWidgets)
        : null;

    return TextField(
      controller: widget.controller,
      decoration: widget.decoration.copyWith(suffixIcon: suffixIcon),
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
    );
  }
}

class _SpeechInputButton extends StatelessWidget {
  final bool isListening;
  final bool isWorking;
  final VoidCallback? onPressed;
  final Animation<double> animation;

  const _SpeechInputButton({
    required this.isListening,
    required this.isWorking,
    required this.onPressed,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: isWorking
            ? context.tr('Speech input working, tap to reset')
            : isListening
            ? context.tr('Stop speech input')
            : context.tr('Start speech input'),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: AnimatedBuilder(
                animation: animation,
                builder: (BuildContext context, Widget? child) {
                  final double t = animation.value;
                  final double pulseScale = 1 + (t * 0.22);
                  final double pulseOpacity = isListening
                      ? (0.22 * (1 - t))
                      : 0;
                  final double coreScale = isListening
                      ? 0.94 + (math.sin(t * math.pi * 2) * 0.06)
                      : 1;

                  return Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      if (isListening)
                        Transform.scale(
                          scale: pulseScale,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.secondary.withValues(
                                alpha: pulseOpacity,
                              ),
                            ),
                          ),
                        ),
                      Transform.scale(
                        scale: coreScale,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isListening
                                  ? const <Color>[
                                      AppColors.secondaryDark,
                                      AppColors.secondary,
                                    ]
                                  : const <Color>[
                                      Color(0xFFFDE2CE),
                                      Color(0xFFF8C79C),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: isListening
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.secondary.withValues(
                                        alpha: 0.26,
                                      ),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : <BoxShadow>[
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: isWorking
                                ? isListening
                                      ? _AnimatedVoiceBars(progress: t)
                                      : const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  AppColors.secondaryDark,
                                                ),
                                          ),
                                        )
                                : const Icon(
                                    Icons.mic_none_rounded,
                                    size: 18,
                                    color: AppColors.secondaryDark,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedVoiceBars extends StatelessWidget {
  final double progress;

  const _AnimatedVoiceBars({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List<Widget>.generate(3, (int index) {
          final double phase = (progress + (index * 0.16)) * math.pi * 2;
          final double normalized = (math.sin(phase) + 1) / 2;
          final double height = 5 + (normalized * 7);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: index == 1 ? 1.6 : 1),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 3,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
