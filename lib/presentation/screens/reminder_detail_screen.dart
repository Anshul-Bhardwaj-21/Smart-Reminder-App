import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/reminder_model.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/app_constants.dart';
import '../viewmodels/reminder_viewmodel.dart';

class ReminderDetailScreen extends StatelessWidget {
  final ReminderModel reminder;

  const ReminderDetailScreen({super.key, required this.reminder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor = AppTheme.getPriorityColor(reminder.priority);
    final isActive = reminder.status == ReminderStatus.pending || reminder.status == ReminderStatus.snoozed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteReminder(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: priorityColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          reminder.title,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  if (reminder.description != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      reminder.description!,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            icon: Icons.calendar_today,
            title: 'Date',
            value: DateTimeUtils.formatDate(reminder.dateTime),
          ),
          _buildInfoCard(
            context,
            icon: Icons.access_time,
            title: 'Time',
            value: DateTimeUtils.formatTime(reminder.dateTime),
          ),
          _buildInfoCard(
            context,
            icon: Icons.flag,
            title: 'Priority',
            value: reminder.priority.displayName,
            color: priorityColor,
          ),
          _buildInfoCard(
            context,
            icon: Icons.repeat,
            title: 'Recurrence',
            value: reminder.recurrence.displayName,
          ),
          _buildInfoCard(
            context,
            icon: Icons.info,
            title: 'Status',
            value: reminder.status.displayName,
          ),
          const SizedBox(height: 24),
          if (isActive) ...[
            ElevatedButton.icon(
              onPressed: () => _completeReminder(context),
              icon: const Icon(Icons.check),
              label: const Text('Mark as Completed'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _snoozeReminder(context),
              icon: const Icon(Icons.snooze),
              label: Text('Snooze (${AppConstants.snoozeMinutes} min)'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  Future<void> _completeReminder(BuildContext context) async {
    final viewModel = context.read<ReminderViewModel>();
    final success = await viewModel.completeReminder(reminder.id);

    if (success && context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder completed')),
      );
    }
  }

  Future<void> _snoozeReminder(BuildContext context) async {
    final viewModel = context.read<ReminderViewModel>();
    final success = await viewModel.snoozeReminder(
      reminder.id,
      minutes: AppConstants.snoozeMinutes,
    );

    if (success && context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder snoozed for ${AppConstants.snoozeMinutes} minutes'),
        ),
      );
    }
  }

  Future<void> _deleteReminder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to delete this reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final viewModel = context.read<ReminderViewModel>();
      final success = await viewModel.deleteReminder(reminder.id);

      if (success && context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder deleted')),
        );
      }
    }
  }
}
