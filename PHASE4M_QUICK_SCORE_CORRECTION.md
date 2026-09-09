# Phase 4M: Quick Score Correction

Adds a fast, direct way to fix an accidental or missed tap — a
long-press on the score digit itself opens a lightweight inline
stepper, right where the score is, instead of a separate "edit mode"
screen. Based on confirmed research: a common complaint pattern across
competitor scoreboard apps is accidental/over-registered taps, and users
specifically dislike a clunky separate edit mode to fix them.

**Status:** 271/271 tests passing (256 previous + 15 new), `flutter
analyze` clean.

---

## What was built

**The affordance:** long-pressing the score digit (not the whole
scoring zone — a plain tap there still scores a point, exactly as
before) opens `ScoreCorrectorDialog`, a small dialog with a
decrement/value/increment stepper and Cancel/Set score buttons. This is
deliberately not a full screen or a persistent "edit mode" toggle —
it's a single, self-contained overlay anchored to the same long-press
gesture, dismissed the moment a value is chosen or cancelled.

**Where the long-press lives vs. the score-a-point tap:** the score
digit (`AnimatedScoreText`) is wrapped in its own `GestureDetector`
with `onLongPress`, nested inside the existing whole-zone `InkWell`
that already handles "tap anywhere to score." Flutter's gesture arena
resolves this correctly with no extra plumbing: a quick tap anywhere in
the zone (including on the digit) still scores a point exactly as
before, while a *sustained* press specifically on the digit is claimed
by the long-press recognizer instead, so it never also scores a stray
point at the same time. A `Semantics(hint: ...)` wraps the digit for
screen readers instead of a visible `Tooltip` — a `Tooltip`'s own
default mobile trigger is *also* a long-press, which would otherwise
compete with the corrector for the exact same gesture.

**The engine side** (`lib/models/scoring_engine.dart`): two new
methods on `TableTennisScoringEngine`, alongside the existing
`addPoint`/`undo`/`resetMatch`:

```dart
int maxCorrectablePoints(Player player);
bool correctScore(Player player, int newValue);
```

`maxCorrectablePoints` returns the highest value `player` could be
corrected to right now without that alone already being a won game
against the other side's current total: `other < 10 ? 10 : other + 1`.
Below 11 there's no ceiling from the other side's score at all — any
value 0-10 is always a legal, unfinished game state. At or above 11,
the win-by-2 rule caps it exactly one point above the other side's
total (e.g. with the other side at 10, 11 is fine since 11-10 isn't won
yet, but 12 isn't, since 12-10 already would be).

`correctScore` validates against exactly that bound (plus rejecting
negative values and refusing entirely once the match is over — the
same lock-during-play gate `addPoint`'s own `canScore` check already
enforces) and, on success, directly sets that side's current-game point
total. Nothing else about the engine's model changes — no new way to
skip playing, no new game/serve/ends state, just the one point-value
correction the request asked for.

## Why the rest of the app didn't need new logic to stay correct

- **Server/receiver indicator.** `currentServer` was already derived
  fresh every time from `player1Points + player2Points` and who served
  first in the game — never separately tracked. A correction changes
  those totals and `currentServer` recalculates correctly automatically,
  with zero extra code. Confirmed with a widget test that corrects
  player one straight to 3 and checks the server icon lands on the
  correct side for that total (derived from whichever side the random
  coin toss put on serve first, not a hardcoded assumption — see
  Testing below).
- **Deciding-game mid-point change of ends.** The "reached 5, change
  ends" prompt is computed inside `addPoint` itself, by comparing the
  score immediately before and after *that specific increment*. It's
  not persisted state that a correction could desynchronize — a
  correction that jumps straight to (or past) 5 simply doesn't retrigger
  that one-time comparison, and critically, doesn't cause it to
  mis-fire on a later, unrelated point either (verified with a test:
  correcting to 5 directly, then playing an ordinary next point, does
  not raise the banner a second time).
- **Undo.** Per the request's own explicit simplicity allowance, a
  successful correction just clears the undo stack outright rather than
  trying to rewrite history for an edit that didn't go through
  `addPoint`. The "Undo" button is disabled immediately after a
  correction — a manual correction is itself the fix for whatever tap
  it's undoing.

## UI wiring

Added to both `ScoreboardScreen` (singles, `_PlayerZone`) and
`DoublesScoreboardScreen` (`_DoublesTeamZone`) — both scoreboards share
the same `TableTennisScoringEngine`, so the engine change covers both
for free; only the UI affordance needed adding twice. Each screen's own
`_correctScore(player)` method opens the dialog seeded with that side's
current points and a computed `maxValue`, and on confirmation calls
`_engine.correctScore(...)` inside `setState`. Guarded by the same
`canScore` check `_scorePoint` already uses, matching the requested
"same lock-during-play logic pattern already used elsewhere" — though
`correctScore` itself would refuse anyway, so this is purely to avoid
opening a dialog that couldn't do anything.

Three new localized strings (`correctScoreHint`, `correctScoreDialogTitle`,
`correctScoreCancelButton`, `correctScoreConfirmButton`) were added to
all three ARB files (en/de/fr), following the existing localization
pattern exactly.

## Testing

**Engine-level** (`test/scoring_engine_test.dart`, new group "Manual
score correction (Phase 4M)", 9 tests): sets a valid value; rejects a
negative value with the engine state left completely unchanged; rejects
a value that would already be a won game; the exact win-by-2 boundary
at deuce (10-10 allows up to 11, not 12); any value 0-10 is always
correctable regardless of the other side's score; a no-op once the
match is over; `currentServer` recalculates correctly from a corrected
total (traced through to deuce territory too); a correction to exactly
5 in the deciding game doesn't retrigger `changeEndsNow` on the next
ordinary point; a correction clears the undo stack.

**Widget-level, singles** (`test/quick_score_correction_test.dart`, 5
tests): long-pressing the digit opens the corrector seeded with the
current score; setting a valid value updates the score correctly;
cancelling discards the change entirely; the stepper itself cannot be
pushed past the win-by-2 boundary or below zero (there is no way to
*select* an invalid value through this UI at all, since the stepper's
own bounds are exactly `maxCorrectablePoints`); the server indicator
recalculates correctly after a correction, verified without assuming
which side the (randomly decided) coin toss put on serve first —
captured dynamically at 0-0 and compared against the corrected total's
expected server instead of hardcoding an assumption that would have
made this test flaky.

**Widget-level, doubles** (`test/doubles_widget_test.dart`, 1 test):
the same long-press-and-correct flow works for a team's score,
confirming the shared engine wiring reaches both scoreboards.

Not separately tested: the exact gesture-arena interaction between the
zone-wide tap and the digit-specific long-press (i.e. "a long-press
never also registers as a scored point"). This follows directly from
Flutter's standard, well-established long-press-inside-a-tappable-region
pattern rather than any custom conflict-resolution code written for
this feature, so it wasn't considered to need its own dedicated test —
the existing "setting a valid value" tests already exercise a full
long-press-then-confirm cycle without an extra stray point ever
appearing on the corrected side.
