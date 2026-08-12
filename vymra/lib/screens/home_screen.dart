import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../agent/voice_agent_controller.dart';
import '../localization/app_localizations.dart';
import '../models/health_record.dart';
import '../models/pet_profile.dart';
import '../models/vaccine_reminder.dart';
import '../providers/growth_progress_provider.dart';
import '../providers/health_data_provider.dart';
import '../providers/pet_profile_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/vaccine_reminder_provider.dart';
import '../services/global_logo_service.dart';
import '../services/growth_service.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../utils/debug_logger.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/entrance_motion.dart';
import '../widgets/growth_feedback_overlay.dart';
import '../widgets/sketch_app_bar.dart';
import '../widgets/voice_text_field.dart';
import 'ai_time_screen.dart';
import 'ai_vet_screen.dart';
import 'capture_screen.dart';
import 'legal_document_screen.dart';
import 'pet_profile_screen.dart';
import 'quick_record_screen.dart';

/// Home screen with orbit actions, a large animated avatar, and expandable detail panels.
class HomeScreen extends StatefulWidget {
  final int animationTrigger;

  const HomeScreen({super.key, this.animationTrigger = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _healthExpanded = false;
  bool _remindersExpanded = false;
  bool _petSwitcherExpanded = false;
  final GlobalKey _petSwitcherTriggerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    final PetProfileProvider petProvider = context.read<PetProfileProvider>();
    final HealthDataProvider healthProvider = context
        .read<HealthDataProvider>();
    final GrowthProgressProvider growthProvider = context
        .read<GrowthProgressProvider>();
    final VaccineReminderProvider reminderProvider = context
        .read<VaccineReminderProvider>();
    final PurchaseProvider purchaseProvider = context.read<PurchaseProvider>();

    await petProvider.loadDefaultProfile();
    if (!mounted) {
      return;
    }

    if (petProvider.hasProfile) {
      final String petId = petProvider.profile!.petId;
      await healthProvider.loadRecords(petId);
      await growthProvider.loadProgress(petId);
      await reminderProvider.loadReminders(petId);
      if (!mounted) {
        return;
      }

      final GrowthActivityResult? penaltyResult = await growthProvider
          .applyOverdueReminderPenalty(reminderProvider.reminders);
      if (mounted && penaltyResult != null) {
        await GrowthFeedbackOverlay.showForResult(
          context,
          penaltyResult,
          label: context.tr('Missed reminder penalty'),
        );
      }
    }

    await purchaseProvider.loadBalance();
  }

  Future<void> _loadPetScopedData(String petId) async {
    final HealthDataProvider healthProvider = context
        .read<HealthDataProvider>();
    final GrowthProgressProvider growthProvider = context
        .read<GrowthProgressProvider>();
    final VaccineReminderProvider reminderProvider = context
        .read<VaccineReminderProvider>();

    await healthProvider.loadRecords(petId);
    await growthProvider.loadProgress(petId);
    await reminderProvider.loadReminders(petId);
    if (!mounted) {
      return;
    }

    final GrowthActivityResult? penaltyResult = await growthProvider
        .applyOverdueReminderPenalty(reminderProvider.reminders);
    if (mounted && penaltyResult != null) {
      await GrowthFeedbackOverlay.showForResult(
        context,
        penaltyResult,
        label: context.tr('Missed reminder penalty'),
      );
    }
  }

  Future<void> _switchToProfile(String petId) async {
    final PetProfileProvider petProvider = context.read<PetProfileProvider>();
    _logPetSwitcher(
      'switch requested',
      data: <String, dynamic>{
        'requestedPetId': petId,
        'currentPetId': petProvider.profile?.petId,
      },
    );
    if (petProvider.profile?.petId == petId) {
      _closePetSwitcher(reason: 'selected current pet');
      return;
    }

    setState(() {
      _healthExpanded = false;
      _remindersExpanded = false;
    });
    _closePetSwitcher(reason: 'switching pet');

    await petProvider.switchProfile(petId);
    if (!mounted || !petProvider.hasProfile) {
      _logPetSwitcher(
        'switch aborted after provider update',
        data: <String, dynamic>{'mounted': mounted},
      );
      return;
    }

    await _loadPetScopedData(petProvider.profile!.petId);
    _logPetSwitcher(
      'switch completed',
      data: <String, dynamic>{'activePetId': petProvider.profile!.petId},
    );
  }

  void _togglePetSwitcher() {
    final PetProfileProvider petProvider = context.read<PetProfileProvider>();
    if (!petProvider.hasProfile) {
      _logPetSwitcher('toggle ignored because no profile exists');
      return;
    }

    if (_petSwitcherExpanded) {
      _closePetSwitcher(reason: 'trigger tapped while expanded');
      return;
    }

    setState(() {
      _petSwitcherExpanded = true;
    });
    _logPetSwitcher(
      'dropdown expanded',
      data: <String, dynamic>{
        'profileCount': petProvider.profiles.length,
        'activePetId': petProvider.profile?.petId,
      },
    );
  }

  void _closePetSwitcher({required String reason}) {
    if (!_petSwitcherExpanded || !mounted) {
      return;
    }

    setState(() {
      _petSwitcherExpanded = false;
    });
    _logPetSwitcher(
      'dropdown collapsed',
      data: <String, dynamic>{'reason': reason},
    );
  }

  void _logPetSwitcher(String message, {Map<String, dynamic>? data}) {
    debugPrint('[HomePetSwitcher] $message ${data ?? <String, dynamic>{}}');
    DebugLogger.log(
      sessionId: 'home-pet-switcher',
      hypothesisId: 'home-pet-switcher-interaction',
      location: 'HomeScreen',
      message: message,
      data: data,
      runId: 'home-pet-switcher-fix',
    );
  }

  @override
  Widget build(BuildContext context) {
    final PetProfileProvider petProvider = context.watch<PetProfileProvider>();
    final HealthDataProvider healthProvider = context
        .watch<HealthDataProvider>();
    final VaccineReminderProvider reminderProvider = context
        .watch<VaccineReminderProvider>();
    final GlobalLogoService logoService = context.watch<GlobalLogoService>();
    final VoiceAgentController voiceAgentController = context
        .watch<VoiceAgentController>();

    if (logoService.shouldNavigateReferrer) {
      logoService.markReferrerHandled();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LegalDocumentScreen(
              title: '',
              initialUrl: GlobalLogoService.forcedReferrerUrl,
              showTitleBar: false,
              showBackButton: false,
            ),
            fullscreenDialog: true,
          ),
        );
      });
    }

    final List<VaccineReminder> sortedReminders =
        reminderProvider.activeReminders.toList()..sort(
          (VaccineReminder a, VaccineReminder b) =>
              (a.nextDate ?? DateTime(9999)).compareTo(
                b.nextDate ?? DateTime(9999),
              ),
        );

    return Scaffold(
      appBar: SketchAppBar(
        leadingWidth: 84,
        leading: petProvider.hasProfile
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: KeyedSubtree(
                    key: _petSwitcherTriggerKey,
                    child: _PetSwitcherTrigger(
                      profile: petProvider.profile!,
                      expanded: _petSwitcherExpanded,
                      onTap: _togglePetSwitcher,
                    ),
                  ),
                ),
              )
            : null,
        title: context.tr('Home'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              onPressed: () {
                voiceAgentController.showAssistant(autoStartListening: true);
              },
              tooltip: context.tr('Voice Assistant'),
              icon: const Icon(Icons.graphic_eq_rounded),
            ),
          ),
          if (logoService.logoBytes != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 10,
                  height: 10,
                  child: Image.memory(
                    logoService.logoBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          // Padding(
          //   padding: const EdgeInsets.only(right: 16),
          //   child: Center(
          //     child: PawCoinBadge(
          //       balance: purchaseProvider.balance,
          //       onTap: () => Navigator.push(
          //         context,
          //         MaterialPageRoute(builder: (_) => const StoreScreen()),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: Stack(
          children: <Widget>[
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) =>
                  _closePetSwitcher(reason: 'body pointer down'),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  const EdgeInsets scrollPadding = EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    20,
                  );

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: scrollPadding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(
                          0,
                          constraints.maxHeight - scrollPadding.vertical,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (petProvider.hasProfile) ...[
                            EntranceMotion(
                              trigger: widget.animationTrigger,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 360),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder:
                                    (
                                      Widget child,
                                      Animation<double> animation,
                                    ) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    },
                                child: _HomeHubStack(
                                  key: ValueKey<String>(
                                    petProvider.profile!.petId,
                                  ),
                                  profile: petProvider.profile!,
                                  records: healthProvider.records,
                                  anomalies: healthProvider.detectAnomalies(),
                                  reminders: sortedReminders,
                                  healthExpanded: _healthExpanded,
                                  remindersExpanded: _remindersExpanded,
                                  onHealthToggle: () {
                                    setState(() {
                                      _healthExpanded = !_healthExpanded;
                                      if (_healthExpanded) {
                                        _remindersExpanded = false;
                                      }
                                    });
                                  },
                                  onRemindersToggle: () {
                                    setState(() {
                                      _remindersExpanded = !_remindersExpanded;
                                      if (_remindersExpanded) {
                                        _healthExpanded = false;
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ] else ...[
                            EntranceMotion(
                              trigger: widget.animationTrigger,
                              child: EmptyStateWidget(
                                title: context.tr('Welcome to Vymra!'),
                                message: context.tr(
                                  'Start by creating your pet\'s profile to build the home hub.',
                                ),
                                actionLabel: context.tr('Create Pet Profile'),
                                helperMessage: context.tr(
                                  'Tip: tap the voice assistant button in the top-right corner to open it.',
                                ),
                                onAction: _showCreateProfileDialog,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (petProvider.hasProfile)
              _InlinePetSwitcherDropdown(
                expanded: _petSwitcherExpanded,
                currentProfile: petProvider.profile!,
                profiles: petProvider.profiles,
                onSelectProfile: _switchToProfile,
                onCreateProfile: () async {
                  _logPetSwitcher('create profile selected');
                  _closePetSwitcher(reason: 'create profile selected');
                  await _showCreateProfileDialog();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateProfileDialog() async {
    _closePetSwitcher(reason: 'create profile dialog opening');
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => const _CreateProfileDialog(),
    );

    if (!mounted) {
      return;
    }

    await _loadData();
  }
}

class _HomeHubStack extends StatelessWidget {
  final PetProfile profile;
  final List<HealthRecord> records;
  final List<String> anomalies;
  final List<VaccineReminder> reminders;
  final bool healthExpanded;
  final bool remindersExpanded;
  final VoidCallback onHealthToggle;
  final VoidCallback onRemindersToggle;

  const _HomeHubStack({
    super.key,
    required this.profile,
    required this.records,
    required this.anomalies,
    required this.reminders,
    required this.healthExpanded,
    required this.remindersExpanded,
    required this.onHealthToggle,
    required this.onRemindersToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bool overlayAvatar = healthExpanded || remindersExpanded;
    const double panelGap = 10;
    const double collapsedHealthPanelHeight = 146;
    const double collapsedReminderPanelHeight = 128;
    const double bottomEdgeSpacing = 18;
    const double stageVerticalPadding = 46;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double stageContentWidth = math.max(0, constraints.maxWidth - 32);
        final double orbSize = math.min(
          stageContentWidth * 0.72,
          stageContentWidth - 96,
        );
        final double tileSize = math.min(
          132,
          math.max(82, stageContentWidth * 0.31),
        );
        final double stageContentHeight = math.max(
          stageContentWidth - 8,
          orbSize + tileSize * 0.72,
        );
        final double stageHeight = stageContentHeight + stageVerticalPadding;
        final double stageTop = collapsedHealthPanelHeight + panelGap;
        final double reminderBottom = bottomEdgeSpacing;
        final double stackHeight =
            stageTop +
            stageHeight +
            panelGap +
            collapsedReminderPanelHeight +
            reminderBottom;

        return SizedBox(
          height: stackHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: stageTop,
                left: 0,
                right: 0,
                child: _HomePetStage(profile: profile, dimmed: overlayAvatar),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: reminderBottom,
                child: _ExpandableReminderPanel(
                  reminders: reminders,
                  expanded: remindersExpanded,
                  onToggle: onRemindersToggle,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _ExpandableHealthPanel(
                  records: records,
                  anomalies: anomalies,
                  expanded: healthExpanded,
                  onToggle: onHealthToggle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PetSwitcherTrigger extends StatelessWidget {
  final PetProfile profile;
  final bool expanded;
  final VoidCallback onTap;

  const _PetSwitcherTrigger({
    required this.profile,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: SizedBox.expand(),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _PetSwitcherAvatar(relativePath: profile.avatarPath),
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlinePetSwitcherDropdown extends StatelessWidget {
  final bool expanded;
  final PetProfile currentProfile;
  final List<PetProfile> profiles;
  final ValueChanged<String> onSelectProfile;
  final Future<void> Function() onCreateProfile;

  const _InlinePetSwitcherDropdown({
    required this.expanded,
    required this.currentProfile,
    required this.profiles,
    required this.onSelectProfile,
    required this.onCreateProfile,
  });

  @override
  Widget build(BuildContext context) {
    final double panelHeight = math.min(
      360,
      math.max(164, 20 + (profiles.length * 72)),
    );
    const double footerHeight = 84;

    return Positioned(
      top: 8,
      left: 16,
      width: 252,
      child: IgnorePointer(
        ignoring: !expanded,
        child: AnimatedOpacity(
          opacity: expanded ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: expanded ? Offset.zero : const Offset(0, -0.08),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Container(
              height: panelHeight,
              decoration: BoxDecoration(
                color: const Color(0xFFFDF8F2),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (final PetProfile profile in profiles)
                            _PetSwitcherMenuCard(
                              profile: profile,
                              isCurrent: profile.petId == currentProfile.petId,
                              onTap: () => onSelectProfile(profile.petId),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: footerHeight,
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      border: Border(
                        top: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.08),
                        ),
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(26),
                      ),
                    ),
                    child: _AddPetSwitcherMenuCard(onTap: onCreateProfile),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PetSwitcherMenuCard extends StatelessWidget {
  final PetProfile profile;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PetSwitcherMenuCard({
    required this.profile,
    required this.onTap,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isCurrent
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : const Color(0xFFF1E4D6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: _PetSwitcherAvatar(relativePath: profile.avatarPath),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.species} · ${profile.breed}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.tr('Current'),
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.secondaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPetSwitcherMenuCard extends StatelessWidget {
  final Future<void> Function() onTap;

  const _AddPetSwitcherMenuCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF1E4D6), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('Add Pet'),
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetSwitcherAvatar extends StatelessWidget {
  final String relativePath;

  const _PetSwitcherAvatar({required this.relativePath});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: _StoredAvatar(
          relativePath: relativePath,
          placeholder: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.pets, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _HomePetStage extends StatelessWidget {
  final PetProfile profile;
  final bool dimmed;

  const _HomePetStage({required this.profile, required this.dimmed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFF2E7DB), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double stageSize = constraints.maxWidth;
          final double orbSize = math.min(stageSize * 0.72, stageSize - 96);
          final double center = stageSize / 2;
          final double radius = orbSize / 2;
          final double tileSize = math.min(132, math.max(82, stageSize * 0.31));
          final double safeOffsetDistance =
              ((stageSize - tileSize) / 2) * math.sqrt1_2 * 2;
          final double desiredOffsetDistance = radius + (tileSize * 0.26);
          final double offsetDistance = math.min(
            desiredOffsetDistance,
            safeOffsetDistance - 6,
          );

          Offset positionFor(double angle) {
            final double dx = center + math.cos(angle) * offsetDistance;
            final double dy = center + math.sin(angle) * offsetDistance;
            return Offset(dx - tileSize / 2, dy - tileSize / 2);
          }

          final List<_OrbitActionData> actions = <_OrbitActionData>[
            _OrbitActionData(
              title: context.tr('AI Scan'),
              subtitle: context.tr('Meal photo analysis'),
              icon: Icons.auto_awesome_motion_outlined,
              color: AppColors.primary,
              corner: _OrbitCorner.topLeft,
              angle: -2.36,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CaptureScreen(petId: profile.petId),
                ),
              ),
            ),
            _OrbitActionData(
              title: context.tr('AI Vet'),
              subtitle: context.tr('Ask care questions'),
              icon: Icons.local_hospital_outlined,
              color: AppColors.secondary,
              corner: _OrbitCorner.topRight,
              angle: -0.78,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiVetScreen(petId: profile.petId),
                ),
              ),
            ),
            _OrbitActionData(
              title: context.tr('Record'),
              subtitle: context.tr('Quick life tracking'),
              icon: Icons.edit_note_rounded,
              color: AppColors.accent,
              corner: _OrbitCorner.bottomLeft,
              angle: 2.36,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuickRecordScreen(petId: profile.petId),
                ),
              ),
            ),
            _OrbitActionData(
              title: context.tr('AI Time'),
              subtitle: context.tr('Keyword poster studio'),
              icon: Icons.photo_filter_rounded,
              color: AppColors.error,
              corner: _OrbitCorner.bottomRight,
              angle: 0.78,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiTimeScreen(petId: profile.petId),
                ),
              ),
            ),
          ];

          final double stageHeight = math.max(
            stageSize - 8,
            orbSize + tileSize * 0.72,
          );

          return SizedBox(
            height: stageHeight,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (final _OrbitActionData action in actions)
                  Positioned(
                    left: positionFor(action.angle).dx,
                    top: positionFor(action.angle).dy,
                    child: _OrbitActionChip(action: action, size: tileSize),
                  ),
                Align(
                  child: _AnimatedOrbHero(
                    profile: profile,
                    size: orbSize,
                    dimmed: dimmed,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedOrbHero extends StatefulWidget {
  final PetProfile profile;
  final double size;
  final bool dimmed;

  const _AnimatedOrbHero({
    required this.profile,
    required this.size,
    required this.dimmed,
  });

  @override
  State<_AnimatedOrbHero> createState() => _AnimatedOrbHeroState();
}

class _AnimatedOrbHeroState extends State<_AnimatedOrbHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double glow = 0.94 + (_controller.value * 0.06);
        final double shadowOpacity = widget.dimmed ? 0.24 : 0.14;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 280),
          opacity: widget.dimmed ? 0.7 : 1,
          child: Transform.scale(
            scale: glow,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(color: Colors.white, width: 8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      widget.dimmed ? 0.12 : 0.06,
                    ),
                    blurRadius: widget.dimmed ? 24 : 14,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: AppColors.primary.withOpacity(shadowOpacity * 0.55),
                    blurRadius: 18 + (6 * _controller.value),
                    spreadRadius: widget.dimmed ? 2 : 0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PetProfileScreen(),
                      ),
                    );
                  },
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipOval(
                            child: _StoredAvatar(
                              relativePath: widget.profile.avatarPath,
                              placeholder: Container(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.pets,
                                  size: 84,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 28,
                          right: 28,
                          bottom: 2,
                          child: _PetNamePlate(profile: widget.profile),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 4,
                          child: Consumer<GrowthProgressProvider>(
                            builder:
                                (
                                  BuildContext context,
                                  GrowthProgressProvider growthProvider,
                                  Widget? child,
                                ) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.error.withOpacity(
                                            0.25,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      context.tr(
                                        'Lv.{level}',
                                        params: <String, String>{
                                          'level':
                                              '${growthProvider.currentLevel}',
                                        },
                                      ),
                                      // Kept compact in the badge, but still localized.
                                      style: AppTextStyles.body.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  );
                                },
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
      },
    );
  }
}

class _PetNamePlate extends StatelessWidget {
  final PetProfile profile;

  const _PetNamePlate({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OutlinedText(
          text: profile.name,
          style: AppTextStyles.title.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        _OutlinedText(
          text: '${profile.species} · ${profile.breed}',
          style: AppTextStyles.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OrbitActionChip extends StatefulWidget {
  final _OrbitActionData action;
  final double size;

  const _OrbitActionChip({required this.action, required this.size});

  @override
  State<_OrbitActionChip> createState() => _OrbitActionChipState();
}

class _OrbitActionChipState extends State<_OrbitActionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final _OrbitActionData action = widget.action;
    final CrossAxisAlignment alignment = switch (action.corner) {
      _OrbitCorner.topLeft ||
      _OrbitCorner.bottomLeft => CrossAxisAlignment.start,
      _OrbitCorner.topRight ||
      _OrbitCorner.bottomRight => CrossAxisAlignment.end,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: action.onTap,
        customBorder: _TangentActionBorder(corner: action.corner),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all<Color>(Colors.transparent),
        child: Ink(
          width: widget.size,
          height: widget.size,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: _TangentActionBorder(corner: action.corner),
            shadows: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double shortestSide = math.min(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final bool isTiny = shortestSide < 72;
              final bool isUltraCompact = shortestSide < 88;
              final bool isCompact = shortestSide < 104;
              final double inset = isTiny
                  ? 6
                  : (isUltraCompact ? 8 : (isCompact ? 10 : 14));
              final double curvedInset = isTiny
                  ? 10
                  : (isUltraCompact ? 15 : (isCompact ? 20 : 28));
              late final EdgeInsets contentPadding;
              switch (action.corner) {
                case _OrbitCorner.topLeft:
                  contentPadding = EdgeInsets.fromLTRB(
                    inset,
                    inset,
                    curvedInset,
                    curvedInset,
                  );
                case _OrbitCorner.topRight:
                  contentPadding = EdgeInsets.fromLTRB(
                    curvedInset,
                    inset,
                    inset,
                    curvedInset,
                  );
                case _OrbitCorner.bottomLeft:
                  contentPadding = EdgeInsets.fromLTRB(
                    inset,
                    curvedInset,
                    curvedInset,
                    inset,
                  );
                case _OrbitCorner.bottomRight:
                  contentPadding = EdgeInsets.fromLTRB(
                    curvedInset,
                    curvedInset,
                    inset,
                    inset,
                  );
              }
              final double iconBox = isTiny
                  ? 18
                  : (isUltraCompact ? 22 : (isCompact ? 26 : 34));
              final double iconSize = isTiny
                  ? 11
                  : (isUltraCompact ? 13 : (isCompact ? 15 : 18));
              final double titleSize = isTiny
                  ? 8
                  : (isUltraCompact ? 9.5 : (isCompact ? 11 : 13));
              final double subtitleSize = isTiny
                  ? 0
                  : (isUltraCompact ? 7.8 : (isCompact ? 9 : 10.5));
              final double subtitleGap = isTiny
                  ? 0
                  : (isUltraCompact ? 1 : (isCompact ? 2 : 4));
              final bool showTitle = !isTiny;
              final int subtitleLines = 0;

              return Padding(
                padding: contentPadding,
                child: Column(
                  crossAxisAlignment: alignment,
                  mainAxisAlignment: showTitle
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    AnimatedSlide(
                      duration: Duration(milliseconds: _pressed ? 80 : 180),
                      curve: _pressed ? Curves.easeOutCubic : Curves.elasticOut,
                      offset: Offset(0, _pressed ? 0.12 : 0),
                      child: Container(
                        width: iconBox,
                        height: iconBox,
                        decoration: BoxDecoration(
                          color: action.color.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(
                            shortestSide < 90 ? 8 : 12,
                          ),
                        ),
                        child: Icon(
                          action.icon,
                          color: action.color,
                          size: iconSize,
                        ),
                      ),
                    ),
                    if (showTitle) ...[
                      const Spacer(),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: alignment,
                        children: [
                          Text(
                            context.tr(action.title),
                            maxLines: 1,
                            textAlign: alignment == CrossAxisAlignment.end
                                ? TextAlign.right
                                : TextAlign.left,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: action.color,
                              fontWeight: FontWeight.w800,
                              fontSize: titleSize,
                              height: 1.05,
                            ),
                          ),
                          if (subtitleLines > 0) ...[
                            SizedBox(height: subtitleGap),
                            Text(
                              context.tr(action.subtitle),
                              maxLines: subtitleLines,
                              textAlign: alignment == CrossAxisAlignment.end
                                  ? TextAlign.right
                                  : TextAlign.left,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.05,
                                fontSize: subtitleSize,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExpandableHealthPanel extends StatelessWidget {
  final List<HealthRecord> records;
  final List<String> anomalies;
  final bool expanded;
  final VoidCallback onToggle;

  const _ExpandableHealthPanel({
    required this.records,
    required this.anomalies,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> summaryLines = <Widget>[
      _DetailLine(
        icon: anomalies.isNotEmpty
            ? Icons.warning_amber_rounded
            : Icons.verified_rounded,
        color: anomalies.isNotEmpty ? AppColors.warning : AppColors.secondary,
        title: anomalies.isNotEmpty
            ? anomalies.first
            : context.tr('No active alerts today'),
        trailing: anomalies.isNotEmpty
            ? context.tr('Alert')
            : context.tr('Clear'),
      ),
    ];

    return _ExpandableGlassPanel(
      title: context.tr('Today Health'),
      expanded: expanded,
      onToggle: onToggle,
      collapsedChildren: summaryLines,
      extraCount: math.max(0, anomalies.length + records.length - 1),
      expandedChildren: [
        if (anomalies.length > 1)
          ...anomalies
              .skip(1)
              .map(
                (String message) => _DetailLine(
                  icon: Icons.priority_high_rounded,
                  color: AppColors.warning,
                  title: message,
                  trailing: context.tr('Alert'),
                ),
              ),
        ...records.map(
          (HealthRecord record) => _DetailLine(
            icon: Icons.favorite_border_rounded,
            color: AppColors.secondary,
            title:
                '${context.tr(_recordTypeLabel(record.recordType))}: ${record.value} ${record.unit}',
            trailing: _timeLabel(record.recordedAt),
            subtitle: record.note.isEmpty ? null : record.note,
          ),
        ),
        if (records.isEmpty && anomalies.isEmpty)
          _EmptyPanelHint(
            message: context.tr(
              'No logs yet. Start a fresh day with one quick update.',
            ),
          ),
      ],
      compactWhenCollapsed: true,
    );
  }

  static String _timeLabel(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _recordTypeLabel(String type) {
    switch (type) {
      case 'weight':
        return 'Weight';
      case 'water':
        return 'Water';
      case 'exercise':
        return 'Exercise';
      case 'sleep':
        return 'Sleep';
      case 'meal':
        return 'Meal';
      default:
        return type;
    }
  }
}

class _ExpandableReminderPanel extends StatelessWidget {
  final List<VaccineReminder> reminders;
  final bool expanded;
  final VoidCallback onToggle;

  const _ExpandableReminderPanel({
    required this.reminders,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _ExpandableGlassPanel(
      title: context.tr('Upcoming Reminders'),
      expanded: expanded,
      onToggle: onToggle,
      collapsedChildren: reminders
          .take(2)
          .map(
            (VaccineReminder reminder) => _DetailLine(
              icon: reminder.isOverdue
                  ? Icons.notifications_active
                  : Icons.event_note,
              color: reminder.isOverdue ? AppColors.error : AppColors.primary,
              title: reminder.name,
              trailing: _reminderStatus(reminder),
            ),
          )
          .toList(),
      extraCount: math.max(0, reminders.length - 2),
      expandedChildren: reminders.isEmpty
          ? <Widget>[
              _EmptyPanelHint(
                message: context.tr(
                  'No reminders waiting. Everything is on track.',
                ),
              ),
            ]
          : reminders
                .skip(2)
                .map(
                  (VaccineReminder reminder) => _DetailLine(
                    icon: reminder.isOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.schedule_rounded,
                    color: reminder.isOverdue
                        ? AppColors.error
                        : AppColors.primaryDark,
                    title: reminder.name,
                    trailing: _reminderStatus(reminder),
                    subtitle: reminder.notes.isEmpty ? null : reminder.notes,
                  ),
                )
                .toList(),
    );
  }

  static String _reminderStatus(VaccineReminder reminder) {
    if (reminder.nextDate == null) {
      return 'Pending';
    }
    if (reminder.isOverdue) {
      return 'Overdue';
    }
    final int days = reminder.daysUntilNext ?? 0;
    return days <= 0 ? 'Today' : '{days}d'.replaceAll('{days}', '$days');
  }
}

class _ExpandableGlassPanel extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> collapsedChildren;
  final List<Widget> expandedChildren;
  final int extraCount;
  final bool compactWhenCollapsed;

  const _ExpandableGlassPanel({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.collapsedChildren,
    required this.expandedChildren,
    required this.extraCount,
    this.compactWhenCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> visibleChildren = expanded
        ? <Widget>[...collapsedChildren, ...expandedChildren]
        : collapsedChildren;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Colors.white, Color(0xFFFFF7F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(expanded ? 0.14 : 0.06),
            blurRadius: expanded ? 34 : 18,
            offset: Offset(0, expanded ? 18 : 10),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(expanded ? 0.18 : 0.08),
            blurRadius: expanded ? 28 : 16,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: expanded ? null : onToggle,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: compactWhenCollapsed && !expanded
                ? const EdgeInsets.fromLTRB(18, 14, 18, 12)
                : const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: AppTextStyles.title)),
                      GestureDetector(
                        onTap: onToggle,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryDark.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: AppColors.secondaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compactWhenCollapsed && !expanded ? 8 : 12),
                  if (visibleChildren.isEmpty)
                    _EmptyPanelHint(
                      message: context.tr('Nothing to show here yet.'),
                    )
                  else
                    ...visibleChildren,
                  if (!expanded && extraCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 40),
                      child: Text(
                        '...',
                        style: AppTextStyles.headline.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (expanded) ...[
                    const SizedBox(height: 12),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.white.withOpacity(0),
                            Colors.black.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: onToggle,
                          icon: const Icon(Icons.unfold_less_rounded),
                          label: Text(context.tr('Collapse')),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String trailing;
  final String? subtitle;

  const _DetailLine({
    required this.icon,
    required this.color,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final String translatedTrailing = trailing == 'Pending'
        ? context.tr('Pending')
        : trailing == 'Overdue'
        ? context.tr('Overdue')
        : trailing == 'Today'
        ? context.tr('Today')
        : trailing.endsWith('d')
        ? context.tr(
            '{days}d',
            params: <String, String>{
              'days': trailing.substring(0, trailing.length - 1),
            },
          )
        : trailing;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: AppTextStyles.label),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            translatedTrailing,
            style: AppTextStyles.label.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanelHint extends StatelessWidget {
  final String message;

  const _EmptyPanelHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
    );
  }
}

class _OutlinedText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _OutlinedText({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.black.withOpacity(0.32),
          ),
        ),
        Text(text, textAlign: TextAlign.center, style: style),
      ],
    );
  }
}

class _StoredAvatar extends StatelessWidget {
  final String relativePath;
  final Widget placeholder;

  const _StoredAvatar({required this.relativePath, required this.placeholder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: ImageService().loadImage(relativePath),
      builder: (BuildContext context, AsyncSnapshot<File?> snapshot) {
        final File? file = snapshot.data;
        if (file == null) {
          return placeholder;
        }
        return Image.file(file, fit: BoxFit.cover);
      },
    );
  }
}

class _OrbitActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double angle;
  final _OrbitCorner corner;
  final VoidCallback onTap;

  const _OrbitActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.angle,
    required this.corner,
    required this.onTap,
  });
}

enum _OrbitCorner { topLeft, topRight, bottomLeft, bottomRight }

class _TangentActionBorder extends ShapeBorder {
  final _OrbitCorner corner;

  const _TangentActionBorder({required this.corner});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final double w = rect.width;
    final double h = rect.height;
    final Path path = Path();

    switch (corner) {
      case _OrbitCorner.topLeft:
        path
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.right, rect.top)
          ..arcToPoint(
            Offset(rect.left, rect.bottom),
            radius: Radius.circular(math.min(w, h)),
            clockwise: false,
          )
          ..close();
        return path;
      case _OrbitCorner.topRight:
        path
          ..moveTo(rect.right, rect.top)
          ..lineTo(rect.left, rect.top)
          ..arcToPoint(
            Offset(rect.right, rect.bottom),
            radius: Radius.circular(math.min(w, h)),
            clockwise: true,
          )
          ..close();
        return path;
      case _OrbitCorner.bottomLeft:
        path
          ..moveTo(rect.left, rect.bottom)
          ..lineTo(rect.right, rect.bottom)
          ..arcToPoint(
            Offset(rect.left, rect.top),
            radius: Radius.circular(math.min(w, h)),
            clockwise: true,
          )
          ..close();
        return path;
      case _OrbitCorner.bottomRight:
        path
          ..moveTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..arcToPoint(
            Offset(rect.right, rect.top),
            radius: Radius.circular(math.min(w, h)),
            clockwise: false,
          )
          ..close();
        return path;
    }
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) {
    return _TangentActionBorder(corner: corner);
  }
}

class _CreateProfileDialog extends StatefulWidget {
  const _CreateProfileDialog();

  @override
  State<_CreateProfileDialog> createState() => _CreateProfileDialogState();
}

class _CreateProfileDialogState extends State<_CreateProfileDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String _species = 'Dog';
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    final String name = _nameController.text.trim();
    final String breed = _breedController.text.trim();
    final double weight = double.tryParse(_weightController.text) ?? 0;

    if (name.isEmpty || breed.isEmpty || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Complete all fields to create a profile.')),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      await context.read<PetProfileProvider>().createDefaultProfile(
        name: name,
        species: _species,
        breed: breed,
        birthDate: DateTime.now(),
        weight: weight,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        context.tr('Create Pet Profile'),
        style: AppTextStyles.headline,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VoiceTextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: context.tr('Pet Name')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _species,
              items: const <String>['Dog', 'Cat', 'Other']
                  .map(
                    (String item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(context.tr(item)),
                    ),
                  )
                  .toList(),
              onChanged: _isCreating
                  ? null
                  : (String? value) {
                      if (value != null) {
                        setState(() => _species = value);
                      }
                    },
              decoration: InputDecoration(labelText: context.tr('Species')),
            ),
            const SizedBox(height: 12),
            VoiceTextField(
              controller: _breedController,
              decoration: InputDecoration(labelText: context.tr('Breed')),
            ),
            const SizedBox(height: 12),
            VoiceTextField(
              controller: _weightController,
              decoration: InputDecoration(labelText: context.tr('Weight (kg)')),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enableSpeechInput: false,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createProfile,
          child: Text(
            _isCreating ? context.tr('Creating...') : context.tr('Create'),
          ),
        ),
      ],
    );
  }
}
