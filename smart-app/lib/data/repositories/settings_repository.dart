import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';

/// Repository for app settings
class SettingsRepository {
  final StorageService _storage;

  SettingsRepository(this._storage);

  ThemeMode? getThemeMode() {
    final savedMode = _storage.settingsBox.get(AppConstants.keyThemeMode) as String?;
    if (savedMode == null) return null;

    return ThemeMode.values.firstWhere(
      (mode) => mode.toString() == savedMode,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _storage.settingsBox.put(AppConstants.keyThemeMode, mode.toString());
  }
}
