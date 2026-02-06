import '../constants/enums.dart';
import '../constants/app_constants.dart';
import 'date_time_utils.dart';

/// Deterministic text parser for extracting reminder information from natural language
/// NO FAKE AI - Uses regex and pattern matching
class TextParser {
  TextParser._();

  /// Parse reminder details from text input
  static ParsedReminder parseReminderText(String input) {
    final cleanInput = input.trim().toLowerCase();

    final recurrenceResult = _extractRecurrence(cleanInput);

    return ParsedReminder(
      title: _extractTitle(cleanInput, input),
      dateTime: _extractDateTime(cleanInput),
      recurrence: recurrenceResult.recurrence,
      customRecurrenceDays: recurrenceResult.customDays,
      priority: _extractPriority(cleanInput),
    );
  }

  /// Extract title by removing time/date/recurrence keywords
  static String _extractTitle(String cleanInput, String originalInput) {
    String title = cleanInput
        .replaceAll(RegExp(r'\b(remind me to|reminder to|remind|remember to)\b'), '')
        .replaceAll(RegExp(r'\b(every day|daily|every week|weekly|every month|monthly)\b'), '')
        .replaceAll(RegExp(r'\b(every\s+\d+\s+days?)\b'), '')
        .replaceAll(RegExp(r'\b(at|on|tomorrow|today|tonight)\b'), '')
        .replaceAll(RegExp(r'\b(morning|afternoon|evening|night)\b'), '')
        .replaceAll(RegExp(r'\b(urgent|important|high priority|low priority|normal)\b'), '')
        .replaceAll(RegExp(r'\b\d{1,2}:\d{2}\s*(am|pm)?\b'), '')
        .replaceAll(RegExp(r'\b\d{1,2}\s*(am|pm)\b'), '')
        .replaceAll(RegExp(r'\b\d{1,2}[/-]\d{1,2}([/-]\d{2,4})?\b'), '')
        .trim();

    if (title.isEmpty || title.length < 3) {
      title = originalInput.trim();
    }

    if (title.isNotEmpty) {
      title = title[0].toUpperCase() + title.substring(1);
    }

    return title;
  }

  /// Extract date and time from text
  static DateTime? _extractDateTime(String input) {
    DateTime? extractedDate;
    DateTime? extractedTime;

    if (input.contains('today')) {
      extractedDate = DateTime.now();
    } else if (input.contains('tomorrow')) {
      extractedDate = DateTime.now().add(const Duration(days: 1));
    } else if (input.contains('tonight')) {
      extractedDate = DateTime.now();
      extractedTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        AppConstants.defaultNightHour,
        AppConstants.defaultMinute,
      );
    }

    final datePattern = RegExp(r'(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?');
    final dateMatch = datePattern.firstMatch(input);
    if (dateMatch != null) {
      final month = int.tryParse(dateMatch.group(1)!);
      final day = int.tryParse(dateMatch.group(2)!);
      final yearStr = dateMatch.group(3);
      int year = DateTime.now().year;

      if (yearStr != null) {
        year = int.tryParse(yearStr)!;
        if (year < 100) {
          year += 2000;
        }
      }

      if (month != null && day != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        extractedDate = DateTime(year, month, day);
      }
    }

    final timePattern = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)');
    final timeMatch = timePattern.firstMatch(input);
    if (timeMatch != null) {
      int hour = int.tryParse(timeMatch.group(1)!) ?? 0;
      final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      final period = timeMatch.group(3);

      if (period == 'pm' && hour != 12) {
        hour += 12;
      } else if (period == 'am' && hour == 12) {
        hour = 0;
      }

      final now = DateTime.now();
      extractedTime = DateTime(now.year, now.month, now.day, hour, minute);
    }

    if (extractedTime == null) {
      final time24Pattern = RegExp(r'(\d{1,2}):(\d{2})');
      final time24Match = time24Pattern.firstMatch(input);
      if (time24Match != null) {
        final hour = int.tryParse(time24Match.group(1)!) ?? 0;
        final minute = int.tryParse(time24Match.group(2)!) ?? 0;
        final now = DateTime.now();
        extractedTime = DateTime(now.year, now.month, now.day, hour, minute);
      }
    }

    if (extractedTime == null) {
      if (input.contains('morning')) {
        final now = DateTime.now();
        extractedTime = DateTime(now.year, now.month, now.day, AppConstants.defaultMorningHour, AppConstants.defaultMinute);
      } else if (input.contains('afternoon')) {
        final now = DateTime.now();
        extractedTime = DateTime(now.year, now.month, now.day, AppConstants.defaultAfternoonHour, AppConstants.defaultMinute);
      } else if (input.contains('evening')) {
        final now = DateTime.now();
        extractedTime = DateTime(now.year, now.month, now.day, AppConstants.defaultEveningHour, AppConstants.defaultMinute);
      } else if (input.contains('night')) {
        final now = DateTime.now();
        extractedTime = DateTime(now.year, now.month, now.day, AppConstants.defaultNightHour, AppConstants.defaultMinute);
      }
    }

    if (extractedDate != null && extractedTime != null) {
      return DateTimeUtils.combineDateTime(extractedDate, extractedTime);
    } else if (extractedDate != null) {
      return DateTime(extractedDate.year, extractedDate.month, extractedDate.day, AppConstants.defaultMorningHour, AppConstants.defaultMinute);
    } else if (extractedTime != null) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, extractedTime.hour, extractedTime.minute);
    }

    return null;
  }

  /// Extract recurrence pattern from text
  static _RecurrenceResult _extractRecurrence(String input) {
    final customMatch = RegExp(r'every\s+(\d+)\s+days?').firstMatch(input);
    if (customMatch != null) {
      final days = int.tryParse(customMatch.group(1) ?? '');
      if (days != null && days > 0) {
        return _RecurrenceResult(RecurrenceType.custom, days);
      }
    }

    if (input.contains('every day') || input.contains('daily')) {
      return _RecurrenceResult(RecurrenceType.daily, null);
    } else if (input.contains('every week') || input.contains('weekly')) {
      return _RecurrenceResult(RecurrenceType.weekly, null);
    } else if (input.contains('every month') || input.contains('monthly')) {
      return _RecurrenceResult(RecurrenceType.monthly, null);
    }

    return _RecurrenceResult(RecurrenceType.none, null);
  }

  /// Extract priority from text
  static Priority _extractPriority(String input) {
    if (input.contains('urgent') || input.contains('important') || input.contains('high priority')) {
      return Priority.high;
    } else if (input.contains('low priority')) {
      return Priority.low;
    } else if (input.contains('normal')) {
      return Priority.medium;
    }
    return Priority.medium;
  }
}

class _RecurrenceResult {
  final RecurrenceType recurrence;
  final int? customDays;

  const _RecurrenceResult(this.recurrence, this.customDays);
}

/// Result of parsing reminder text
class ParsedReminder {
  final String title;
  final DateTime? dateTime;
  final RecurrenceType recurrence;
  final int? customRecurrenceDays;
  final Priority priority;

  ParsedReminder({
    required this.title,
    this.dateTime,
    required this.recurrence,
    required this.customRecurrenceDays,
    required this.priority,
  });
}
