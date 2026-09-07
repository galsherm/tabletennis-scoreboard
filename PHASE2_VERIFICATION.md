# Phase 2 Voice Announcement Verification

This document records a verification pass over Phase 2 (voice announcements)
before starting Phase 3, covering: score announcement ordering, consistency
of that ordering across code paths, mute-toggle correctness, and the test
suite. All findings below were confirmed empirically (disposable diagnostic
tests written, run, and then deleted — no code in the repo was changed while
producing this report) rather than by code reading alone.

**Status:** one real bug found (score announcement order around service
rotation — see §1–2). **Fixed** — see §2 for the applied change. All 53
tests pass after the fix (§4).

---

## 1. Score announcement order

*(This section describes the state as originally found. See §2 for the fix
that has since landed.)*

The order comes from a `server` value threaded through two files:

**`lib/screens/scoreboard_screen.dart:41-51` (before the fix)**
```dart
void _scorePoint(Player scorer) {
  if (!_engine.canScore) return;
  final server = _engine.currentServer;   // <-- captured BEFORE addPoint
  final event = _engine.addPoint(scorer);
  setState(() {});

  _voice.announce(announcementForPoint(
    engine: _engine,
    event: event,
    server: server,
  ));
```

**`lib/services/match_commentary.dart:68-80`**
```dart
final serverPoints =
    server == Player.one ? engine.player1Points : engine.player2Points;
final receiverPoints =
    server == Player.one ? engine.player2Points : engine.player1Points;
...
Announcement('$serverPoints, $receiverPoints', ...)
```

The order is driven entirely by `currentServer`/`firstServerThisGame` (not by
"Player 1" on screen, not by who scored the point) — that part was correct.

**But it was not the server-about-to-serve-next.** `server` was read
*before* `addPoint()` mutated the engine, and was never refreshed afterward,
so it identified whoever served the point that was **just played**, not
whoever is about to serve the next point.

## 2. Consistency across code paths

`currentServer` evaluated before a point and `currentServer` evaluated after
the same point are only the same player when the point does *not* cross a
service-rotation boundary. They differ on:

- every 2nd point pre-deuce (service rotates every 2 points), and
- **literally every single point once both players reach 10** (service
  rotates every 1 point at deuce).

This was confirmed concretely with the real engine:

| Scenario | pre-point server used (current behavior) | produces | "who serves next" would produce |
|---|---|---|---|
| 9-9, P1 scores → 10-9 | Player.two | `"9, 10"` | `"10, 9"` |
| 10-10 deuce, P1 scores → 11-10 | Player.one | `"11, 10"` | `"10, 11"` |

A 30-point mixed sequence run through the real engine showed pre-point and
post-point server **disagreeing on 20 of 30 points**. During deuce
specifically they disagree on 100% of points, since service rotates every
point there.

Standard table tennis umpiring calls the score with whoever is **about to
serve next** named first — that's the functional point of the convention,
since it tells the players/listener who serves next. Using the pre-point
value means the announcement is backwards specifically on rotation-boundary
points, i.e. the majority of points in any deuce-heavy game.

There is exactly **one** root cause (one stale value, read at one call
site) — this is not a case of multiple code paths disagreeing with each
other, so the bad behavior is fully deterministic and reproducible (always
wrong on rotation-boundary points, always right otherwise), not randomly
unpredictable. A user would clearly notice it every time a game goes to
deuce, since every single deuce-phase announcement is affected.

**Test coverage gap:** `test/match_commentary_test.dart`, in "orders the
numbers by server first, not by who just scored," uses a 1-1 tie as its
example. Both conventions (pre-point and post-point server) produce the same
string by coincidence at a tie, so that test does not actually catch this
bug. This is a real gap in the Phase 2 test suite, not just a documentation
note.

**Verdict: this was a bug**, not a style/comment issue.

**Fix applied.** In `_scorePoint` (`lib/screens/scoreboard_screen.dart`),
`server` is now read *after* calling `addPoint`:

```dart
final event = _engine.addPoint(scorer);
final server = _engine.currentServer; // who serves next, not who just served
```

This was safe because `server` is never consumed by the `matchCompleted` /
`gameCompleted` branches of `announcementForPoint` (those use player labels,
not server-ordered numbers) — only the ordinary-score, mid-game
change-of-ends, and match-point branches use it, and all three want "who
serves next." The doc comment on `announcementForPoint`
(`lib/services/match_commentary.dart`) was also updated to describe the
corrected contract ("who serves next," not "whoever served that point").

The masking test gap was also fixed: "orders the numbers by server first,
not by who just scored" in `test/match_commentary_test.dart` now uses the
10-10 → 11-10 deuce scenario from the table above (a genuine
rotation-boundary point, not a tie) and asserts
`expect(serverWhoJustServed, isNot(serverWhoServesNext))` as a guard, so the
test can no longer pass by coincidence if the scenario ever stopped crossing
a rotation boundary.

## 3. Mute toggle

Confirmed via a live widget-driven diagnostic:

- Scored 2 points unmuted → 2 announcements logged.
- Muted, then scored 16 more points (through 9-9) → **zero** new entries;
  the spoken log was byte-for-byte identical before and after.
- Unmuted and continued through deuce → 3 new announcements appeared.
- Toggled mute 3 times rapidly mid-deuce, then scored again → no exception
  (`tester.takeException()` was `null` throughout), and the final point was
  correctly suppressed (an odd number of toggles left the announcer muted).

Mechanically this holds because every announcement funnels through the
single `if (_muted) return;` gate at the top of `VoiceAnnouncer.announce()`
(`lib/services/voice_announcer.dart:74-75`), and `setMuted(true)` also calls
`_tts.stop()` / `_clips.stop()`, both wrapped in `.catchError((_) {})`, so an
in-flight announcement is cut off without throwing.

**Confirmed:** mute blocks 100% of announcements (not just some), and
toggling mid-match — including mid-deuce and rapid repeated toggling —
causes no errors.

## 4. Test suite

Original verification pass (before the fix, no code changed while producing
that part of this report):

```
00:04 +53: All tests passed!
```

Re-run after applying the §2 fix and rewriting the masking test:

```
00:07 +53: All tests passed!
```

All 53 tests pass both before and after the fix (29 from Phase 1 + 24 from
Phase 2) — the count is unchanged because the fix corrected existing
behavior rather than adding new cases, and the rewritten test replaces the
old masking test one-for-one.
