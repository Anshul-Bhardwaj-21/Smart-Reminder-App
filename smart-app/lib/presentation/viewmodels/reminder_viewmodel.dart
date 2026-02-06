import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../data/models/reminder_model.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../core/services/notification_service.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';

/// ViewModel for managing reminders
/// Handles business logic and state management
class ReminderViewModel extends ChangeNotifier {
  final ReminderRepository _repository;
  final NotificationService _notificationService;

  List<ReminderModel> _reminders = [];
  bool _isLoading = false;
  String? _error;

  ReminderViewModel(this._repository, this._notificationService);

  // Getters
  List<ReminderModel> get reminders => _reminders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<ReminderModel> get pendingReminders => _reminders
      .where((r) => r.status == ReminderStatus.pending || r.status == ReminderStatus.snoozed)
      .toList();

  List<ReminderModel> get completedReminders =>
      _reminders.where((r) => r.status == ReminderStatus.completed).toList();

  List<ReminderModel> get dueReminders => _reminders.where((r) => r.isDue).toList();

  Future<void> initialize() async {
    await loadReminders();
    await rescheduleAllNotifications();
  }

  /// Load all reminders
  Future<void> loadReminders() async {
    _setLoading(true);
    _clearError();

    try {
      _reminders = await _repository.getAllReminders();
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
        );
      } else {
        updatedReminder = reminder.copyWith(
          status: ReminderStatus.completed,
          completedAt: now,
          snoozedUntil: null,
          completionHistory: [...reminder.completionHistory, now],
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
          .where((reminder) => reminder.status == ReminderStatus.pending || reminder.status == ReminderStatus.snoozed)
          .toList();

      await _notificationService.scheduleReminders(activeReminders);

      Logger.info('Rescheduled ${activeReminders.length} notifications', 'ReminderViewModel');
    } catch (e, stackTrace) {
      Logger.error('Failed to reschedule notifications', e, stackTrace, 'ReminderViewModel');
    }
  }

  Future<void> _refreshRemindersAndReschedule() async {
    await loadReminders();
    await rescheduleAllNotifications();
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
