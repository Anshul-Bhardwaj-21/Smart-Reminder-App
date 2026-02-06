import 'package:flutter/foundation.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/date_time_utils.dart';

/// Reminder model with null-safe implementation
@immutable
class ReminderModel {
  final String id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final Priority priority;
  final RecurrenceType recurrence;
  final ReminderStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? snoozedUntil;
  final int? customRecurrenceDays;
  final List<DateTime> completionHistory;

  const ReminderModel({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    required this.priority,
    required this.recurrence,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.snoozedUntil,
    this.customRecurrenceDays,
    this.completionHistory = const [],
  });

  /// Create a new reminder with default values
  factory ReminderModel.create({
    required String id,
    required String title,
    String? description,
    required DateTime dateTime,
    Priority priority = Priority.medium,
    RecurrenceType recurrence = RecurrenceType.none,
    int? customRecurrenceDays,
  }) {
    return ReminderModel(
      id: id,
      title: title,
      description: description,
      dateTime: dateTime,
      priority: priority,
      recurrence: recurrence,
      status: ReminderStatus.pending,
      createdAt: DateTime.now(),
      customRecurrenceDays: customRecurrenceDays,
      completionHistory: const [],
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': DateTimeUtils.toStorageFormat(dateTime),
      'priority': priority.value,
      'recurrence': recurrence.index,
      'status': status.index,
      'createdAt': DateTimeUtils.toStorageFormat(createdAt),
      'completedAt': completedAt != null ? DateTimeUtils.toStorageFormat(completedAt!) : null,
      'snoozedUntil': snoozedUntil != null ? DateTimeUtils.toStorageFormat(snoozedUntil!) : null,
      'customRecurrenceDays': customRecurrenceDays,
      'completionHistory': completionHistory.map(DateTimeUtils.toStorageFormat).toList(),
    };
  }

  /// Create from JSON
  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    final completionList = (json['completionHistory'] as List?)?.cast<String>() ?? [];

    return ReminderModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dateTime: DateTimeUtils.fromStorageFormat(json['dateTime'] as String) ?? DateTime.now(),
      priority: Priority.fromValue(json['priority'] as int),
      recurrence: RecurrenceType.values[json['recurrence'] as int],
      status: ReminderStatus.values[json['status'] as int],
      createdAt: DateTimeUtils.fromStorageFormat(json['createdAt'] as String) ?? DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTimeUtils.fromStorageFormat(json['completedAt'] as String)
          : null,
      snoozedUntil: json['snoozedUntil'] != null
          ? DateTimeUtils.fromStorageFormat(json['snoozedUntil'] as String)
          : null,
      customRecurrenceDays: json['customRecurrenceDays'] as int?,
      completionHistory: completionList
          .map((value) => DateTimeUtils.fromStorageFormat(value))
          .whereType<DateTime>()
          .toList(growable: false),
    );
  }

  /// Copy with modifications
  ReminderModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    Priority? priority,
    RecurrenceType? recurrence,
    ReminderStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? snoozedUntil,
    int? customRecurrenceDays,
    List<DateTime>? completionHistory,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      priority: priority ?? this.priority,
      recurrence: recurrence ?? this.recurrence,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      customRecurrenceDays: customRecurrenceDays ?? this.customRecurrenceDays,
      completionHistory: completionHistory ?? this.completionHistory,
    );
  }

  /// Check if reminder is due
  bool get isDue {
    if (status == ReminderStatus.completed || status == ReminderStatus.cancelled) {
      return false;
    }

    final now = DateTime.now();
    final effectiveTime = snoozedUntil ?? dateTime;
    return now.isAfter(effectiveTime);
  }

  /// Check if reminder is upcoming (within next hour)
  bool get isUpcoming {
    if (status == ReminderStatus.completed || status == ReminderStatus.cancelled) {
      return false;
    }

    final now = DateTime.now();
    final effectiveTime = snoozedUntil ?? dateTime;
    final oneHourLater = now.add(const Duration(hours: 1));
    return effectiveTime.isAfter(now) && effectiveTime.isBefore(oneHourLater);
  }

  /// Get next occurrence for recurring reminders
  DateTime? getNextOccurrence({DateTime? after}) {
    if (recurrence == RecurrenceType.none) return null;

    return DateTimeUtils.getNextOccurrenceAfter(
      base: dateTime,
      recurrence: recurrence,
      customDays: customRecurrenceDays,
      after: after ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
