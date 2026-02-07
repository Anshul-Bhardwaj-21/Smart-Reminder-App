import 'package:flutter/material.dart';

import '../viewmodels/reminder_viewmodel.dart';

class SuggestionCard extends StatelessWidget {
  final ReminderSuggestion suggestion;
  final VoidCallback onPrimaryAction;
  final VoidCallback onDismiss;

  const SuggestionCard({
    super.key,
    required this.suggestion,
    required this.onPrimaryAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(suggestion.type), color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: suggestion.secondaryActionLabel,
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  child: Text(suggestion.secondaryActionLabel),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onPrimaryAction,
                  child: Text(suggestion.primaryActionLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ReminderSuggestionType type) {
    switch (type) {
      case ReminderSuggestionType.adjustTime:
        return Icons.schedule;
      case ReminderSuggestionType.makeRecurring:
        return Icons.autorenew;
    }
  }
}

