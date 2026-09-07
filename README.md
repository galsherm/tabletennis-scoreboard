# Table Tennis Scoreboard — Phase 1

Core scoring engine + basic UI, per the MVP plan (Phase 1 of 6). Singles only.

## What's in this phase

- `lib/models/scoring_engine.dart` — the scoring state machine (pure Dart,
  no Flutter dependency): points → games (11, win-by-2, deuce) → match
  (best-of-3/5/7), serve rotation, change-of-ends (including the deciding-game
  5-point rule), undo, reset.
- `lib/screens/setup_screen.dart` — pick best-of format, "toss" for who
  serves first.
- `lib/screens/scoreboard_screen.dart` — the two-tap scoring UI: tap either
  side to score, undo button, reset button, server indicator, banners for
  game/match completion.
- `test/scoring_engine_test.dart` — unit tests for the scoring logic.
- `test/widget_test.dart` — automated UI tests that drive the actual app
  (tap zones, undo, game/match completion, the "new match" flow).

**Deliberately NOT in this phase** (see the MVP doc, §4 and §9): voice
announcements, localization, doubles, monetization, the expedite system,
time-outs, toweling-down breaks. Those are later phases.

## How to run it

This repo only contains the Dart/Flutter source (`lib/`, `test/`,
`pubspec.yaml`) — not the generated platform scaffolding
(`android/`, `windows/`, `web/`, etc.), which Flutter needs in order to
actually launch on a device. Generate it once, then run:

```bash
flutter create .
flutter pub get
flutter run
```

`flutter create .` only adds the missing platform folders — it will not
overwrite `lib/`, `test/`, or `pubspec.yaml`. You only need to run it once
per machine/checkout.

## How to run the tests

```bash
flutter test
```

This runs both `test/scoring_engine_test.dart` (logic) and
`test/widget_test.dart` (UI).

## Important: I could not execute these tests myself

I don't have the Flutter/Dart SDK available in the sandbox I write code in,
and it can't reach pub.dev to install one — so **I have not run `flutter
pub get` or `flutter test` against this code.** I wrote and reasoned through
every test by hand, tracing the exact state transitions the engine goes
through (e.g. working out `currentServer` and the deciding-game 5-point
switch by hand for each assertion), but "I checked it carefully" is not the
same as "it compiles and passes."

**Please run `flutter test` yourself before trusting this as correct**, and
if anything fails, send me the output — I'll fix it immediately. Given you
said you want this to be perfect, treat this as a strong first draft that
needs one real test run to confirm, not a finished, verified artifact.

A few specific things worth double-checking once you can run it:
- The `SegmentedButton` widget (used for best-of selection) has had minor
  API differences across Flutter versions — if `flutter test` complains
  about it, it's likely a version mismatch, not a logic bug.
- The deciding-game change-of-ends test (the trickiest piece of logic here)
  is the one I'd re-read most carefully if something breaks.

## Design decisions worth knowing about

- **Undo** is implemented as a snapshot stack (each point pushes a snapshot
  before applying itself), rather than trying to algebraically reverse a
  point. This is simpler to get right and cheap at this data size.
- **`currentServer`** is computed on demand from total points scored and
  who served first in the game — not stored as separate mutable state — so
  it can never drift out of sync with the score.
- **Change of ends** and **game/match completion** are reported back to the
  UI as one `PointEvent` per point, rather than the UI polling engine state
  after every tap. A completed game always implies a change of ends, so the
  UI shows one banner per point, never two stacked ones.
