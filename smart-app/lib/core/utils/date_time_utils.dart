import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../constants/enums.dart';

/// Utility class for date and time operations
class DateTimeUtils {
  DateTimeUtils._();

  /// Format DateTime to display date string
  static String formatDate(DateTime dateTime) {
    return DateFormat(AppConstants.displayDateFormat).format(dateTime);
  }

  /// Format DateTime to display time string
  static String formatTime(DateTime dateTime) {
    return DateFormat(AppConstants.displayTimeFormat).format(dateTime);
  }

  /// Format DateTime to display date and time string
  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} ${formatTime(dateTime)}';
  }

  /// Format DateTime to storage format
  static String toStorageFormat(DateTime dateTime) {
    return DateFormat(AppConstants.dateTimeFormat).format(dateTime);
  }

  /// Parse DateTime from storage format
  static DateTime? fromStorageFormat(String dateTimeString) {
    try {
      return DateFormat(AppConstants.dateTimeFormat).parse(dateTimeString);
    } catch (e) {
      return null;
    }
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is tomorrow
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  /// Get relative date string (Today, Tomorrow, or formatted date)
  static String getRelativeDateString(DateTime date) {
    if (isToday(date)) {
      return 'Today';
    } else if (isTomorrow(date)) {
      return 'Tomorrow';
    } else {
      return formatDate(date);
    }
  }

  /// Check if DateTime is in the past
  static bool isPast(DateTime dateTime) {
    return dateTime.isBefore(DateTime.now());
  }

  /// Check if DateTime is in the future
  static bool isFuture(DateTime dateTime) {
    return dateTime.isAfter(DateTime.now());
  }

  /// Get next occurrence for daily recurrence
  static DateTime getNextDailyOccurrence(DateTime current) {
    return current.add(const Duration(days: 1));
  }

  /// Get next occurrence for weekly recurrence
  static DateTime getNextWeeklyOccurrence(DateTime current) {
    return current.add(const Duration(days: 7));
  }

  /// Get next occurrence for monthly recurrence
  static DateTime getNextMonthlyOccurrence(DateTime current) {
    return DateTime(
      current.year,
      current.month + 1,
      current.day,
      current.hour,
      current.minute,
    );
  }

  /// Combine date and time
  static DateTime combineDateTime(DateTime date, DateTime time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  /// Get the next occurrence after a reference time
  static DateTime? getNextOccurrenceAfter({
    required DateTime base,
    required RecurrenceType recurrence,
    int? customDays,
    required DateTime after,
  }) {
    if (recurrence == RecurrenceType.none) {
      return base.isAfter(after) ? base : null;
    }

    DateTime candidate = base;
    int safety = 0;

    while (!candidate.isAfter(after)) {
      safety++;
      if (safety > 5000) {
        return null;
      }

      switch (recurrence) {
        case RecurrenceType.daily:
          candidate = getNextDailyOccurrence(candidate);
          break;
        case RecurrenceType.weekly:
          candidate = getNextWeeklyOccurrence(candidate);
          break;
        case RecurrenceType.monthly:
          candidate = getNextMonthlyOccurrence(candidate);
          break;
        case RecurrenceType.custom:
          final interval = customDays ?? 1;
          candidate = candidate.add(Duration(days: interval));
          break;
        case RecurrenceType.none:
          break;
      }
    }

    return candidate;
  }

  /// Get next occurrences for custom recurrence
  static List<DateTime> getNextCustomOccurrences({
    required DateTime base,
    required int customDays,
    required int count,
    required DateTime after,
  }) {
    if (customDays <= 0 || count <= 0) return [];

    final occurrences = <DateTime>[];
    DateTime candidate = base;

    while (!candidate.isAfter(after)) {
      candidate = candidate.add(Duration(days: customDays));
    }

    for (int i = 0; i < count; i++) {
      occurrences.add(candidate);
      candidate = candidate.add(Duration(days: customDays));
    }

    return occurrences;
  }
}
