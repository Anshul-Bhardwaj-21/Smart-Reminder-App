import 'package:hive_flutter/hive_flutter.dart';
import '../utils/logger.dart';

/// Hive-backed storage service
/// Owns and provides access to app boxes
class StorageService {
  static const String remindersBoxName = 'reminders';
  static const String settingsBoxName = 'settings';

  final Box<Map> remindersBox;
  final Box settingsBox;

  StorageService._(this.remindersBox, this.settingsBox);

  static Future<StorageService> init() async {
    try {
      await Hive.initFlutter();
      final remindersBox = await Hive.openBox<Map>(remindersBoxName);
      final settingsBox = await Hive.openBox(settingsBoxName);
      Logger.info('Hive storage initialized', 'StorageService');
      return StorageService._(remindersBox, settingsBox);
    } catch (e, stackTrace) {
      Logger.error('Failed to initialize Hive storage', e, stackTrace, 'StorageService');
      rethrow;
    }
  }
}
