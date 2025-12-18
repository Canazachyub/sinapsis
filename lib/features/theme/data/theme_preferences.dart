import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

class ThemePreferences {
  final SharedPreferences _prefs;

  ThemePreferences(this._prefs);

  Future<ThemeMode> getThemeMode() async {
    final themeName = _prefs.getString(AppConstants.themeKey);

    switch (themeName) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String themeName;

    switch (mode) {
      case ThemeMode.light:
        themeName = 'light';
        break;
      case ThemeMode.dark:
        themeName = 'dark';
        break;
      case ThemeMode.system:
        themeName = 'system';
        break;
    }

    await _prefs.setString(AppConstants.themeKey, themeName);
  }
}
