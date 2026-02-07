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
  final ReminderTriggerType triggerType;
  final ReminderLocation? location;
  final ReminderStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? snoozedUntil;
  final int? customRecurrenceDays;
  final List<DateTime> completionHistory;
  final int snoozeCount;
  final List<int> completionDelayMinutesHistory;

  const ReminderModel({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    required this.priority,
    required this.recurrence,
    this.triggerType = ReminderTriggerType.time,
    this.location,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.snoozedUntil,
    this.customRecurrenceDays,
    this.completionHistory = const [],
    this.snoozeCount = 0,
    this.completionDelayMinutesHistory = const [],
  });

  /// Create a new reminder with default values
  factory ReminderModel.create({
    required String id,
    required String title,
    String? description,
    required DateTime dateTime,
    Priority priority = Priority.medium,
    RecurrenceType recurrence = RecurrenceType.none,
    ReminderTriggerType triggerType = ReminderTriggerType.time,
    ReminderLocation? location,
    int? customRecurrenceDays,
  }) {
    return ReminderModel(
      id: id,
      title: title,
      description: description,
      dateTime: dateTime,
      priority: priority,
      recurrence: recurrence,
      triggerType: triggerType,
      location: location,
      status: ReminderStatus.pending,
      createdAt: DateTime.now(),
      customRecurrenceDays: customRecurrenceDays,
      completionHistory: const [],
      snoozeCount: 0,
      completionDelayMinutesHistory: const [],
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
      'triggerType': triggerType.storageValue,
      'location': location?.toJson(),
      'status': status.index,
      'createdAt': DateTimeUtils.toStorageFormat(createdAt),
      'completedAt': completedAt != null ? DateTimeUtils.toStorageFormat(completedAt!) : null,
      'snoozedUntil': snoozedUntil != null ? DateTimeUtils.toStorageFormat(snoozedUntil!) : null,
      'customRecurrenceDays': customRecurrenceDays,
      'completionHistory': completionHistory.map(DateTimeUtils.toStorageFormat).toList(),
      'snoozeCount': snoozeCount,
      'completionDelayMinutesHistory': completionDelayMinutesHistory,
    };
  }

  /// Create from JSON
  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    final completionList = (json['completionHistory'] as List?)?.cast<String>() ?? [];
    final delaysRaw = json['completionDelayMinutesHistory'] as List?;
    final delays = (delaysRaw ?? const [])
        .whereType<num>()
        .map((value) => value.toInt())
        .toList(growable: false);
    final locationJson = json['location'];

    return ReminderModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dateTime: DateTimeUtils.fromStorageFormat(json['dateTime'] as String) ?? DateTime.now(),
      priority: Priority.fromValue(json['priority'] as int),
      recurrence: RecurrenceType.values[json['recurrence'] as int],
      triggerType: ReminderTriggerType.fromStorageValue(json['triggerType'] as String?),
      location: locationJson is Map ? ReminderLocation.fromJson(Map<String, dynamic>.from(locationJson)) : null,
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
      snoozeCount: (json['snoozeCount'] as num?)?.toInt() ?? 0,
      completionDelayMinutesHistory: delays,
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
    ReminderTriggerType? triggerType,
    ReminderLocation? location,
    ReminderStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? snoozedUntil,
    int? customRecurrenceDays,
    List<DateTime>? completionHistory,
    int? snoozeCount,
    List<int>? completionDelayMinutesHistory,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      priority: priority ?? this.priority,
      recurrence: recurrence ?? this.recurrence,
      triggerType: triggerType ?? this.triggerType,
      location: location ?? this.location,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      customRecurrenceDays: customRecurrenceDays ?? this.customRecurrenceDays,
      completionHistory: completionHistory ?? this.completionHistory,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      completionDelayMinutesHistory: completionDelayMinutesHistory ?? this.completionDelayMinutesHistory,
    );
  }

  /// Check if reminder is due
  bool get isDue {
    if (triggerType != ReminderTriggerType.time) {
      return false;
    }

    if (status == ReminderStatus.completed || status == ReminderStatus.cancelled) {
      return false;
    }

    final now = DateTime.now();
    final effectiveTime = snoozedUntil ?? dateTime;
    return now.isAfter(effectiveTime);
  }

  /// Check if reminder is upcoming (within next hour)
  bool get isUpcoming {
    if (triggerType != ReminderTriggerType.time) {
      return false;
    }

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

@immutable
class ReminderLocation {
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const ReminderLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
    };
  }

  factory ReminderLocation.fromJson(Map<String, dynamic> json) {
    return ReminderLocation(
      name: (json['name'] as String?)?.trim().isNotEmpty == true ? json['name'] as String : 'Location',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 150,
    );
  }
}
