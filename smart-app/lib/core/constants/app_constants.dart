/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Smart Reminder';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String keyReminders = 'reminders';
  static const String keyThemeMode = 'theme_mode';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyUserId = 'user_id';

  // Notification Channels
  static const String notificationChannelId = 'smart_reminder_channel';
  static const String notificationChannelName = 'Reminders';
  static const String notificationChannelDescription = 'Reminder notifications';

  // Notification Actions
  static const String snoozeActionId = 'snooze_10_min';
  static const String snoozeActionLabel = 'Snooze 10 min';
  static const String snoozeCategoryId = 'snooze_actions';

  // Date/Time Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String displayTimeFormat = 'hh:mm a';

  // Defaults
  static const int defaultMorningHour = 9;
  static const int defaultAfternoonHour = 14;
  static const int defaultEveningHour = 18;
  static const int defaultNightHour = 20;
  static const int defaultMinute = 0;

  // Limits
  static const int maxTitleLength = 100;
  static const int maxDescriptionLength = 500;
  static const int snoozeMinutes = 10;
  static const int customScheduleLookaheadCount = 30;
}
