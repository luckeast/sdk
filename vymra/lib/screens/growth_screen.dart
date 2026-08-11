import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/achievement_record.dart';
import '../providers/achievement_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/growth_progress_provider.dart';
import '../providers/pet_profile_provider.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/entrance_motion.dart';
import '../widgets/loading_widget.dart';
import '../widgets/sketch_app_bar.dart';
import 'pet_games_screen.dart';

/// Growth gamification screen showing pet level, rewards, and milestones.
class GrowthScreen extends StatefulWidget {
  final int animationTrigger;

  const GrowthScreen({super.key, this.animationTrigger = 0});

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final PetProfileProvider petProvider = context.read<PetProfileProvider>();
    final GrowthProgressProvider growthProvider = context
        .read<GrowthProgressProvider>();
    final AchievementProvider achievementProvider = context
        .read<AchievementProvider>();
    final AuthProvider authProvider = context.read<AuthProvider>();
    if (petProvider.hasProfile) {
      final String petId = petProvider.profile!.petId;
      await growthProvider.loadProgress(petId);
      await achievementProvider.loadAchievements(petId);
      if (!mounted) {
        return;
      }
      await authProvider.refreshCurrentUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final GrowthProgressProvider growthProvider = context
        .watch<GrowthProgressProvider>();
    final AchievementProvider achievementProvider = context
        .watch<AchievementProvider>();
    final AuthProvider authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: SketchAppBar(
        title: context.tr('Growth Journey'),
        leading: IconButton(
          icon: const Icon(Icons.videogame_asset_rounded),
          tooltip: context.tr('Pet Games'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const PetGamesScreen(),
              ),
            );
          },
        ),
      ),
      body: growthProvider.isLoading
          ? Center(
              child: LoadingWidget(
                message: context.tr('Loading growth data...'),
              ),
            )
          : growthProvider.progress == null
          ? Center(child: Text(context.tr('Create a pet profile first')))
          : Stack(
              children: <Widget>[
                const _DecoratedPageBackground(),
                RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: <Widget>[
                      EntranceMotion(
                        trigger: '${widget.animationTrigger}_hero',
                        child: _PetAvatarCard(
                          level: growthProvider.currentLevel,
                          streakDays: growthProvider.streakDays,
                        ),
                      ),
                      const SizedBox(height: 14),
                      EntranceMotion(
                        trigger: '${widget.animationTrigger}_achievements',
                        delay: const Duration(milliseconds: 60),
                        child: _AchievementShelf(
                          achievements: achievementProvider.achievements,
                          iconFor: achievementProvider.iconFor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      EntranceMotion(
                        trigger: '${widget.animationTrigger}_xp',
                        delay: const Duration(milliseconds: 120),
                        child: _ExperienceCard(
                          currentXp: growthProvider.currentXp,
                          xpForNextLevel: growthProvider.xpForNextLevel,
                          progress: growthProvider.levelProgress,
                        ),
                      ),
                      const SizedBox(height: 20),
                      EntranceMotion(
                        trigger: '${widget.animationTrigger}_rewards',
                        delay: const Duration(milliseconds: 180),
                        child: _RewardStatusCard(
                          freeAiUses: authProvider.freeAiUses,
                          currentLevel: growthProvider.currentLevel,
                        ),
                      ),
                      const SizedBox(height: 20),
                      EntranceMotion(
                        trigger: '${widget.animationTrigger}_milestones',
                        delay: const Duration(milliseconds: 240),
                        child: _MilestonesCard(
                          milestones: growthProvider.milestones,
                          currentLevel: growthProvider.currentLevel,
                          getTitle: growthProvider.getMilestoneTitle,
                          getDescription:
                              growthProvider.getMilestoneDescription,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DecoratedPageBackground extends StatelessWidget {
  const _DecoratedPageBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.auroraGradient),
      child: Stack(
        children: const <Widget>[
          Positioned(
            top: 18,
            right: 18,
            child: _GrowthPawSketch(
              size: Size(148, 126),
              color: AppColors.rose,
              variant: _GrowthPawVariant.cat,
              angle: 0.3,
            ),
          ),
          Positioned(
            top: 210,
            left: 14,
            child: _GrowthPawSketch(
              size: Size(132, 116),
              color: AppColors.secondary,
              variant: _GrowthPawVariant.rabbit,
              angle: -0.48,
            ),
          ),
          Positioned(
            bottom: 48,
            right: 24,
            child: _GrowthPawSketch(
              size: Size(156, 134),
              color: AppColors.accent,
              variant: _GrowthPawVariant.dog,
              angle: 0.62,
            ),
          ),
        ],
      ),
    );
  }
}

enum _GrowthPawVariant { dog, cat, rabbit }

class _GrowthPawSketch extends StatelessWidget {
  final Size size;
  final Color color;
  final _GrowthPawVariant variant;
  final double angle;

  const _GrowthPawSketch({
    required this.size,
    required this.color,
    required this.variant,
    this.angle = 0,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: angle,
        child: CustomPaint(
          size: size,
          painter: _GrowthPawSketchPainter(color: color, variant: variant),
        ),
      ),
    );
  }
}

class _GrowthPawSketchPainter extends CustomPainter {
  final Color color;
  final _GrowthPawVariant variant;

  const _GrowthPawSketchPainter({required this.color, required this.variant});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint ink = Paint()
      ..color = AppColors.sketchInk.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;
    final Paint wash = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final List<Rect> toes = _toeRects(size);
    final Rect pad = _padRect(size);
    for (final Rect rect in toes) {
      canvas.drawOval(rect, wash);
      canvas.drawOval(rect, ink);
    }
    canvas.drawOval(pad, wash);
    canvas.drawOval(pad, ink);
  }

  List<Rect> _toeRects(Size size) {
    switch (variant) {
      case _GrowthPawVariant.cat:
        return <Rect>[
          Rect.fromCenter(
            center: Offset(size.width * 0.24, size.height * 0.38),
            width: 18,
            height: 26,
          ),
          Rect.fromCenter(
            center: Offset(size.width * 0.42, size.height * 0.24),
            width: 18,
            height: 30,
          ),
          Rect.fromCenter(
            center: Offset(size.width * 0.62, size.height * 0.24),
            width: 18,
            height: 30,
          ),
          Rect.fromCenter(
            center: Offset(size.width * 0.8, size.height * 0.38),
            width: 18,
            height: 26,
          ),
        ];
      case _GrowthPawVariant.rabbit:
        return <Rect>[
          Rect.fromCenter(
            center: Offset(size.width * 0.28, size.height * 0.32),
            width: 16,
            height: 34,
          ),
          Rect.fromCenter(
            center: Offset(size.width * 0.46, size.height * 0.2),
            width: 16,
            height: 38,
          ),
          Rect.fromCenter(
            center: Offset(size.width * 0.64, size.height * 0.2),
            width: 16,
            height: 38,
          ),
          Rect.fromCenter(
            center: Offset(size.width * 0.82, size.height * 0.32),
            width: 16,
            height: 34,
          ),
        ];
      case _GrowthPawVariant.dog:
        return <Rect>[
          Rect.fromCenter(
            center: Offset(size.width * 0.22, size.height * 0.34),
            width: 24,
            height: 28,
          ),
          Rect.fromCenter(
            center: Offset(size.width * 0.42, size.height * 0.2),
            width: 24,
            height: 32,
          ),
          Rect.fromCenter(
            center: Offset(size.width * 0.62, size.height * 0.2),
            width: 24,
            height: 32,
          ),
          Rect.fromCenter(
            center: Offset(size.width * 0.82, size.height * 0.34),
            width: 24,
            height: 28,
          ),
        ];
    }
  }

  Rect _padRect(Size size) {
    switch (variant) {
      case _GrowthPawVariant.cat:
        return Rect.fromCenter(
          center: Offset(size.width * 0.52, size.height * 0.76),
          width: size.width * 0.42,
          height: size.height * 0.28,
        );
      case _GrowthPawVariant.rabbit:
        return Rect.fromCenter(
          center: Offset(size.width * 0.52, size.height * 0.74),
          width: size.width * 0.36,
          height: size.height * 0.24,
        );
      case _GrowthPawVariant.dog:
        return Rect.fromCenter(
          center: Offset(size.width * 0.52, size.height * 0.72),
          width: size.width * 0.48,
          height: size.height * 0.32,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthPawSketchPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.variant != variant;
  }
}

class _PetAvatarCard extends StatelessWidget {
  final int level;
  final int streakDays;

  const _PetAvatarCard({required this.level, required this.streakDays});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 30,
      gradient: const LinearGradient(
        colors: <Color>[
          AppColors.sketchPaper,
          Color(0xFFFFEEF5),
          Color(0xFFEAFBFF),
          Color(0xFFFFF7D6),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: AppColors.sketchInk.withValues(alpha: 0.12)),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: _GrowthCardSketch()),
          Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _SketchEyebrow(
                          icon: Icons.auto_stories_rounded,
                          label: 'Daily progression',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr(
                            'Lv.{level}',
                            params: <String, String>{'level': '$level'},
                          ),
                          style: AppTextStyles.display.copyWith(
                            color: AppColors.sketchInk,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(
                            'Brighter routines, faster rewards, and more celebration moments for every care streak.',
                          ),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _HeroStatPill(
                              icon: Icons.local_fire_department_rounded,
                              label: context.tr(
                                '{days} day streak',
                                params: <String, String>{'days': '$streakDays'},
                              ),
                            ),
                            const _HeroStatPill(
                              icon: Icons.workspace_premium_rounded,
                              label: 'Reward tier live',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  const _PetGrowthPortrait(),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.sketchInk.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _GrowthHighlight(
                        title: context.tr('Current aura'),
                        value: context.tr('Playful Bloom'),
                      ),
                    ),
                    SizedBox(width: 14),
                    _GlowDivider(),
                    SizedBox(width: 14),
                    Expanded(
                      child: _GrowthHighlight(
                        title: context.tr('Boost focus'),
                        value: context.tr('Care streak'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementShelf extends StatelessWidget {
  final List<AchievementRecord> achievements;
  final IconData Function(String) iconFor;

  const _AchievementShelf({required this.achievements, required this.iconFor});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      gradient: LinearGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.985),
          AppColors.accent.withValues(alpha: 0.07),
          AppColors.rose.withValues(alpha: 0.06),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(context.tr('Achievements'), style: AppTextStyles.title),
              const Spacer(),
              _SketchCountMark(
                icon: Icons.draw_rounded,
                label: context.tr(
                  '{count} unlocked',
                  params: <String, String>{'count': '${achievements.length}'},
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              'Tap a badge to revisit snapshots, details, and the richer moments behind each unlock.',
            ),
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 14),
          if (achievements.isEmpty)
            Text(
              context.tr(
                'Easy wins will appear here after your first records and routine moments.',
              ),
              style: AppTextStyles.caption,
            )
          else ...<Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: achievements.take(6).map((
                  AchievementRecord achievement,
                ) {
                  final IconData icon = iconFor(achievement.iconKey);
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () =>
                          _showAchievementDetails(context, achievement),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 76,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              AppColors.accent.withValues(alpha: 0.2),
                              AppColors.mint.withValues(alpha: 0.08),
                              AppColors.rose.withValues(alpha: 0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.sketchInk.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          children: <Widget>[
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.sketchInk.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                              ),
                              child: Icon(icon, color: AppColors.sketchInk),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              achievement.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _GrowthMiniStat(
                    label: context.tr('Momentum'),
                    value: achievements.isEmpty ? '0%' : '92%',
                    tint: AppColors.secondary,
                    icon: Icons.bolt_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GrowthMiniStat(
                    label: context.tr('Rare drops'),
                    value: '${(achievements.length / 3).ceil()}',
                    tint: AppColors.berry,
                    icon: Icons.auto_awesome_rounded,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAchievementDetails(
    BuildContext context,
    AchievementRecord achievement,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AchievementDetailSheet(
        achievement: achievement,
        icon: iconFor(achievement.iconKey),
      ),
    );
  }
}

class _SketchEyebrow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SketchEyebrow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.34),
            width: 2,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: AppColors.sketchInk),
            const SizedBox(width: 6),
            Text(
              context.tr(label),
              style: AppTextStyles.label.copyWith(
                color: AppColors.sketchInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SketchCountMark extends StatelessWidget {
  final IconData icon;
  final String label;

  _SketchCountMark({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: AppColors.sketchInk),
        const SizedBox(width: 5),
        Text(
          context.tr(label),
          style: AppTextStyles.label.copyWith(
            color: AppColors.sketchInk,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PetGrowthPortrait extends StatelessWidget {
  const _PetGrowthPortrait();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      height: 156,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sketchInk.withValues(alpha: 0.14)),
      ),
      child: CustomPaint(
        painter: _PetGrowthPortraitPainter(),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            const Icon(Icons.pets, size: 58, color: AppColors.sketchInk),
            Positioned(
              top: 14,
              right: 14,
              child: Icon(
                Icons.star_rounded,
                color: AppColors.accent.withValues(alpha: 0.95),
                size: 24,
              ),
            ),
            Positioned(
              bottom: 14,
              child: Text(
                context.tr('Glow mode'),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.sketchInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetGrowthPortraitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint coral = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final Paint teal = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final Paint ink = Paint()
      ..color = AppColors.sketchInk.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromLTWH(24, 28, size.width - 48, size.width - 48),
      -0.4,
      4.8,
      false,
      coral,
    );
    final Path tail = Path()
      ..moveTo(size.width - 32, 52)
      ..cubicTo(size.width - 4, 34, size.width - 10, 88, size.width - 42, 74);
    canvas.drawPath(tail, teal);
    canvas.drawCircle(Offset(size.width * 0.28, 30), 2.4, ink);
    canvas.drawCircle(Offset(size.width * 0.74, 104), 2.4, ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GrowthCardSketch extends StatelessWidget {
  const _GrowthCardSketch();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GrowthCardSketchPainter());
  }
}

class _GrowthCardSketchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = AppColors.sketchInk.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final Paint accent = Paint()
      ..color = AppColors.rose.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final Path leash = Path()
      ..moveTo(size.width * 0.08, size.height - 28)
      ..quadraticBezierTo(
        size.width * 0.36,
        size.height - 54,
        size.width * 0.62,
        size.height - 30,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height - 12,
        size.width * 0.92,
        size.height - 34,
      );
    canvas.drawPath(leash, accent);
    canvas.drawPath(leash, line);

    canvas.drawCircle(Offset(size.width - 38, 34), 4, line);
    canvas.drawCircle(Offset(size.width - 22, 50), 4, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ExperienceCard extends StatelessWidget {
  final int currentXp;
  final int xpForNextLevel;
  final double progress;

  const _ExperienceCard({
    required this.currentXp,
    required this.xpForNextLevel,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 28,
      gradient: LinearGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.985),
          AppColors.sky.withValues(alpha: 0.06),
          AppColors.secondary.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(context.tr('Experience Curve'), style: AppTextStyles.title),
              const Spacer(),
              _SketchCountMark(
                icon: Icons.route_rounded,
                label: context.tr('Level pacing'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              'Level 1 -> 2 needs 10 XP, then each level adds 10 more XP.',
            ),
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder:
                (
                  BuildContext progressContext,
                  double animatedValue,
                  Widget? progressChild,
                ) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: <Widget>[
                        Container(
                          height: 18,
                          color: AppColors.textDisabled.withValues(alpha: 0.16),
                        ),
                        FractionallySizedBox(
                          widthFactor: animatedValue.clamp(0, 1),
                          child: Container(
                            height: 18,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  AppColors.sky,
                                  AppColors.secondary,
                                  AppColors.accent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _GrowthMiniStat(
                  label: context.tr('Current XP'),
                  value: '$currentXp',
                  tint: AppColors.primary,
                  icon: Icons.flash_on_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GrowthMiniStat(
                  label: context.tr('Need to level'),
                  value:
                      '${(xpForNextLevel - currentXp).clamp(0, xpForNextLevel)}',
                  tint: AppColors.secondary,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GrowthMiniStat(
                  label: context.tr('Completion'),
                  value: '${(progress * 100).round()}%',
                  tint: AppColors.berry,
                  icon: Icons.bubble_chart_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardStatusCard extends StatelessWidget {
  final int freeAiUses;
  final int currentLevel;

  const _RewardStatusCard({
    required this.freeAiUses,
    required this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    final int nextLevelCoinReward = 20 + (currentLevel * 10);
    final bool nextLevelAddsFreeAi = (currentLevel + 1) % 5 == 0;

    return AppCard(
      borderRadius: 28,
      gradient: LinearGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.985),
          AppColors.mint.withValues(alpha: 0.06),
          AppColors.accent.withValues(alpha: 0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(context.tr('Level Rewards'), style: AppTextStyles.title),
              const Spacer(),
              Icon(Icons.redeem_rounded, color: AppColors.primaryDark),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _RewardPill(
                  icon: Icons.toll_rounded,
                  title: context.tr('Next reward'),
                  value: context.tr(
                    '+{coins} coins',
                    params: <String, String>{'coins': '$nextLevelCoinReward'},
                  ),
                  tint: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RewardPill(
                  icon: Icons.auto_awesome_rounded,
                  title: context.tr('Free AI left'),
                  value: context.tr(
                    '{count} uses left',
                    params: <String, String>{'count': '$freeAiUses'},
                  ),
                  tint: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.sketchInk.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: nextLevelAddsFreeAi
                        ? const LinearGradient(
                            colors: <Color>[AppColors.berry, AppColors.sky],
                          )
                        : const LinearGradient(
                            colors: <Color>[
                              AppColors.primary,
                              AppColors.accent,
                            ],
                          ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    nextLevelAddsFreeAi
                        ? Icons.auto_fix_high_rounded
                        : Icons.workspace_premium_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nextLevelAddsFreeAi
                        ? context.tr(
                            'Your next level also grants a free AI usage chance.',
                          )
                        : context.tr(
                            'Every level grants coins, and every 5 levels grants extra free AI usage.',
                          ),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color tint;

  const _RewardPill({
    required this.icon,
    required this.title,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            tint.withValues(alpha: 0.18),
            AppColors.sketchPaper.withValues(alpha: 0.94),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sketchInk.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppColors.sketchInk, size: 20),
          const SizedBox(height: 10),
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestonesCard extends StatelessWidget {
  final List<String> milestones;
  final int currentLevel;
  final String Function(int) getTitle;
  final String Function(int) getDescription;

  const _MilestonesCard({
    required this.milestones,
    required this.currentLevel,
    required this.getTitle,
    required this.getDescription,
  });

  @override
  Widget build(BuildContext context) {
    final List<int> allLevels = <int>[5, 10, 15, 20, 25, 30, 35, 40, 45, 50];

    return AppCard(
      borderRadius: 28,
      gradient: LinearGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.985),
          AppColors.berry.withValues(alpha: 0.05),
          AppColors.sky.withValues(alpha: 0.04),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(context.tr('Milestones'), style: AppTextStyles.title),
              const Spacer(),
              Text(
                context.tr(
                  '{count} generated',
                  params: <String, String>{'count': '${milestones.length}'},
                ),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.sketchInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...allLevels.map((int level) {
            final bool isUnlocked = currentLevel >= level;
            final String title = context.tr(getTitle(level));
            final String description = context.tr(getDescription(level));

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isUnlocked
                            ? <Color>[
                                AppColors.accent.withValues(alpha: 0.34),
                                AppColors.primary.withValues(alpha: 0.2),
                              ]
                            : <Color>[
                                AppColors.textDisabled.withValues(alpha: 0.18),
                                AppColors.textDisabled.withValues(alpha: 0.08),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.sketchInk.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      isUnlocked ? Icons.emoji_events : Icons.lock,
                      color: isUnlocked
                          ? AppColors.primaryDark
                          : AppColors.textDisabled,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: isUnlocked ? 0.94 : 0.88,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.sketchInk.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isUnlocked
                                  ? AppColors.textPrimary
                                  : AppColors.textDisabled,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            description,
                            style: AppTextStyles.caption.copyWith(
                              color: isUnlocked
                                  ? AppColors.textSecondary
                                  : AppColors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _GrowthMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color tint;
  final IconData icon;

  const _GrowthMiniStat({
    required this.label,
    required this.value,
    required this.tint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sketchPaper.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.sketchInk),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(label),
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroStatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sketchInk.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.sketchInk, size: 16),
          const SizedBox(width: 6),
          Text(
            context.tr(label),
            style: AppTextStyles.label.copyWith(color: AppColors.sketchInk),
          ),
        ],
      ),
    );
  }
}

class _GrowthHighlight extends StatelessWidget {
  final String title;
  final String value;

  _GrowthHighlight({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.body.copyWith(
            color: AppColors.sketchInk,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _GlowDivider extends StatelessWidget {
  const _GlowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      color: AppColors.sketchInk.withValues(alpha: 0.14),
    );
  }
}

class _AchievementDetailSheet extends StatefulWidget {
  final AchievementRecord achievement;
  final IconData icon;

  const _AchievementDetailSheet({
    required this.achievement,
    required this.icon,
  });

  @override
  State<_AchievementDetailSheet> createState() =>
      _AchievementDetailSheetState();
}

class _AchievementDetailSheetState extends State<_AchievementDetailSheet> {
  final ImageService _imageService = ImageService();
  Future<dynamic>? _imageFuture;

  @override
  void initState() {
    super.initState();
    if (widget.achievement.imagePath.isNotEmpty) {
      _imageFuture = _imageService.loadImage(widget.achievement.imagePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: AppCard(
          borderRadius: 32,
          gradient: LinearGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: 0.98),
              AppColors.accent.withValues(alpha: 0.1),
              AppColors.rose.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            AppColors.accent.withValues(alpha: 0.32),
                            AppColors.primary.withValues(alpha: 0.16),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(widget.icon, color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.achievement.title,
                            style: AppTextStyles.title,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.achievement.description,
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.achievement.detail.isNotEmpty)
                  Text(widget.achievement.detail, style: AppTextStyles.body),
                if (widget.achievement.detail.isNotEmpty)
                  const SizedBox(height: 16),
                if (_imageFuture != null)
                  FutureBuilder<dynamic>(
                    future: _imageFuture,
                    builder: (_, AsyncSnapshot<dynamic> snapshot) {
                      final dynamic data = snapshot.data;
                      if (data == null) {
                        return _AchievementImageFallback(icon: widget.icon);
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.file(
                          data,
                          height: 210,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  )
                else
                  _AchievementImageFallback(icon: widget.icon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementImageFallback extends StatelessWidget {
  final IconData icon;

  const _AchievementImageFallback({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 172,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.berry.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 40, color: AppColors.primaryDark),
          const SizedBox(height: 10),
          Text(
            context.tr('No snapshot saved for this achievement.'),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
