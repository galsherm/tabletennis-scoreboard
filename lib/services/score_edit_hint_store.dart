import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the one-time "you can long-press a score to correct
/// it" discoverability pulse (Phase 4P, see [ScoreEditHint]) has already
/// played — so it shows exactly once for the lifetime of an install, on
/// the very first scoreboard screen ever opened, and never again across
/// new matches or app restarts.
///
/// Best-effort like [ThemePreference]/[ProStatusStore]: a missing/
/// unavailable platform implementation is caught. Unlike those two,
/// failure here defaults to "already shown" (`true`) rather than
/// "nothing saved yet" (`false`) — a hint that silently never appears
/// again (because persistence happens to be broken) is a much smaller
/// problem than one that replays on every single match because it can
/// never successfully record that it already played.
class ScoreEditHintStore {
  static const _key = 'score_edit_hint_shown';

  Future<bool> hasShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return true;
    }
  }

  Future<void> markShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // Best-effort — see the class doc comment for why this direction
      // of failure is the safer one to accept silently.
    }
  }
}
