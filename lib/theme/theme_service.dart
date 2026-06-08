import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted theme-mode singleton.
/// Call [load] once at startup, then read/write [notifier].
class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _key = 'app_theme_mode';

  final ValueNotifier<ThemeMode> notifier =
      ValueNotifier(ThemeMode.light);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_key);
    notifier.value = val == 'dark'
        ? ThemeMode.dark
        : val == 'system'
            ? ThemeMode.system
            : ThemeMode.light;
  }

  Future<void> setMode(ThemeMode mode) async {
    notifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  bool get isDark => notifier.value == ThemeMode.dark;
}
