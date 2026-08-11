import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../models/vaccine_reminder.dart';
import '../models/achievement_record.dart';
import '../providers/auth_provider.dart';
import '../providers/achievement_provider.dart';
import '../providers/growth_progress_provider.dart';
import '../providers/pet_profile_provider.dart';
import '../providers/vaccine_reminder_provider.dart';
import '../services/growth_service.dart';
import '../widgets/achievement_feedback_overlay.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/growth_feedback_overlay.dart';
import '../widgets/loading_widget.dart';
import '../widgets/reminder_form_dialog.dart';

/// Vaccine and health reminder management screen.
class VaccineReminderScreen extends StatefulWidget {
  const VaccineReminderScreen({super.key});

  @override
  State<VaccineReminderScreen> createState() => _VaccineReminderScreenState();
}

class _VaccineReminderScreenState extends State<VaccineReminderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReminders();
    });
  }

  Future<void> _loadReminders() async {
    final PetProfileProvider petProvider = context.read<PetProfileProvider>();
    final GrowthProgressProvider growthProvider = context.read<GrowthProgressProvider>();
    final VaccineReminderProvider reminderProvider = context.read<VaccineReminderProvider>();
    if (petProvider.hasProfile) {
      await growthProvider.loadProgress(
        petProvider.profile!.petId,
      );
      await reminderProvider.loadReminders(
        petProvider.profile!.petId,
      );
      final GrowthActivityResult? penaltyResult =
          await growthProvider.applyOverdueReminderPenalty(reminderProvider.reminders);
      if (!mounted) {
        return;
      }
      if (penaltyResult != null) {
        await GrowthFeedbackOverlay.showForResult(
          context,
          penaltyResult,
          label: context.tr('Missed reminder penalty'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminderProvider = context.watch<VaccineReminderProvider>();
    final petProvider = context.watch<PetProfileProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Vaccine & Reminders'))),
      floatingActionButton: petProvider.hasProfile
          ? FloatingActionButton(
              onPressed: () => _showAddReminderDialog(context),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: reminderProvider.isLoading
          ? Center(
              child: LoadingWidget(
                message: context.tr('Loading reminders...'),
              ),
            )
          : !petProvider.hasProfile
              ? EmptyStateWidget(
                  title: context.tr('No Pet Profile'),
                  message: context.tr(
                    'Create a pet profile first to manage health reminders.',
                  ),
                  actionLabel: context.tr('Create Profile'),
                  onAction: () => Navigator.pop(context),
                )
              : reminderProvider.reminders.isEmpty
                  ? EmptyStateWidget(
                      title: context.tr('No Reminders Yet'),
                      message: context.tr(
                        'Add vaccine, deworming, and checkup reminders for your pet.',
                      ),
                      actionLabel: context.tr('Add First Reminder'),
                      onAction: () => _showAddReminderDialog(context),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReminders,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: reminderProvider.reminders.length,
                        itemBuilder: (context, index) {
                          final reminder = reminderProvider.reminders[index];
                          return _ReminderCard(
                            reminder: reminder,
                            onComplete: () => _markCompleted(reminder.reminderId),
                            onEdit: () => _showEditReminderDialog(context, reminder),
                            onDelete: () => _confirmDelete(reminder.reminderId),
                          );
                        },
                      ),
                    ),
    );
  }

  void _markCompleted(String reminderId) async {
    final VaccineReminderProvider reminderProvider = context.read<VaccineReminderProvider>();
    final GrowthProgressProvider growthProvider = context.read<GrowthProgressProvider>();
    final AuthProvider authProvider = context.read<AuthProvider>();
    final AchievementProvider achievementProvider = context.read<AchievementProvider>();
    VaccineReminder? reminder;
    for (final VaccineReminder item in reminderProvider.reminders) {
      if (item.reminderId == reminderId) {
        reminder = item;
        break;
      }
    }

    await reminderProvider.markCompleted(reminderId);
    final GrowthActivityResult? result = await growthProvider.awardCheckupXp();
    if (!mounted) {
      return;
    }
    if (result != null && result.reward.freeAiUses > 0) {
      await authProvider.refreshCurrentUser();
      if (!mounted) {
        return;
      }
    }
    final String reminderName = reminder?.name ?? 'Care reminder';
    await achievementProvider.loadAchievements(
      context.read<PetProfileProvider>().profile!.petId,
    );
    final List<AchievementRecord> achievementUnlocks =
        await achievementProvider.evaluateReminderCompleted(
      reminderName: reminderName,
    );
    if (result != null) {
      achievementUnlocks.addAll(
        await achievementProvider.evaluateGrowth(
          level: result.currentLevel,
          streakDays: growthProvider.streakDays,
        ),
      );
    }
    if (!mounted) {
      return;
    }
    await GrowthFeedbackOverlay.showForResult(
      context,
      result,
      label: context.tr('Reminder completed'),
    );
    if (!mounted) {
      return;
    }
    if (achievementUnlocks.isNotEmpty) {
      AchievementFeedbackOverlay.showAll(
        context,
        achievementProvider,
        achievementUnlocks,
      );
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr('Reminder marked as completed! Next date updated.'),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _confirmDelete(String reminderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.tr('Delete Reminder?'),
          style: AppTextStyles.headline,
        ),
        content: Text(
          context.tr('This action cannot be undone.'),
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<VaccineReminderProvider>().deleteReminder(reminderId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
  }

  void _showAddReminderDialog(BuildContext context) {
    final petId = context.read<PetProfileProvider>().profile!.petId;
    showDialog(
      context: context,
      builder: (context) => ReminderFormDialog(petId: petId),
    );
  }

  void _showEditReminderDialog(BuildContext context, VaccineReminder reminder) {
    showDialog(
      context: context,
      builder: (context) => ReminderFormDialog(reminder: reminder),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final VaccineReminder reminder;
  final VoidCallback onComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReminderCard({
    required this.reminder,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = reminder.isOverdue && !reminder.isCompleted;
    final daysUntil = reminder.daysUntilNext;

    Color statusColor;
    String statusText;
    if (isOverdue) {
      statusColor = AppColors.error;
      statusText = 'Overdue';
    } else if (daysUntil != null && daysUntil <= 7) {
      statusColor = AppColors.warning;
      statusText = daysUntil <= 0 ? 'Due today' : '$daysUntil days left';
    } else {
      statusColor = AppColors.success;
      statusText = daysUntil != null ? '$daysUntil days left' : 'No date set';
    }

    IconData typeIcon;
    switch (reminder.reminderType) {
      case 'vaccine':
        typeIcon = Icons.vaccines;
      case 'deworm-internal':
      case 'deworm-external':
        typeIcon = Icons.medication;
      case 'checkup':
        typeIcon = Icons.medical_services;
      default:
        typeIcon = Icons.event_note;
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.name,
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatType(reminder.reminderType),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: AppTextStyles.label.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (reminder.nextDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.event, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Next: ${_formatDate(reminder.nextDate!)}',
                  style: AppTextStyles.caption,
                ),
                if (reminder.lastDate != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.history, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Last: ${_formatDate(reminder.lastDate!)}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ],
          if (reminder.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(reminder.notes, style: AppTextStyles.caption),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Mark Done'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 20),
                color: AppColors.textSecondary,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, size: 20),
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatType(String type) {
    switch (type) {
      case 'vaccine':
        return 'Vaccination';
      case 'deworm-internal':
        return 'Internal Deworming';
      case 'deworm-external':
        return 'External Deworming';
      case 'checkup':
        return 'Health Checkup';
      default:
        return type;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
