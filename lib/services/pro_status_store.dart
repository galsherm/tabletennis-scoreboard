import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has purchased Pro, so ads stay removed and
/// export stays unlocked across app restarts without needing to re-query
/// the store on every launch. See PHASE5_MONETIZATION.md.
///
/// Best-effort like [ThemePreference]: a missing/unavailable platform
/// implementation (a plain `flutter test` widget test without
/// `SharedPreferences.setMockInitialValues`) is caught and treated as
/// "not Pro" rather than crashing — this is a convenience cache, not the
/// source of truth (the store itself is, via [PurchaseGateway.
/// restorePurchases]).
class ProStatusStore {
  static const _key = 'is_pro';

  Future<bool> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> save(bool isPro) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, isPro);
    } catch (_) {
      // Best-effort — losing the cached flag isn't worth crashing over;
      // restorePurchases() will re-sync it next time the store answers.
    }
  }
}
