import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's Light/Dark/System theme choice across app
/// restarts — see PHASE4F_THEME_AND_NAMES.md.
///
/// Best-effort, like [VoiceAnnouncer]: a missing/unavailable platform
/// implementation (notably in a plain `flutter test` widget test, which
/// has no real shared_preferences plugin registered unless the test
/// explicitly calls `SharedPreferences.setMockInitialValues`) is caught
/// and treated the same as "nothing saved yet" rather than crashing or
/// blocking startup — persistence is a convenience, never a requirement
/// to use the app.
class ThemePreference {
  static const _key = 'theme_mode';

  /// Dark remains the default for a fresh install (nothing stored yet) —
  /// the courtside-legibility reasoning from PHASE4B_UI_POLISH.md still
  /// applies; this feature adds choice, it doesn't change what a new
  /// user sees.
  Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return switch (prefs.getString(_key)) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  Future<void> save(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
      });
    } catch (_) {
      // Best-effort — losing the persisted preference isn't worth
      // crashing over.
    }
  }
}
