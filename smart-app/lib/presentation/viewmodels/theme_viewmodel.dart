import 'package:flutter/material.dart';
import '../../data/repositories/settings_repository.dart';
import '../../core/utils/logger.dart';

/// ViewModel for managing app theme
class ThemeViewModel extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeViewModel(this._settingsRepository);

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  /// Load saved theme mode
  Future<void> load() async {
    try {
      final savedMode = _settingsRepository.getThemeMode();
      if (savedMode != null) {
        _themeMode = savedMode;
        notifyListeners();
        Logger.debug('Loaded theme mode: $_themeMode', 'ThemeViewModel');
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to load theme mode', e, stackTrace, 'ThemeViewModel');
    }
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      _themeMode = mode;
      await _settingsRepository.setThemeMode(mode);
      notifyListeners();
      Logger.info('Theme mode changed to: $mode', 'ThemeViewModel');
    } catch (e, stackTrace) {
      Logger.error('Failed to set theme mode', e, stackTrace, 'ThemeViewModel');
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }
}
