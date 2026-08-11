import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/growth_service.dart';
import '../theme/app_theme.dart';

TextStyle _overlayTextStyle(TextStyle style) {
  return style.copyWith(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );
}

/// Reusable visual feedback for XP gains/losses and level-up celebrations.
class GrowthFeedbackOverlay {
  static Future<void> showForResult(
    BuildContext context,
    GrowthActivityResult? result, {
    String? label,
  }) async {
    if (result == null) {
      return;
    }

    if (result.xpDelta != 0) {
      _showExperienceBubble(context, result, label: label);
    }

    if (result.leveledUp) {
      await _showLevelUpCelebration(context, result);
    }
  }

  static void _showExperienceBubble(
    BuildContext context,
    GrowthActivityResult result, {
    String? label,
  }) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return _ExperienceBubbleEntry(
          result: result,
          label: label,
          onCompleted: () => entry.remove(),
        );
      },
    );
    overlay.insert(entry);
  }

  static Future<void> _showLevelUpCelebration(
    BuildContext context,
    GrowthActivityResult result,
  ) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context).tr('Level up'),
      barrierColor: Colors.black.withOpacity(0.7),
      pageBuilder: (_, __, ___) {
        return _LevelUpDialog(result: result);
      },
      transitionBuilder: (_, Animation<double> animation, __, Widget child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }
}

class _ExperienceBubbleEntry extends StatefulWidget {
  final GrowthActivityResult result;
  final String? label;
  final VoidCallback onCompleted;

  const _ExperienceBubbleEntry({
    required this.result,
    required this.label,
    required this.onCompleted,
  });

  @override
  State<_ExperienceBubbleEntry> createState() => _ExperienceBubbleEntryState();
}

class _ExperienceBubbleEntryState extends State<_ExperienceBubbleEntry> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    unawaited(_play());
  }

  Future<void> _play() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (!mounted) {
      return;
    }
    setState(() => _visible = true);

    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) {
      return;
    }
    setState(() => _visible = false);

    await Future<void>.delayed(const Duration(milliseconds: 320));
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPositive = widget.result.xpDelta > 0;
    final String xpText = '${isPositive ? '+' : ''}${widget.result.xpDelta} XP';
    final List<String> rewardParts = <String>[
      if (widget.result.reward.coins > 0)
        context.tr(
          '+{coins} coins',
          params: <String, String>{'coins': '${widget.result.reward.coins}'},
        ),
      if (widget.result.reward.freeAiUses > 0)
        context.tr(
          '+{count} free AI',
          params: <String, String>{
            'count': '${widget.result.reward.freeAiUses}',
          },
        ),
    ];

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            offset: _visible ? Offset.zero : const Offset(1.1, 0),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _visible ? 1 : 0,
              child: Container(
                width: 220,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: isPositive
                      ? const LinearGradient(
                          colors: <Color>[Color(0xFF1F9D87), Color(0xFFE9C46A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: <Color>[Color(0xFFB24545), Color(0xFF6A2E2E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.label ??
                          (isPositive
                              ? context.tr('Growth boosted')
                              : context.tr('Growth setback')),
                      style: _overlayTextStyle(
                        AppTextStyles.label,
                      ).copyWith(color: Colors.white.withOpacity(0.9)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      xpText,
                      style: _overlayTextStyle(AppTextStyles.headline).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (rewardParts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        rewardParts.join('  ·  '),
                        style: _overlayTextStyle(
                          AppTextStyles.caption,
                        ).copyWith(color: Colors.white.withOpacity(0.92)),
                      ),
                    ],
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

class _LevelUpDialog extends StatefulWidget {
  final GrowthActivityResult result;

  const _LevelUpDialog({required this.result});

  @override
  State<_LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<_LevelUpDialog> {
  @override
  void initState() {
    super.initState();
    unawaited(_dismissLater());
  }

  Future<void> _dismissLater() async {
    await Future<void>.delayed(const Duration(milliseconds: 1900));
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> rewardParts = <String>[
      if (widget.result.reward.coins > 0)
        context.tr(
          '+{coins} PawCoins',
          params: <String, String>{'coins': '${widget.result.reward.coins}'},
        ),
      if (widget.result.reward.freeAiUses > 0)
        context.tr(
          '+{count} free AI use',
          params: <String, String>{
            'count': '${widget.result.reward.freeAiUses}',
          },
        ),
    ];

    return Material(
      color: Colors.transparent,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.82, end: 1),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutBack,
          builder: (_, double scale, Widget? child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ...List<Widget>.generate(10, (int index) {
                final double angle = index * 0.62;
                final double radius = 130 + (index.isEven ? 18 : 0);
                return Transform.translate(
                  offset: Offset(
                    radius * (index.isEven ? 0.6 : -0.6) * 0.5,
                    radius * (index - 5) * 0.08,
                  ),
                  child: Transform.rotate(
                    angle: angle,
                    child: Icon(
                      index.isEven ? Icons.auto_awesome : Icons.star_rounded,
                      color: index.isEven
                          ? AppColors.accent.withOpacity(0.75)
                          : Colors.white.withOpacity(0.85),
                      size: index.isEven ? 28 : 18,
                    ),
                  ),
                );
              }),
              Container(
                width: 310,
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[
                      Color(0xFF112F33),
                      Color(0xFF1F6F69),
                      Color(0xFFE9C46A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 30,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.tr('LEVEL UP'),
                      style: _overlayTextStyle(AppTextStyles.label).copyWith(
                        letterSpacing: 2.4,
                        color: Colors.white.withOpacity(0.86),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lv.${widget.result.previousLevel}  ->  Lv.${widget.result.currentLevel}',
                      style: _overlayTextStyle(
                        AppTextStyles.display,
                      ).copyWith(color: Colors.white, fontSize: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr(
                        'Your care routine just pushed your companion into a new stage.',
                      ),
                      textAlign: TextAlign.center,
                      style: _overlayTextStyle(
                        AppTextStyles.body,
                      ).copyWith(color: Colors.white.withOpacity(0.92)),
                    ),
                    if (rewardParts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          rewardParts.join('  ·  '),
                          textAlign: TextAlign.center,
                          style: _overlayTextStyle(AppTextStyles.body).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
