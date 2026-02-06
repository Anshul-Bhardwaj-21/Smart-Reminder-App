/// Priority levels for reminders
enum Priority {
  low,
  medium,
  high;

  String get displayName {
    switch (this) {
      case Priority.low:
        return 'Low';
      case Priority.medium:
        return 'Medium';
      case Priority.high:
        return 'High';
    }
  }

  int get value {
    switch (this) {
      case Priority.low:
        return 0;
      case Priority.medium:
        return 1;
      case Priority.high:
        return 2;
    }
  }

  static Priority fromValue(int value) {
    switch (value) {
      case 0:
        return Priority.low;
      case 1:
        return Priority.medium;
      case 2:
        return Priority.high;
      default:
        return Priority.medium;
    }
  }
}

/// Recurrence patterns for reminders
enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
  custom;

  String get displayName {
    switch (this) {
      case RecurrenceType.none:
        return 'None';
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
      case RecurrenceType.custom:
        return 'Custom';
    }
  }
}

/// Status of a reminder
enum ReminderStatus {
  pending,
  completed,
  snoozed,
  cancelled;

  String get displayName {
    switch (this) {
      case ReminderStatus.pending:
        return 'Pending';
      case ReminderStatus.completed:
        return 'Completed';
      case ReminderStatus.snoozed:
        return 'Snoozed';
      case ReminderStatus.cancelled:
        return 'Cancelled';
    }
  }
}
