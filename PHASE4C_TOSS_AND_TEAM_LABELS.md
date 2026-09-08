# Phase 4C: Coin-Flip Animation & Doubles Team-Label Wording

Two related UI/UX fixes from user testing and competitor research: a brief
coin-flip flourish before the toss result is revealed, and a wording split
so doubles' toss result and win banners say "Team 1"/"Team 2" instead of
the ambiguous "Player 1"/"Player 2" (which reads as one specific person
when 4 players are on screen). No player-name customization in this pass
— deliberately deferred to a later phase.

**Status:** built and passing (119/119 tests — 108 pre-existing +
11 new covering these two features specifically). Updated after a
post-ship terminology correction — see §7.

---

## 1. Coin-flip animation

**`lib/widgets/coin_flip_indicator.dart`** (new): a 700ms flourish shown
in place of the toss result while it's "settling." Three full rotations
around the vertical axis (`Matrix4.rotateY`) with a shallow perspective
entry (`setEntry(3, 2, 0.0018)`) so the spin reads as a 3D coin tumbling
rather than a flat spin, plus a small scale "hop" (1.0 → 1.18 → 1.0,
peaking at the midpoint) suggesting the coin lifting and landing. Curve is
`Curves.easeOutCubic` so it settles with a gentle deceleration rather than
stopping abruptly. Under a second total, as requested — the one polished
flourish, not a delay.

**Why `TweenAnimationBuilder`, not `AnimatedSwitcher` (repeating the
Phase 4B lesson deliberately, per your instruction):** Phase 4B's
score-pop animation was originally built with `AnimatedSwitcher` and hit
`Bad state: too many elements` in widget tests, because `AnimatedSwitcher`
keeps the outgoing and incoming child mounted simultaneously during its
crossfade — two widgets carrying the same test `Key` at once. The fix
there was a single `TweenAnimationBuilder` mount per state change instead.
`CoinFlipIndicator` follows that exact pattern from the start: one
`TweenAnimationBuilder`, keyed by the caller (`ValueKey(_tossSequence)` in
`SetupScreen`) so a repeated toss gets a fresh mount rather than updating
in place, and `onEnd` (confirmed present on `TweenAnimationBuilder` in
this Flutter SDK) fires the completion callback once — no manual `Timer`.

**`lib/screens/setup_screen.dart`**: the toss result is now a small state
machine. `_tossCoin()` decides the winner immediately into `_pendingResult`
(so the actual outcome is determined at tap time, not animation-dependent)
but sets `_isFlipping = true` and clears `_firstServer`, withholding the
result from the UI and from "Start match" (`onPressed: _firstServer == null
? null : _start`) until `_onCoinFlipComplete()` — `CoinFlipIndicator`'s
`onEnd` — copies `_pendingResult` into `_firstServer`. While flipping, the
result `Text` is replaced by the `CoinFlipIndicator`; the swap is a
straight conditional, not `AnimatedSwitcher`, so there's never a moment
with two result widgets mounted.

**Layout note caught before it became a bug**: the toss-result slot is
deliberately *not* height-constrained. `tossPrompt` wraps to two lines in
German and French (confirmed in Phase 4B's screenshots), so an early draft
that wrapped the coin and text in a fixed-height `SizedBox` would have
clipped the prompt in those languages. Removed the fixed height; the coin
sits in a `Padding` on its own instead.

## 2. Doubles team-label wording

**New ARB strings** (`team1Label`/`team2Label`) in `app_en.arb`
("Team 1"/"Team 2"), `app_de.arb` ("Team 1"/"Team 2" — see §4), and
`app_fr.arb` ("Paire 1"/"Paire 2" — corrected from an initial "Équipe
1"/"Équipe 2," see §7), added after `player4Label` and matching its
naming pattern. Regenerated via `flutter gen-l10n`.

**`lib/screens/setup_screen.dart`**: `_sideLabel(l10n, player)` picks
`team1Label`/`team2Label` when `_isDoubles` is true, otherwise
`player1Label`/`player2Label` — used only for the toss-result text
(`firstServerLabel`). The doubles player-slot preview under the mode
toggle still shows the four individual `player1Label`–`player4Label`
names, unchanged.

**`lib/screens/doubles_scoreboard_screen.dart`**: `_teamLabel(team)`
resolves the same two strings, used by both `_showGameCompleteBanner` and
`_showMatchCompleteDialog` in place of the old `player1Label`/
`player2Label`. The 4-player on-court display (`_DoublesTeamZone`,
`_DoublesPlayerRow`) and their serve/receive icons are untouched — they
already correctly identify which of the 4 individuals is serving or
receiving, and continue to show "Player 1"–"Player 4."

**Deliberate wording split, voice vs. banner**: `CommentaryStrings` (voice
announcements) is untouched per Phase 4/4B scope and still says "Player 1"/
"Player 2" for doubles, via the same singles-shaped commentary templates.
So for the same event, the spoken announcement and the on-screen banner
now use different wording for the winning side. This is called out
explicitly (also as a doc comment on `DoublesScoreboardScreen`) because
it's an intentional, scoped decision — redesigning doubles voice wording
was out of scope for this pass, exactly as it was for Phase 4 and 4B.

## 3. Tests added

New file `test/toss_and_team_labels_test.dart`, 11 tests:

- **Coin-flip timing** (4 tests): the result stays hidden and "Start
  match" stays disabled one frame after tapping toss, then both become
  available after `pumpAndSettle`; the flip settles well under 1 second
  (advancing the clock ~950ms is enough); repeated partial pumps through
  the flip never throw (guards against the `AnimatedSwitcher`-style
  double-mount failure mode from Phase 4B); tossing a second time after a
  result restarts the flip cleanly.
- **Team-label wording** (7 tests): doubles toss result shows "Team 1" or
  "Team 2" and never "Player 1"/"Player 2"; singles toss result is
  unchanged ("Player 1"/"Player 2", never "Team"); switching mode after
  tossing relabels the same already-chosen side; the doubles
  game-complete snackbar says "Team 1"/"Team 2" (the match-complete
  dialog case was already covered, and updated, in
  `doubles_widget_test.dart` — see below); the 4 individual on-court
  labels stay "Player 1"–"Player 4" in doubles and never show "Team 1"/
  "Team 2"; German and French doubles toss results show "Team 1"/"Team 2"
  and "Paire 1"/"Paire 2" respectively (the French assertion was updated
  along with the string itself — see §7).

**Existing tests fixed** (timing, not behavior, except one):
`test/widget_test.dart`, `test/doubles_widget_test.dart`, and
`test/localization_widget_test.dart` all had a `tester.pump()` immediately
after tapping `tossButton`, then checked `startMatchButton.onPressed` or
tapped it — valid before this phase, when the toss result was set
synchronously. Changed each to `tester.pumpAndSettle()` so the flip
animation completes first. Separately, `doubles_widget_test.dart`'s
match-complete-dialog test asserted `'Player 1 wins the match!'`, which is
an expected consequence of §2's wording change, not a timing issue —
updated to `'Team 1 wins the match!'`.

## 4. Terminology flagged for review

- German `team1Label`/`team2Label` use the English loanword "Team" rather
  than a native German word, matching the same judgment call already made
  for "Best of" earlier in the project. Should be confirmed against native
  German table-tennis usage. (Still open — no change in this pass.)
- ~~French uses "Équipe 1"/"Équipe 2"...~~ — resolved via research; see §7.

## 5. Test results

```
flutter analyze → No issues found!
flutter test    → 00:11 +119: All tests passed!
```

119/119 (108 pre-existing + 11 new). No regressions. (Re-run after the
§7 correction, still 119/119.)

## 6. Scope confirmation

No player-name customization was added — both features use the existing
numbered Player/Team labels only, per your instruction to defer name
customization to a later phase. No scoring logic, doubles rotation logic,
or existing localization wording (beyond the two new `team1Label`/
`team2Label` strings) changed.

## 7. Correction: French "Équipe" → "Paire"

Found via further research after this phase shipped: "Équipe" is not the
right French word for a doubles pairing — it specifically denotes a club
*team* (3+ players in league team competition), a distinct concept from
the two-player pairing that plays a doubles match. Authoritative French
table-tennis sources (FFTT-based glossaries) consistently use "paire" for
the doubles pairing itself, e.g. "Match : rencontre entre deux joueurs
(simple) ou deux paires (double)."

**Fix**: `app_fr.arb`'s `team1Label`/`team2Label` changed from "Équipe
1"/"Équipe 2" to "Paire 1"/"Paire 2"; regenerated via `flutter gen-l10n`.
Updated the corresponding assertion in
`test/toss_and_team_labels_test.dart` ("French doubles toss result says
'Paire 1'/'Paire 2'"). German's "Team 1"/"Team 2" is unaffected — verified
separately as correct, since German table-tennis sources do use "Team"
naturally for a doubles pair, unlike French. `flutter analyze` and
`flutter test` re-run clean (119/119) after the fix.
