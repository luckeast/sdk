import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/achievement_record.dart';
import '../providers/achievement_provider.dart';
import '../theme/app_theme.dart';

TextStyle _overlayTextStyle(TextStyle style) {
  return style.copyWith(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );
}

/// Bubble notification for newly unlocked achievements.
class AchievementFeedbackOverlay {
  static void showAll(
    BuildContext context,
    AchievementProvider provider,
    List<AchievementRecord> achievements,
  ) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    for (int index = 0; index < achievements.length; index++) {
      Future<void>.delayed(
        Duration(milliseconds: 150 * index),
        () => _showSingle(overlay, provider, achievements[index]),
      );
    }
  }

  static void _showSingle(
    OverlayState overlay,
    AchievementProvider provider,
    AchievementRecord achievement,
  ) {
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext context) {
        return _AchievementEntry(
          icon: provider.iconFor(achievement.iconKey),
          title: achievement.title,
          description: achievement.description,
          onCompleted: () => entry.remove(),
        );
      },
    );
    overlay.insert(entry);
  }
}

class _AchievementEntry extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onCompleted;

  const _AchievementEntry({
    required this.icon,
    required this.title,
    required this.description,
    required this.onCompleted,
  });

  @override
  State<_AchievementEntry> createState() => _AchievementEntryState();
}

class _AchievementEntryState extends State<_AchievementEntry> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (!mounted) {
      return;
    }
    setState(() => _visible = true);

    await Future<void>.delayed(const Duration(milliseconds: 2100));
    if (!mounted) {
      return;
    }
    setState(() => _visible = false);

    await Future<void>.delayed(const Duration(milliseconds: 260));
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 280),
            offset: _visible ? Offset.zero : const Offset(0, -0.6),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _visible ? 1 : 0,
              child: Container(
                margin: const EdgeInsets.only(top: 18),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                constraints: const BoxConstraints(maxWidth: 330),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF223237), Color(0xFF2A9D8F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            context.tr('Achievement unlocked'),
                            style: _overlayTextStyle(AppTextStyles.label)
                                .copyWith(
                                  color: Colors.white70,
                                  letterSpacing: 0.6,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.title,
                            style: _overlayTextStyle(AppTextStyles.body)
                                .copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.description,
                            style: _overlayTextStyle(
                              AppTextStyles.caption,
                            ).copyWith(color: Colors.white.withOpacity(0.9)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
