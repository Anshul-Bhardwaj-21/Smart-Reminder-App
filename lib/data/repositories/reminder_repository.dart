import '../../core/constants/enums.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/logger.dart';
import '../models/reminder_model.dart';

/// Repository for managing reminder data
/// Handles all CRUD operations for reminders
class ReminderRepository {
  final StorageService _storage;

  ReminderRepository(this._storage);

  /// Get all reminders
  Future<List<ReminderModel>> getAllReminders() async {
    try {
      final reminders = _storage.remindersBox.values
          .map((json) => ReminderModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      reminders.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      Logger.debug('Loaded ${reminders.length} reminders', 'ReminderRepository');
      return reminders;
    } catch (e, stackTrace) {
      Logger.error('Failed to get all reminders', e, stackTrace, 'ReminderRepository');
      return [];
    }
  }

  /// Get reminder by ID
  Future<ReminderModel?> getReminderById(String id) async {
    try {
      final json = _storage.remindersBox.get(id);
      if (json == null) return null;
      return ReminderModel.fromJson(Map<String, dynamic>.from(json));
    } catch (e, stackTrace) {
      Logger.error('Failed to get reminder by ID: $id', e, stackTrace, 'ReminderRepository');
      return null;
    }
  }

  /// Save reminder (create or update)
  Future<bool> saveReminder(ReminderModel reminder) async {
    try {
      await _storage.remindersBox.put(reminder.id, reminder.toJson());
      Logger.info('Saved reminder: ${reminder.id}', 'ReminderRepository');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to save reminder: ${reminder.id}', e, stackTrace, 'ReminderRepository');
      return false;
    }
  }

  /// Delete reminder
  Future<bool> deleteReminder(String id) async {
    try {
      await _storage.remindersBox.delete(id);
      Logger.info('Deleted reminder: $id', 'ReminderRepository');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to delete reminder: $id', e, stackTrace, 'ReminderRepository');
      return false;
    }
  }

  /// Get reminders by status
  Future<List<ReminderModel>> getRemindersByStatus(Set<ReminderStatus> statuses) async {
    try {
      final reminders = await getAllReminders();
      return reminders.where((r) => statuses.contains(r.status)).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to get reminders by status', e, stackTrace, 'ReminderRepository');
      return [];
    }
  }

  /// Clear all reminders
  Future<bool> clearAllReminders() async {
    try {
      await _storage.remindersBox.clear();
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to clear all reminders', e, stackTrace, 'ReminderRepository');
      return false;
    }
  }
}
