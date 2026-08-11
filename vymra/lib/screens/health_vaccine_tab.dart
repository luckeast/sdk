import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vaccine_reminder.dart';
import '../providers/pet_profile_provider.dart';
import '../providers/vaccine_reminder_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/loading_widget.dart';
import '../widgets/reminder_form_dialog.dart';

/// Vaccine reminders tab view embedded in the HealthScreen.
class HealthVaccineTabView extends StatefulWidget {
  const HealthVaccineTabView({super.key});

  @override
  State<HealthVaccineTabView> createState() => _HealthVaccineTabViewState();
}

class _HealthVaccineTabViewState extends State<HealthVaccineTabView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReminders();
    });
  }

  Future<void> _loadReminders() async {
    final petProvider = context.read<PetProfileProvider>();
    final reminderProvider = context.read<VaccineReminderProvider>();
    if (petProvider.hasProfile) {
      await reminderProvider.loadReminders(petProvider.profile!.petId);
    }
  }

  void _showAddDialog() {
    final petId = context.read<PetProfileProvider>().profile?.petId;
    if (petId == null) return;
    showDialog(
      context: context,
      builder: (_) => ReminderFormDialog(petId: petId),
    );
  }

  void _showEditDialog(VaccineReminder reminder) {
    showDialog(
      context: context,
      builder: (_) => ReminderFormDialog(reminder: reminder),
    );
  }

  Future<void> _markCompleted(String reminderId) async {
    await context.read<VaccineReminderProvider>().markCompleted(reminderId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reminder marked as completed! Next date updated.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _confirmDelete(String reminderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Reminder?', style: AppTextStyles.headline),
        content: Text(
          'This action cannot be undone.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<VaccineReminderProvider>().deleteReminder(reminderId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reminderProvider = context.watch<VaccineReminderProvider>();

    if (reminderProvider.isLoading) {
      return const Center(
        child: LoadingWidget(message: 'Loading reminders...'),
      );
    }

    if (reminderProvider.reminders.isEmpty) {
      return EmptyStateWidget(
        title: 'No Reminders Yet',
        message: 'Add vaccine, deworming, and checkup reminders for your pet.',
        actionLabel: 'Add First Reminder',
        onAction: _showAddDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReminders,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        itemCount: reminderProvider.reminders.length,
        itemBuilder: (context, index) {
          final reminder = reminderProvider.reminders[index];
          return _ReminderCard(
            reminder: reminder,
            onComplete: () => _markCompleted(reminder.reminderId),
            onEdit: () => _showEditDialog(reminder),
            onDelete: () => _confirmDelete(reminder.reminderId),
          );
        },
      ),
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
