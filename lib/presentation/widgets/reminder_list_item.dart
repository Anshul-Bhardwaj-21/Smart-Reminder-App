import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/reminder_model.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../viewmodels/reminder_viewmodel.dart';

/// List item widget for displaying a reminder
class ReminderListItem extends StatelessWidget {
  final ReminderModel reminder;
  final VoidCallback onTap;

  const ReminderListItem({
    super.key,
    required this.reminder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor = AppTheme.getPriorityColor(reminder.priority);
    final isActive = reminder.status == ReminderStatus.pending || reminder.status == ReminderStatus.snoozed;
    final isOverdue = reminder.isDue && isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            decoration: reminder.status == ReminderStatus.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (reminder.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            reminder.description!,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isActive)
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () {
                        context.read<ReminderViewModel>().completeReminder(reminder.id);
                      },
                    )
                  else if (reminder.status == ReminderStatus.completed)
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(
                    context,
                    icon: Icons.calendar_today,
                    label: DateTimeUtils.getRelativeDateString(reminder.dateTime),
                    color: isOverdue ? Colors.red : null,
                  ),
                  _buildChip(
                    context,
                    icon: Icons.access_time,
                    label: DateTimeUtils.formatTime(reminder.dateTime),
                  ),
                  if (reminder.recurrence != RecurrenceType.none)
                    _buildChip(
                      context,
                      icon: Icons.repeat,
                      label: reminder.recurrence.displayName,
                    ),
                  if (reminder.status == ReminderStatus.snoozed && reminder.snoozedUntil != null)
                    _buildChip(
                      context,
                      icon: Icons.snooze,
                      label: 'Snoozed until ${DateTimeUtils.formatTime(reminder.snoozedUntil!)}',
                    ),
                  _buildChip(
                    context,
                    icon: Icons.flag,
                    label: reminder.priority.displayName,
                    color: priorityColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.surfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: chipColor),
          ),
        ],
      ),
    );
  }
}
