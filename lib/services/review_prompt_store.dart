import 'package:shared_preferences/shared_preferences.dart';

/// What [ReviewPromptStore] has on record, read in one go so
/// [shouldAutoPromptReview] decides from a single consistent snapshot.
typedef ReviewPromptState = ({
  int completedMatches,
  bool autoPrompted,
  bool manualUsed,
});

/// Persists what the automatic "rate this app" prompt needs to stay a
/// one-time event for the lifetime of an install: how many matches have
/// been completed, whether the automatic prompt already fired, and
/// whether the user already used the manual "Rate this app" menu item.
///
/// Best-effort like [ScoreEditHintStore], and failing in the same
/// direction: if persistence is broken, the flags read as already set —
/// a prompt that silently never appears is a much smaller problem than
/// one that reappears after every match because it can never record
/// that it already fired.
class ReviewPromptStore {
  static const _completedMatchesKey = 'review_completed_matches';
  static const _autoPromptedKey = 'review_auto_prompted';
  static const _manualUsedKey = 'review_manual_used';

  Future<ReviewPromptState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (
        completedMatches: prefs.getInt(_completedMatchesKey) ?? 0,
        autoPrompted: prefs.getBool(_autoPromptedKey) ?? false,
        manualUsed: prefs.getBool(_manualUsedKey) ?? false,
      );
    } catch (_) {
      return (completedMatches: 0, autoPrompted: true, manualUsed: true);
    }
  }

  Future<void> incrementCompletedMatches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_completedMatchesKey) ?? 0;
      await prefs.setInt(_completedMatchesKey, current + 1);
    } catch (_) {
      // Best-effort — see the class doc comment.
    }
  }

  Future<void> markAutoPrompted() => _setFlag(_autoPromptedKey);

  Future<void> markManualUsed() => _setFlag(_manualUsedKey);

  Future<void> _setFlag(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {
      // Best-effort — see the class doc comment.
    }
  }
}
