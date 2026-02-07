import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/location/geofence_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'data/repositories/reminder_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'presentation/viewmodels/reminder_viewmodel.dart';
import 'presentation/viewmodels/theme_viewmodel.dart';
import 'core/utils/logger.dart';
import 'main_app.dart';

/// Entry point of the application
/// Handles initialization of core services
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final storageService = await StorageService.init();

  final notificationService = NotificationService.instance;
  final notificationInitialized = await notificationService.initialize();

  if (notificationInitialized) {
    await notificationService.requestPermissions();
    Logger.info('Notification service initialized', 'Main');
  } else {
    Logger.error('Failed to initialize notification service', null, null, 'Main');
  }

  final reminderRepository = ReminderRepository(storageService);
  final settingsRepository = SettingsRepository(storageService);

  final geofenceService = GeofenceService();

  final reminderViewModel = ReminderViewModel(reminderRepository, notificationService, geofenceService);
  await reminderViewModel.initialize();

  final themeViewModel = ThemeViewModel(settingsRepository);
  await themeViewModel.load();

  notificationService.registerResponseHandler(reminderViewModel.handleNotificationResponse);

  runApp(
    SmartReminderApp(
      reminderViewModel: reminderViewModel,
      themeViewModel: themeViewModel,
    ),
  );
}
