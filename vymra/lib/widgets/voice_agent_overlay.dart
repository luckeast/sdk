import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../agent/voice_agent_controller.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';

/// Full-screen voice assistant overlay opened from the Home header.
class VoiceAgentOverlay extends StatefulWidget {
  final Widget child;

  const VoiceAgentOverlay({super.key, required this.child});

  @override
  State<VoiceAgentOverlay> createState() => _VoiceAgentOverlayState();
}

class _VoiceAgentOverlayState extends State<VoiceAgentOverlay> {
  final TextEditingController _textController = TextEditingController();
  String _lastSyncedTranscript = '';

  void _dismissKeyboard() {
    final FocusScopeNode focusScope = FocusScope.of(context);
    if (!focusScope.hasPrimaryFocus && focusScope.focusedChild != null) {
      focusScope.unfocus();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VoiceAgentController? controller = context
        .watch<VoiceAgentController?>();
    if (controller == null) {
      return widget.child;
    }

    if (_lastSyncedTranscript != controller.lastTranscript) {
      _lastSyncedTranscript = controller.lastTranscript;
      _textController.value = TextEditingValue(
        text: controller.lastTranscript,
        selection: TextSelection.collapsed(
          offset: controller.lastTranscript.length,
        ),
      );
    }

    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Stack(
      children: <Widget>[
        widget.child,
        IgnorePointer(
          ignoring: !controller.isVisible,
          child: AnimatedOpacity(
            opacity: controller.isVisible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _dismissKeyboard,
              child: Container(
                color: Colors.black.withValues(alpha: 0.58),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      return AnimatedPadding(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          20,
                          20,
                          20 + keyboardInset,
                        ),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  constraints.maxHeight - keyboardInset - 40 > 0
                                  ? constraints.maxHeight - keyboardInset - 40
                                  : 0,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 560,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: <Color>[
                                          Color(0xFF112B31),
                                          Color(0xFF1B4A52),
                                          Color(0xFF2A9D8F),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 28,
                                          offset: const Offset(0, 16),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.14,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                              child: Icon(
                                                controller.isListening
                                                    ? Icons.graphic_eq_rounded
                                                    : Icons.smart_toy_rounded,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Text(
                                                    controller.greeting,
                                                    style: AppTextStyles.title
                                                        .copyWith(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    context.tr(
                                                      'Tap Listening to speak naturally and run app tools directly.',
                                                    ),
                                                    style: AppTextStyles.caption
                                                        .copyWith(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.78,
                                                              ),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: controller.dismiss,
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        _OverlayCard(
                                          label: context.tr('Assistant Reply'),
                                          child: Text(
                                            controller.hasAssistantReply
                                                ? controller.resultSummary
                                                : context.tr(
                                                    'Try asking me to create a pet named Lucky, record a weight of 4.2 kilograms, open games, or add a vaccine reminder.',
                                                  ),
                                            style: AppTextStyles.body.copyWith(
                                              color: Colors.white,
                                              height: 1.45,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: _textController,
                                          onTapOutside: (_) =>
                                              _dismissKeyboard(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: context.tr(
                                              'Fallback text command',
                                            ),
                                            hintStyle: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          minLines: 1,
                                          maxLines: 4,
                                          onChanged: (String value) {
                                            if (_lastSyncedTranscript !=
                                                value) {
                                              _lastSyncedTranscript = value;
                                            }
                                          },
                                          onSubmitted: controller.isExecuting
                                              ? null
                                              : (String value) {
                                                  _dismissKeyboard();
                                                  controller.executeTranscript(
                                                    value,
                                                  );
                                                },
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed:
                                                    controller.isExecuting
                                                    ? null
                                                    : controller
                                                          .toggleListening,
                                                icon: Icon(
                                                  controller.isListening
                                                      ? Icons.graphic_eq_rounded
                                                      : Icons.mic_none_rounded,
                                                ),
                                                label: Text(
                                                  controller.isListening
                                                      ? context.tr('Listening')
                                                      : context.tr(
                                                          'Start Listening',
                                                        ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed:
                                                    controller.isExecuting
                                                    ? null
                                                    : () {
                                                        _dismissKeyboard();
                                                        controller
                                                            .executeTranscript(
                                                              _textController
                                                                  .text,
                                                            );
                                                      },
                                                icon: const Icon(
                                                  Icons.play_arrow_rounded,
                                                ),
                                                label: Text(context.tr('Run')),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  side: BorderSide(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.24,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          controller.statusMessage,
                                          style: AppTextStyles.label.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.72,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _OverlayCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: Colors.white.withValues(alpha: 0.74),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
