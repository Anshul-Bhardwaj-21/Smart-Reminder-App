import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/reminder_model.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
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
    final isLocationReminder = reminder.triggerType.isLocation && reminder.location != null;
    final isActive = reminder.status == ReminderStatus.pending || reminder.status == ReminderStatus.snoozed;
    final isOverdue = reminder.isDue && isActive;

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: isActive ? DismissDirection.horizontal : DismissDirection.none,
      background: _buildSwipeBackground(
        context,
        alignment: Alignment.centerLeft,
        color: Colors.green,
        icon: Icons.check,
        label: 'Complete',
      ),
      secondaryBackground: _buildSwipeBackground(
        context,
        alignment: Alignment.centerRight,
        color: theme.colorScheme.secondary,
        icon: Icons.more_horiz,
        label: 'Actions',
      ),
      confirmDismiss: (direction) => _handleSwipe(context, direction),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  priorityColor.withValues(alpha: 0.10),
                  theme.colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
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
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            final success =
                                await context.read<ReminderViewModel>().completeReminder(reminder.id);
                            if (!success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to complete reminder')),
                              );
                            }
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
                      if (!isLocationReminder) ...[
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
                      ] else ...[
                        _buildChip(
                          context,
                          icon: Icons.place,
                          label:
                              '${reminder.triggerType == ReminderTriggerType.locationExit ? 'Leave' : 'Arrive'} ${reminder.location!.name}',
                        ),
                        _buildChip(
                          context,
                          icon: Icons.my_location,
                          label: '${reminder.location!.radiusMeters.round()} m radius',
                        ),
                      ],
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
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(
    BuildContext context, {
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: color.withValues(alpha: 0.85),
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<bool> _handleSwipe(BuildContext context, DismissDirection direction) async {
    final viewModel = context.read<ReminderViewModel>();

    if (direction == DismissDirection.startToEnd) {
      HapticFeedback.mediumImpact();
      final success = await viewModel.completeReminder(reminder.id);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to complete reminder')),
        );
      }
      return false;
    }

    HapticFeedback.selectionClick();

    final action = await showModalBottomSheet<_ReminderSwipeAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.snooze),
                title: Text('Snooze (${AppConstants.snoozeMinutes} min)'),
                onTap: () => Navigator.pop(context, _ReminderSwipeAction.snooze),
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                title: Text(
                  'Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.pop(context, _ReminderSwipeAction.delete),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!context.mounted) return false;
    if (action == null) return false;

    if (action == _ReminderSwipeAction.snooze) {
      HapticFeedback.lightImpact();
      final success = await viewModel.snoozeReminder(reminder.id, minutes: AppConstants.snoozeMinutes);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to snooze reminder')),
        );
      }
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: const Text('This cannot be undone.'),
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

    if (!context.mounted) return false;
    if (confirmed != true) return false;

    HapticFeedback.heavyImpact();
    final success = await viewModel.deleteReminder(reminder.id);
    if (!context.mounted) return false;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete reminder')),
      );
    }

    return false;
  }

  Widget _buildChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.surfaceContainerHighest;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withValues(alpha: 0.50)),
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

enum _ReminderSwipeAction {
  snooze,
  delete,
}
