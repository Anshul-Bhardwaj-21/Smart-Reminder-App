import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show NotificationResponse;
import '../../data/models/reminder_model.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../core/location/geofence_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/utils/logger.dart';

/// ViewModel for managing reminders
/// Handles business logic and state management
class ReminderViewModel extends ChangeNotifier {
  final ReminderRepository _repository;
  final NotificationService _notificationService;
  final GeofenceService _geofenceService;

  List<ReminderModel> _reminders = [];
  bool _isLoading = false;
  String? _error;
  List<ReminderSuggestion> _suggestions = const [];
  final Set<String> _dismissedSuggestionIds = <String>{};

  ReminderViewModel(this._repository, this._notificationService, this._geofenceService);

  // Getters
  List<ReminderModel> get reminders => _reminders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ReminderSuggestion> get suggestions => _suggestions;

  List<ReminderModel> get pendingReminders => _reminders
      .where((r) => r.status == ReminderStatus.pending || r.status == ReminderStatus.snoozed)
      .toList();

  List<ReminderModel> get completedReminders =>
      _reminders.where((r) => r.status == ReminderStatus.completed).toList();

  List<ReminderModel> get dueReminders => _reminders.where((r) => r.isDue).toList();

  Future<void> initialize() async {
    await loadReminders();
    await rescheduleAllNotifications();
    await rescheduleAllGeofences();
  }

  /// Load all reminders
  Future<void> loadReminders() async {
    _setLoading(true);
    _clearError();

    try {
      _reminders = await _repository.getAllReminders();
      _updateSuggestions();
      Logger.info('Loaded ${_reminders.length} reminders', 'ReminderViewModel');
      notifyListeners();
    } catch (e, stackTrace) {
      _setError('Failed to load reminders');
      Logger.error('Failed to load reminders', e, stackTrace, 'ReminderViewModel');
    } finally {
      _setLoading(false);
    }
  }

  /// Add new reminder
  Future<bool> addReminder(ReminderModel reminder) async {
    _clearError();

    try {
      final success = await _repository.saveReminder(reminder);

      if (success) {
        await _refreshRemindersAndReschedule();
        Logger.info('Added reminder: ${reminder.id}', 'ReminderViewModel');
        return true;
      } else {
        _setError('Failed to add reminder');
        return false;
      }
    } catch (e, stackTrace) {
      _setError('Failed to add reminder');
      Logger.error('Failed to add reminder', e, stackTrace, 'ReminderViewModel');
      return false;
    }
  }

  /// Update existing reminder
  Future<bool> updateReminder(ReminderModel reminder) async {
    _clearError();

    try {
      final success = await _repository.saveReminder(reminder);

      if (success) {
        await _refreshRemindersAndReschedule();
        Logger.info('Updated reminder: ${reminder.id}', 'ReminderViewModel');
        return true;
      } else {
        _setError('Failed to update reminder');
        return false;
      }
    } catch (e, stackTrace) {
      _setError('Failed to update reminder');
      Logger.error('Failed to update reminder', e, stackTrace, 'ReminderViewModel');
      return false;
    }
  }

  /// Delete reminder
  Future<bool> deleteReminder(String id) async {
    _clearError();

    try {
      final success = await _repository.deleteReminder(id);

      if (success) {
        await _refreshRemindersAndReschedule();
        Logger.info('Deleted reminder: $id', 'ReminderViewModel');
        return true;
      } else {
        _setError('Failed to delete reminder');
        return false;
      }
    } catch (e, stackTrace) {
      _setError('Failed to delete reminder');
      Logger.error('Failed to delete reminder', e, stackTrace, 'ReminderViewModel');
      return false;
    }
  }

  /// Mark reminder as completed
  Future<bool> completeReminder(String id) async {
    _clearError();

    try {
      final reminder = _findReminderById(id);
      if (reminder == null) {
        _setError('Reminder not found');
        return false;
      }

      final now = DateTime.now();
      ReminderModel updatedReminder;
      final scheduledTime = (reminder.status == ReminderStatus.snoozed && reminder.snoozedUntil != null)
          ? reminder.snoozedUntil!
          : reminder.dateTime;
      final delayMinutes = now.isAfter(scheduledTime) ? now.difference(scheduledTime).inMinutes : 0;
      final updatedDelayHistory = delayMinutes > 0
          ? [...reminder.completionDelayMinutesHistory, delayMinutes]
          : reminder.completionDelayMinutesHistory;

      if (reminder.recurrence != RecurrenceType.none) {
        final nextOccurrence = reminder.getNextOccurrence(after: now);
        if (nextOccurrence == null) {
          _setError('Failed to calculate next occurrence');
          return false;
        }

        updatedReminder = reminder.copyWith(
          dateTime: nextOccurrence,
          status: ReminderStatus.pending,
          completedAt: now,
          snoozedUntil: null,
          completionHistory: [...reminder.completionHistory, now],
          completionDelayMinutesHistory: updatedDelayHistory,
        );
      } else {
        updatedReminder = reminder.copyWith(
          status: ReminderStatus.completed,
          completedAt: now,
          snoozedUntil: null,
          completionHistory: [...reminder.completionHistory, now],
          completionDelayMinutesHistory: updatedDelayHistory,
        );
      }

      final success = await _repository.saveReminder(updatedReminder);
      if (!success) {
        _setError('Failed to complete reminder');
        return false;
      }

      await _refreshRemindersAndReschedule();
      Logger.info('Completed reminder: $id', 'ReminderViewModel');
      return true;
    } catch (e, stackTrace) {
      _setError('Failed to complete reminder');
      Logger.error('Failed to complete reminder', e, stackTrace, 'ReminderViewModel');
      return false;
    }
  }

  /// Snooze reminder
  Future<bool> snoozeReminder(String id, {int minutes = AppConstants.snoozeMinutes}) async {
    _clearError();

    try {
      final reminder = _findReminderById(id);
      if (reminder == null) {
        _setError('Reminder not found');
        return false;
      }

      final duration = Duration(minutes: minutes);
      final snoozedUntil = DateTime.now().add(duration);

      final updatedReminder = reminder.copyWith(
        status: ReminderStatus.snoozed,
        snoozedUntil: snoozedUntil,
        snoozeCount: reminder.snoozeCount + 1,
      );

      final success = await _repository.saveReminder(updatedReminder);
      if (!success) {
        _setError('Failed to snooze reminder');
        return false;
      }

      await _refreshRemindersAndReschedule();
      Logger.info('Snoozed reminder: $id for $minutes minutes', 'ReminderViewModel');
      return true;
    } catch (e, stackTrace) {
      _setError('Failed to snooze reminder');
      Logger.error('Failed to snooze reminder', e, stackTrace, 'ReminderViewModel');
      return false;
    }
  }

  Future<void> handleNotificationResponse(NotificationResponse response) async {
    if (response.actionId == AppConstants.snoozeActionId) {
      final reminderId = response.payload;
      if (reminderId != null && reminderId.isNotEmpty) {
        await snoozeReminder(reminderId, minutes: AppConstants.snoozeMinutes);
      }
    }
  }

  Future<GeofencePermissionStatus> requestGeofencePermissions() async {
    return _geofenceService.requestPermissions();
  }

  void dismissSuggestion(String suggestionId) {
    _dismissedSuggestionIds.add(suggestionId);
    _updateSuggestions();
    notifyListeners();
  }

  Future<void> applySuggestion(ReminderSuggestion suggestion) async {
    switch (suggestion.type) {
      case ReminderSuggestionType.adjustTime:
        final reminderId = suggestion.reminderId;
        final shiftMinutes = suggestion.shiftMinutes;
        if (reminderId == null || shiftMinutes == null || shiftMinutes <= 0) return;

        final reminder = _findReminderById(reminderId);
        if (reminder == null) return;

        final now = DateTime.now();
        var updatedDateTime = reminder.dateTime.add(Duration(minutes: shiftMinutes));
        if (reminder.recurrence == RecurrenceType.none && !updatedDateTime.isAfter(now)) {
          updatedDateTime = now.add(Duration(minutes: shiftMinutes));
        }

        final updatedReminder = reminder.copyWith(
          dateTime: updatedDateTime,
          status: ReminderStatus.pending,
          snoozedUntil: null,
        );

        final success = await updateReminder(updatedReminder);
        if (success) {
          dismissSuggestion(suggestion.id);
        }
        return;

      case ReminderSuggestionType.makeRecurring:
        final title = suggestion.sourceTitle;
        final hour = suggestion.suggestedHour;
        final minute = suggestion.suggestedMinute;
        if (title == null || hour == null || minute == null) return;

        final now = DateTime.now();
        var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
        if (!scheduled.isAfter(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }

        final newReminder = ReminderModel.create(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
          description: null,
          dateTime: scheduled,
          priority: suggestion.suggestedPriority ?? Priority.medium,
          recurrence: RecurrenceType.daily,
        );

        final success = await addReminder(newReminder);
        if (success) {
          dismissSuggestion(suggestion.id);
        }
        return;
    }
  }

  void _updateSuggestions() {
    final all = <ReminderSuggestion>[
      ..._buildAdjustTimeSuggestions(),
      ..._buildMakeRecurringSuggestions(),
    ];

    _suggestions = all
        .where((suggestion) => !_dismissedSuggestionIds.contains(suggestion.id))
        .take(3)
        .toList(growable: false);
  }

  List<ReminderSuggestion> _buildAdjustTimeSuggestions() {
    final suggestions = <ReminderSuggestion>[];

    for (final reminder in pendingReminders) {
      if (reminder.triggerType != ReminderTriggerType.time) continue;

      final delays = reminder.completionDelayMinutesHistory;
      if (reminder.recurrence != RecurrenceType.none && delays.length >= 3) {
        final avgDelay = delays.reduce((a, b) => a + b) ~/ delays.length;
        if (avgDelay >= 15) {
          final shift = _roundToNearestFive(avgDelay).clamp(5, 60).toInt();
          suggestions.add(
            ReminderSuggestion.adjustTime(
              reminderId: reminder.id,
              shiftMinutes: shift,
              title: 'Adjust reminder time',
              message: 'You usually complete “${reminder.title}” about $avgDelay min late. Move it later by $shift min?',
            ),
          );
          continue;
        }
      }

      if (reminder.snoozeCount >= 3) {
        final shift = (AppConstants.snoozeMinutes * 3).clamp(10, 60).toInt();
        suggestions.add(
          ReminderSuggestion.adjustTime(
            reminderId: reminder.id,
            shiftMinutes: shift,
            title: 'Adjust reminder time',
            message: 'You’ve snoozed “${reminder.title}” ${reminder.snoozeCount} times. Move it later by $shift min?',
          ),
        );
      }
    }

    return suggestions;
  }

  List<ReminderSuggestion> _buildMakeRecurringSuggestions() {
    final now = DateTime.now();
    final completedRecent = _reminders.where((r) {
      if (r.triggerType != ReminderTriggerType.time) return false;
      if (r.status != ReminderStatus.completed) return false;
      if (r.recurrence != RecurrenceType.none) return false;
      final completedAt = r.completedAt;
      if (completedAt == null) return false;
      return now.difference(completedAt).inDays <= 30;
    }).toList(growable: false);

    final groups = <String, List<ReminderModel>>{};
    for (final reminder in completedRecent) {
      final key = _normalizeTitle(reminder.title);
      if (key.isEmpty) continue;
      groups.putIfAbsent(key, () => <ReminderModel>[]).add(reminder);
    }

    final suggestions = <ReminderSuggestion>[];
    for (final entry in groups.entries) {
      final normalizedTitle = entry.key;
      final items = entry.value;
      if (items.length < 3) continue;

      final distinctDays = items
          .map((r) {
            final time = r.completedAt!;
            return DateTime(time.year, time.month, time.day);
          })
          .toSet();

      if (distinctDays.length < 3) continue;

      final hasActiveRecurring = _reminders.any((r) {
        if (r.triggerType != ReminderTriggerType.time) return false;
        if (r.status != ReminderStatus.pending && r.status != ReminderStatus.snoozed) return false;
        if (r.recurrence == RecurrenceType.none) return false;
        return _normalizeTitle(r.title) == normalizedTitle;
      });

      if (hasActiveRecurring) continue;

      items.sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));
      final latest = items.first;
      final completedAt = latest.completedAt ?? now;

      final timeLabel = DateTimeUtils.formatTime(
        DateTime(now.year, now.month, now.day, completedAt.hour, completedAt.minute),
      );

      suggestions.add(
        ReminderSuggestion.makeRecurring(
          normalizedTitle: normalizedTitle,
          sourceTitle: latest.title,
          suggestedHour: completedAt.hour,
          suggestedMinute: completedAt.minute,
          suggestedPriority: latest.priority,
          title: 'Make it recurring',
          message:
              'You’ve completed “${latest.title}” ${items.length} times recently. Make it a daily reminder at $timeLabel?',
        ),
      );
    }

    return suggestions;
  }

  String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _roundToNearestFive(int minutes) {
    final remainder = minutes % 5;
    if (remainder == 0) return minutes;
    return minutes + (5 - remainder);
  }

  /// Get reminders for a specific date
  List<ReminderModel> getRemindersForDate(DateTime date) {
    return _reminders.where((r) {
      return r.dateTime.year == date.year &&
          r.dateTime.month == date.month &&
          r.dateTime.day == date.day;
    }).toList();
  }

  /// Reschedule all pending notifications
  /// Useful after app restart or device reboot
  Future<void> rescheduleAllNotifications() async {
    try {
      await _notificationService.cancelAllNotifications();

      final activeReminders = _reminders
          .where((reminder) =>
              reminder.triggerType == ReminderTriggerType.time &&
              (reminder.status == ReminderStatus.pending || reminder.status == ReminderStatus.snoozed))
          .toList();

      await _notificationService.scheduleReminders(activeReminders);

      Logger.info('Rescheduled ${activeReminders.length} notifications', 'ReminderViewModel');
    } catch (e, stackTrace) {
      Logger.error('Failed to reschedule notifications', e, stackTrace, 'ReminderViewModel');
    }
  }

  Future<void> rescheduleAllGeofences() async {
    try {
      final supported = await _geofenceService.isSupported();
      if (!supported) return;

      final permission = await _geofenceService.getPermissionStatus();
      if (permission != GeofencePermissionStatus.always) {
        Logger.info('Geofence permission not granted; skipping reschedule', 'ReminderViewModel');
        return;
      }

      await _geofenceService.clearGeofences();

      final activeLocationReminders = _reminders
          .where((reminder) =>
              reminder.triggerType.isLocation &&
              reminder.location != null &&
              (reminder.status == ReminderStatus.pending || reminder.status == ReminderStatus.snoozed))
          .toList();

      for (final reminder in activeLocationReminders) {
        await _geofenceService.addGeofence(reminder);
      }

      Logger.info('Rescheduled ${activeLocationReminders.length} geofences', 'ReminderViewModel');
    } catch (e, stackTrace) {
      Logger.error('Failed to reschedule geofences', e, stackTrace, 'ReminderViewModel');
    }
  }

  Future<void> _refreshRemindersAndReschedule() async {
    await loadReminders();
    await rescheduleAllNotifications();
    await rescheduleAllGeofences();
  }

  ReminderModel? _findReminderById(String id) {
    for (final reminder in _reminders) {
      if (reminder.id == id) return reminder;
    }
    return null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}

enum ReminderSuggestionType {
  adjustTime,
  makeRecurring,
}

@immutable
class ReminderSuggestion {
  final String id;
  final ReminderSuggestionType type;
  final String title;
  final String message;
  final String primaryActionLabel;
  final String secondaryActionLabel;

  final String? reminderId;
  final int? shiftMinutes;

  final String? normalizedTitle;
  final String? sourceTitle;
  final int? suggestedHour;
  final int? suggestedMinute;
  final Priority? suggestedPriority;

  const ReminderSuggestion._({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.primaryActionLabel,
    required this.secondaryActionLabel,
    this.reminderId,
    this.shiftMinutes,
    this.normalizedTitle,
    this.sourceTitle,
    this.suggestedHour,
    this.suggestedMinute,
    this.suggestedPriority,
  });

  factory ReminderSuggestion.adjustTime({
    required String reminderId,
    required int shiftMinutes,
    required String title,
    required String message,
  }) {
    return ReminderSuggestion._(
      id: 'adjustTime:$reminderId:$shiftMinutes',
      type: ReminderSuggestionType.adjustTime,
      title: title,
      message: message,
      primaryActionLabel: 'Move later',
      secondaryActionLabel: 'Not now',
      reminderId: reminderId,
      shiftMinutes: shiftMinutes,
    );
  }

  factory ReminderSuggestion.makeRecurring({
    required String normalizedTitle,
    required String sourceTitle,
    required int suggestedHour,
    required int suggestedMinute,
    required Priority suggestedPriority,
    required String title,
    required String message,
  }) {
    return ReminderSuggestion._(
      id: 'makeRecurring:$normalizedTitle',
      type: ReminderSuggestionType.makeRecurring,
      title: title,
      message: message,
      primaryActionLabel: 'Make daily',
      secondaryActionLabel: 'Not now',
      normalizedTitle: normalizedTitle,
      sourceTitle: sourceTitle,
      suggestedHour: suggestedHour,
      suggestedMinute: suggestedMinute,
      suggestedPriority: suggestedPriority,
    );
  }
}
