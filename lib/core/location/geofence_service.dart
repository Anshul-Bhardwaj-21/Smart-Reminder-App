import 'package:flutter/services.dart';

import '../../data/models/reminder_model.dart';
import '../utils/logger.dart';

enum GeofencePermissionStatus {
  denied,
  whenInUse,
  always,
  notDetermined,
  restricted,
  unknown,
}

class GeofenceService {
  static const MethodChannel _channel = MethodChannel('smart_reminder/geofence');

  Future<bool> isSupported() async {
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } catch (e, stackTrace) {
      Logger.error('Failed to check geofence support', e, stackTrace, 'GeofenceService');
      return false;
    }
  }

  Future<GeofencePermissionStatus> getPermissionStatus() async {
    try {
      final status = await _channel.invokeMethod<String>('getPermissionStatus');
      return _parsePermissionStatus(status);
    } catch (e, stackTrace) {
      Logger.error('Failed to get permission status', e, stackTrace, 'GeofenceService');
      return GeofencePermissionStatus.unknown;
    }
  }

  Future<GeofencePermissionStatus> requestPermissions() async {
    try {
      final status = await _channel.invokeMethod<String>('requestPermissions');
      return _parsePermissionStatus(status);
    } catch (e, stackTrace) {
      Logger.error('Failed to request permissions', e, stackTrace, 'GeofenceService');
      return GeofencePermissionStatus.unknown;
    }
  }

  Future<bool> addGeofence(ReminderModel reminder) async {
    if (!reminder.triggerType.isLocation) return true;
    final location = reminder.location;
    if (location == null) {
      Logger.error('Location reminder missing location data', null, null, 'GeofenceService');
      return false;
    }

    try {
      final success = await _channel.invokeMethod<bool>('addGeofence', {
        'id': reminder.id,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'radiusMeters': location.radiusMeters,
        'triggerType': reminder.triggerType.storageValue,
        'locationName': location.name,
        'title': reminder.title,
        'body': reminder.description ?? 'Reminder',
      });

      return success ?? false;
    } catch (e, stackTrace) {
      Logger.error('Failed to add geofence for reminder: ${reminder.id}', e, stackTrace, 'GeofenceService');
      return false;
    }
  }

  Future<bool> removeGeofence(String reminderId) async {
    try {
      final success = await _channel.invokeMethod<bool>('removeGeofence', {'id': reminderId});
      return success ?? false;
    } catch (e, stackTrace) {
      Logger.error('Failed to remove geofence: $reminderId', e, stackTrace, 'GeofenceService');
      return false;
    }
  }

  Future<bool> clearGeofences() async {
    try {
      final success = await _channel.invokeMethod<bool>('clearGeofences');
      return success ?? false;
    } catch (e, stackTrace) {
      Logger.error('Failed to clear geofences', e, stackTrace, 'GeofenceService');
      return false;
    }
  }

  GeofencePermissionStatus _parsePermissionStatus(String? status) {
    switch (status) {
      case 'denied':
        return GeofencePermissionStatus.denied;
      case 'whenInUse':
        return GeofencePermissionStatus.whenInUse;
      case 'always':
        return GeofencePermissionStatus.always;
      case 'notDetermined':
        return GeofencePermissionStatus.notDetermined;
      case 'restricted':
        return GeofencePermissionStatus.restricted;
      default:
        return GeofencePermissionStatus.unknown;
    }
  }
}
