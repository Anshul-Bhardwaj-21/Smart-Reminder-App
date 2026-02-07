import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import '../../data/models/reminder_model.dart';
import '../utils/logger.dart';
import '../constants/app_constants.dart';
import '../constants/enums.dart' as reminder_enums;
import '../utils/date_time_utils.dart';

/// Production-ready notification service
/// Handles local notifications with proper permission handling
class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  NotificationResponseHandler? _responseHandler;
  NotificationResponse? _pendingResponse;

  NotificationService._();

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  /// Initialize notification service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            AppConstants.snoozeCategoryId,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                AppConstants.snoozeActionId,
                AppConstants.snoozeActionLabel,
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
            ],
          ),
        ],
      );

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      if (initialized == true) {
        await _createNotificationChannel();
        _isInitialized = true;
        Logger.info('Notification service initialized', 'NotificationService');
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      Logger.error('Failed to initialize notification service', e, stackTrace, 'NotificationService');
      return false;
    }
  }

  void registerResponseHandler(NotificationResponseHandler handler) {
    _responseHandler = handler;
    if (_pendingResponse != null) {
      final response = _pendingResponse!;
      _pendingResponse = null;
      _responseHandler?.call(response);
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (_responseHandler != null) {
      _responseHandler?.call(response);
    } else {
      _pendingResponse = response;
    }
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: AppConstants.notificationChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      final androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }

      final iosImplementation = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      if (iosImplementation != null) {
        final granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to request permissions', e, stackTrace, 'NotificationService');
      return false;
    }
  }

  /// Schedule notification for reminder
  Future<void> scheduleReminder(ReminderModel reminder) async {
    if (!_isInitialized) {
      Logger.error('Notification service not initialized', null, null, 'NotificationService');
      return;
    }

    if (reminder.triggerType != reminder_enums.ReminderTriggerType.time) {
      return;
    }

    if (reminder.status == reminder_enums.ReminderStatus.completed ||
        reminder.status == reminder_enums.ReminderStatus.cancelled) {
      return;
    }

    final now = DateTime.now();
    final snoozeTime =
        reminder.status == reminder_enums.ReminderStatus.snoozed ? reminder.snoozedUntil : null;
    final isRecurring = reminder.recurrence != reminder_enums.RecurrenceType.none;

    final scheduleAfter =
        (reminder.status == reminder_enums.ReminderStatus.snoozed &&
                snoozeTime != null &&
                reminder.dateTime.isAfter(now))
            ? reminder.dateTime
            : now;

    if (isRecurring && snoozeTime != null && snoozeTime.isAfter(now)) {
      await _scheduleOneTime(
        reminder,
        snoozeTime,
        notificationId: _notificationIdForSnooze(reminder.id),
      );
    }

    if (reminder.recurrence == reminder_enums.RecurrenceType.none) {
      final effectiveTime = snoozeTime ?? reminder.dateTime;
      if (effectiveTime.isAfter(now)) {
        await _scheduleOneTime(reminder, effectiveTime, notificationId: _notificationIdForReminder(reminder.id));
      }
      return;
    }

    if (reminder.recurrence == reminder_enums.RecurrenceType.custom) {
      final customDays = reminder.customRecurrenceDays ?? 1;
      final occurrences = DateTimeUtils.getNextCustomOccurrences(
        base: reminder.dateTime,
        customDays: customDays,
        count: AppConstants.customScheduleLookaheadCount,
        after: scheduleAfter,
      );

      for (final occurrence in occurrences) {
        await _scheduleOneTime(
          reminder,
          occurrence,
          notificationId: _notificationIdForOccurrence(reminder.id, occurrence),
        );
      }
      return;
    }

    final nextOccurrence = DateTimeUtils.getNextOccurrenceAfter(
      base: reminder.dateTime,
      recurrence: reminder.recurrence,
      customDays: reminder.customRecurrenceDays,
      after: scheduleAfter,
    );

    if (nextOccurrence == null) return;

    await _notifications.zonedSchedule(
      _notificationIdForReminder(reminder.id),
      reminder.title,
      reminder.description ?? 'Reminder',
      tz.TZDateTime.from(nextOccurrence, tz.local),
      _getNotificationDetails(reminder),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: _getMatchComponents(reminder.recurrence),
      payload: reminder.id,
    );

    Logger.info('Scheduled notification for reminder: ${reminder.id}', 'NotificationService');
  }

  Future<void> scheduleReminders(List<ReminderModel> reminders) async {
    for (final reminder in reminders) {
      await scheduleReminder(reminder);
    }
  }

  Future<void> _scheduleOneTime(
    ReminderModel reminder,
    DateTime scheduledDate, {
    required int notificationId,
  }) async {
    await _notifications.zonedSchedule(
      notificationId,
      reminder.title,
      reminder.description ?? 'Reminder',
      tz.TZDateTime.from(scheduledDate, tz.local),
      _getNotificationDetails(reminder),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: reminder.id,
    );
  }

  DateTimeComponents? _getMatchComponents(reminder_enums.RecurrenceType recurrence) {
    switch (recurrence) {
      case reminder_enums.RecurrenceType.daily:
        return DateTimeComponents.time;
      case reminder_enums.RecurrenceType.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case reminder_enums.RecurrenceType.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
      case reminder_enums.RecurrenceType.custom:
      case reminder_enums.RecurrenceType.none:
        return null;
    }
  }

  /// Get notification details based on priority
  NotificationDetails _getNotificationDetails(ReminderModel reminder) {
    final androidPriority = _getAndroidPriority(reminder.priority);
    final importance = _getAndroidImportance(reminder.priority);

    return NotificationDetails(
      android: AndroidNotificationDetails(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        channelDescription: AppConstants.notificationChannelDescription,
        importance: importance,
        priority: androidPriority,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            AppConstants.snoozeActionId,
            AppConstants.snoozeActionLabel,
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: AppConstants.snoozeCategoryId,
      ),
    );
  }

  /// Get Android priority from reminder priority
  Priority _getAndroidPriority(reminder_enums.Priority priority) {
    switch (priority) {
      case reminder_enums.Priority.high:
        return Priority.high;
      case reminder_enums.Priority.medium:
        return Priority.defaultPriority;
      case reminder_enums.Priority.low:
        return Priority.low;
    }
  }

  /// Get Android importance from reminder priority
  Importance _getAndroidImportance(reminder_enums.Priority priority) {
    switch (priority) {
      case reminder_enums.Priority.high:
        return Importance.high;
      case reminder_enums.Priority.medium:
        return Importance.defaultImportance;
      case reminder_enums.Priority.low:
        return Importance.low;
    }
  }

  /// Cancel scheduled notification
  Future<bool> cancelNotification(int notificationId) async {
    try {
      await _notifications.cancel(notificationId);
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to cancel notification: $notificationId', e, stackTrace, 'NotificationService');
      return false;
    }
  }

  /// Cancel all notifications
  Future<bool> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      Logger.info('Cancelled all notifications', 'NotificationService');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to cancel all notifications', e, stackTrace, 'NotificationService');
      return false;
    }
  }

  /// Show immediate notification
  Future<bool> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) return false;

    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.notificationChannelId,
            AppConstants.notificationChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to show notification', e, stackTrace, 'NotificationService');
      return false;
    }
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e, stackTrace) {
      Logger.error('Failed to get pending notifications', e, stackTrace, 'NotificationService');
      return [];
    }
  }

  int _notificationIdForReminder(String reminderId) {
    return _stableHash('reminder:$reminderId');
  }

  int _notificationIdForSnooze(String reminderId) {
    return _stableHash('reminder:$reminderId:snooze');
  }

  int _notificationIdForOccurrence(String reminderId, DateTime occurrence) {
    return _stableHash('reminder:$reminderId:${occurrence.millisecondsSinceEpoch}');
  }

  int _stableHash(String value) {
    const int fnvOffset = 0x811c9dc5;
    const int fnvPrime = 0x01000193;
    int hash = fnvOffset;

    for (int i = 0; i < value.length; i++) {
      hash ^= value.codeUnitAt(i);
      hash = (hash * fnvPrime) & 0x7fffffff;
    }

    return hash;
  }
}

typedef NotificationResponseHandler = Future<void> Function(NotificationResponse response);

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('Notification action received in background: ${response.actionId}');
}

