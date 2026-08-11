import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../models/vaccine_reminder.dart';
import '../providers/vaccine_reminder_provider.dart';
import '../theme/app_theme.dart';
import 'voice_text_field.dart';

/// Form dialog for adding or editing a vaccine/health reminder.
class ReminderFormDialog extends StatefulWidget {
  final String? petId;
  final VaccineReminder? reminder;

  const ReminderFormDialog({super.key, this.petId, this.reminder});

  @override
  State<ReminderFormDialog> createState() => _ReminderFormDialogState();
}

class _ReminderFormDialogState extends State<ReminderFormDialog> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _intervalController = TextEditingController();
  String _reminderType = 'vaccine';
  DateTime? _lastDate;
  DateTime? _nextDate;
  bool _isSaving = false;

  final List<Map<String, String>> _reminderTypes = [
    {'value': 'vaccine', 'label': 'Vaccination'},
    {'value': 'deworm-internal', 'label': 'Internal Deworming'},
    {'value': 'deworm-external', 'label': 'External Deworming'},
    {'value': 'checkup', 'label': 'Health Checkup'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.reminder != null) {
      _nameController.text = widget.reminder!.name;
      _notesController.text = widget.reminder!.notes;
      _intervalController.text = widget.reminder!.intervalDays.toString();
      _reminderType = widget.reminder!.reminderType;
      _lastDate = widget.reminder!.lastDate;
      _nextDate = widget.reminder!.nextDate;
    } else {
      _intervalController.text = '365';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _save() async {
    final name = _nameController.text.trim();
    final interval = int.tryParse(_intervalController.text) ?? 0;

    if (name.isEmpty) {
      _showError(context.tr('Please enter a reminder name'));
      return;
    }
    if (interval <= 0) {
      _showError(context.tr('Please enter a valid interval'));
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final lastDate = _lastDate ?? now;
    final nextDate = _nextDate ?? lastDate.add(Duration(days: interval));

    final reminder = VaccineReminder(
      reminderId:
          widget.reminder?.reminderId ??
          'reminder_${now.millisecondsSinceEpoch}',
      petId: widget.reminder?.petId ?? widget.petId!,
      reminderType: _reminderType,
      name: name,
      lastDate: lastDate,
      nextDate: nextDate,
      intervalDays: interval,
      notes: _notesController.text.trim(),
      isActive: true,
      isCompleted: false,
    );

    if (widget.reminder != null) {
      await context.read<VaccineReminderProvider>().updateReminder(reminder);
    } else {
      await context.read<VaccineReminderProvider>().addReminder(reminder);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate(bool isLastDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isLastDate) {
          _lastDate = picked;
          final interval = int.tryParse(_intervalController.text) ?? 365;
          _nextDate = picked.add(Duration(days: interval));
        } else {
          _nextDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.reminder != null;

    return AlertDialog(
      title: Text(
        isEditing
            ? context.tr('Edit Reminder')
            : context.tr('Add Reminder'),
        style: AppTextStyles.headline,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VoiceTextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.tr('Reminder Name'),
              ),
              enabled: !_isSaving,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _reminderType,
              decoration: InputDecoration(labelText: context.tr('Type')),
              items: _reminderTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t['value'],
                      child: Text(context.tr(t['label']!)),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (v) => setState(() => _reminderType = v!),
            ),
            const SizedBox(height: 12),
            VoiceTextField(
              controller: _intervalController,
              decoration: InputDecoration(
                labelText: context.tr('Interval (days)'),
                hintText: context.tr('e.g., 365 for yearly'),
              ),
              keyboardType: TextInputType.number,
              enableSpeechInput: false,
              enabled: !_isSaving,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _isSaving ? null : () => _pickDate(true),
              child: InputDecorator(
                decoration: InputDecoration(labelText: context.tr('Last Date')),
                child: Text(
                  _lastDate != null
                      ? '${_lastDate!.year}/${_lastDate!.month.toString().padLeft(2, '0')}/${_lastDate!.day.toString().padLeft(2, '0')}'
                      : context.tr('Select date'),
                  style: _lastDate != null
                      ? AppTextStyles.body
                      : AppTextStyles.caption.copyWith(
                          color: AppColors.textDisabled,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _isSaving ? null : () => _pickDate(false),
              child: InputDecorator(
                decoration: InputDecoration(labelText: context.tr('Next Date')),
                child: Text(
                  _nextDate != null
                      ? '${_nextDate!.year}/${_nextDate!.month.toString().padLeft(2, '0')}/${_nextDate!.day.toString().padLeft(2, '0')}'
                      : context.tr('Auto-calculated'),
                  style: _nextDate != null
                      ? AppTextStyles.body
                      : AppTextStyles.caption.copyWith(
                          color: AppColors.textDisabled,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            VoiceTextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: context.tr('Notes (optional)'),
                hintText: context.tr('Brand, vet name, etc.'),
              ),
              maxLines: 2,
              enabled: !_isSaving,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  isEditing ? context.tr('Update') : context.tr('Save'),
                ),
        ),
      ],
    );
  }
}
