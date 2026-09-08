/// A small, in-memory (never persisted, never shared across matches)
/// store of up to 4 custom player display names, keyed 1-4 to match the
/// `playerNLabel` numbering used throughout the app (1/2 for singles or
/// team 1's two doubles players, 3/4 for team 2's) — see
/// PHASE4F_THEME_AND_NAMES.md.
///
/// Deliberately not a saved profile/history system — scope for this
/// feature is "rename for this match only," so there's no persistence
/// layer here at all; a screen just holds one of these for its own
/// lifetime and discards it on "New match".
class PlayerNames {
  /// Longer names are rejected outright (left at the default) rather
  /// than silently truncated — the caller should also cap input length
  /// at entry time (e.g. a `TextField.maxLength`); this is a defensive
  /// backstop so a slot's on-court label is never long enough to risk
  /// clipping the compact doubles layout.
  static const maxLength = 16;

  final Map<int, String> _custom = {};

  /// The name to show for [slot], or [defaultLabel] if no custom name is
  /// set for it (including if it was cleared back to blank).
  String resolve(int slot, String defaultLabel) =>
      _custom[slot] ?? defaultLabel;

  bool isCustom(int slot) => _custom.containsKey(slot);

  /// Sets [slot]'s custom name to the trimmed [name] — or clears it back
  /// to the default if [name] is null, empty/whitespace-only, or longer
  /// than [maxLength], since a blank or oversized name isn't a name a
  /// user meant to keep.
  void set(int slot, String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed.length > maxLength) {
      _custom.remove(slot);
    } else {
      _custom[slot] = trimmed;
    }
  }

  void clear() => _custom.clear();
}
