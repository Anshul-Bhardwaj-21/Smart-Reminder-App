import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/date_time_utils.dart';
import '../../data/models/reminder_model.dart';

class TodayHeader extends StatelessWidget {
  final ReminderModel? nextReminder;

  const TodayHeader({
    super.key,
    required this.nextReminder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greetingFor(now),
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, MMM d').format(now),
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildNextCard(context),
        ),
      ],
    );
  }

  Widget _buildNextCard(BuildContext context) {
    final theme = Theme.of(context);

    if (nextReminder == null) {
      return Card(
        key: const ValueKey('no_next'),
        child: ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('No upcoming reminders'),
          subtitle: const Text('Add one to get started'),
        ),
      );
    }

    final effectiveTime = nextReminder!.snoozedUntil ?? nextReminder!.dateTime;

    return Card(
      key: ValueKey('next_${nextReminder!.id}'),
      child: ListTile(
        leading: const Icon(Icons.schedule),
        title: const Text('Next up'),
        subtitle: Text(
          '${nextReminder!.title} • ${DateTimeUtils.getRelativeDateString(effectiveTime)} at ${DateTimeUtils.formatTime(effectiveTime)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.chevron_right, color: theme.colorScheme.outline),
      ),
    );
  }

  String _greetingFor(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

