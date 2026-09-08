/// A small, in-memory (never persisted, never shared across matches)
/// store of custom names for the current match — see
/// PHASE4F_THEME_AND_NAMES.md and PHASE4G_NAMES_SYNC_AND_DIALOG.md.
///
/// Two independent kinds of name live here:
/// - up to 4 **player** names, keyed 1-4 to match the `playerNLabel`
///   numbering (1/2 for singles or team 1's two doubles players, 3/4 for
///   team 2's);
/// - up to 2 **team** names (doubles only), keyed 1/2, entirely separate
///   from the player names — setting a team name never touches either
///   player's name, and vice versa. A team name is optional: if unset,
///   callers keep showing the generic "Team 1"/"Team 2" default exactly
///   as before. This is deliberately *not* auto-derived from the two
///   player names (e.g. "Alex & Sam") — combining two names gets
///   unwieldy fast, especially once either is renamed again, so a team
///   name is its own explicit opt-in field.
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

  final Map<int, String> _customPlayers = {};
  final Map<int, String> _customTeams = {};

  /// The name to show for player [slot], or [defaultLabel] if no custom
  /// name is set for it (including if it was cleared back to blank).
  String resolve(int slot, String defaultLabel) =>
      _customPlayers[slot] ?? defaultLabel;

  bool isCustom(int slot) => _customPlayers.containsKey(slot);

  /// Sets player [slot]'s custom name to the trimmed [name] — or clears
  /// it back to the default if [name] is null, empty/whitespace-only, or
  /// longer than [maxLength], since a blank or oversized name isn't a
  /// name a user meant to keep.
  void set(int slot, String? name) {
    final trimmed = _sanitize(name);
    if (trimmed == null) {
      _customPlayers.remove(slot);
    } else {
      _customPlayers[slot] = trimmed;
    }
  }

  /// The name to show for [team] (1 or 2), or [defaultLabel] (typically
  /// the localized "Team 1"/"Team 2") if no custom team name is set.
  String resolveTeam(int team, String defaultLabel) =>
      _customTeams[team] ?? defaultLabel;

  bool isTeamCustom(int team) => _customTeams.containsKey(team);

  /// Sets [team]'s (1 or 2) custom name — same validation as [set].
  void setTeam(int team, String? name) {
    final trimmed = _sanitize(name);
    if (trimmed == null) {
      _customTeams.remove(team);
    } else {
      _customTeams[team] = trimmed;
    }
  }

  String? _sanitize(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed.length > maxLength) {
      return null;
    }
    return trimmed;
  }

  void clear() {
    _customPlayers.clear();
    _customTeams.clear();
  }
}
