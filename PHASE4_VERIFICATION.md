# Phase 4 Verification: Doubles Support

This document records what was built for Phase 4 (doubles), the design
decisions made where the phase spec left room for judgment (flagged for
your review), test results, and anything found along the way.

**Status:** built and passing (108/108 tests: the 83 from Phases 1–3,
plus 11 new doubles-rotation unit tests and 14 new doubles widget tests).
No bugs found in existing code this time — the rotation logic was derived
and hand-verified against the standard ITTF doubles sequence *before*
writing the implementation (§1), and every test passed on the first real
run once one trivial missing-import compile error was fixed. §4 has since
been corrected: both the German and French receiver terms were wrong,
caught via external research citing DTTB's and FFTT's own official rules
text. Several design decisions were made where the spec allowed judgment;
§3 lists them for your review, most notably §3.1 (fixed partner order for
the whole match, not re-chosen each game) and §3.2 (doubles game/match-won
announcements say "Player 1"/"Player 2" generically, not the specific
pair's names).

---

## 1. What was built

**Engine (`lib/models/scoring_engine.dart`):** one new getter,
`Player get firstServerThisGame`, exposing state the engine already
tracked privately. Purely additive — no existing method, field, or
behavior changed, so every existing singles test needed no changes and
all still pass. `TableTennisScoringEngine` itself is otherwise completely
unchanged and is reused as-is for doubles: it only ever scores two
*sides*, so nothing about doubles' four individual players affects
points, games, match completion, or the deciding-game mid-game
change-of-ends — those are the same engine, same code path, for both
modes.

**Doubles rotation (`lib/models/doubles_seat.dart`,
`lib/services/doubles_rotation.dart`, new):** `DoublesSeat` identifies one
of the four players (a `team` — `Player.one`/`Player.two`, matching the
engine's side — plus a `slot`, 0 or 1, for which partner). A pure function,
`currentDoublesServingState(engine)`, computes who serves and who
receives right now from the engine's current score and
`firstServerThisGame` alone — no extra state to track, so it's
automatically correct across undo and game boundaries for free (both
already correctly restore/reset the state this reads). See §1a for the
derivation and how it was checked.

**UI:**
- `lib/screens/setup_screen.dart`: a new Singles/Doubles mode toggle
  (`modeSelector`), and — only when Doubles is selected — a static preview
  of the four player slots ("Player 1"/"Player 2" for one side, "Player
  3"/"Player 4" for the other). The existing best-of selector, coin toss,
  and start button are shared/reused unchanged for both modes; starting a
  doubles match navigates to a new `DoublesScoreboardScreen` instead of
  the existing `ScoreboardScreen`.
- `lib/screens/doubles_scoreboard_screen.dart` (new): a parallel screen to
  `ScoreboardScreen`, reusing the same engine, `VoiceAnnouncer`,
  `CommentaryStrings`, and locale-detection wiring verbatim. Each side
  shows its two players stacked, with a serving icon (🏓, reusing the
  existing "Aufschlag"/"Serving"/"Service" tooltip) on whichever one of
  the four is currently serving, and a new receiving icon (↩, new
  "Rückschläger"/"Receiving"/"Relanceur" tooltip — corrected from an
  initial wrong choice, see §4) on whichever one is currently the
  designated receiver — never more than one of each, and never both on
  the same two people twice on either side (see the rotation cycle below).
- New ARB keys (`app_en.arb`/`app_de.arb`/`app_fr.arb`): `player3Label`,
  `player4Label`, `receivingTooltip`, `modeSinglesOption`,
  `modeDoublesOption` — following the exact existing pattern, no hardcoded
  English anywhere in the new screens.

**Voice:** completely unchanged. `VoiceAnnouncer.announcePoint` and
`announcementForPoint` are called identically for doubles as for singles
— same score announcements, same "Deuce"/"Change ends"/"Match point"
phrasing, same three languages. See §3.2 for the one consequence of not
touching this: game/match-won announcements refer to "Player 1"/"Player
2" (the side), not to the specific pair of names shown on the
4-player board.

### 1a. Deriving and verifying the rotation rule

The prompt's rule — "the previous receiver becomes the new server, and
their partner becomes the new receiver" — is ambiguous about whose
partner ("their" could mean the new server's or the previous server's). I
resolved this by deriving both readings against the well-known correct
ITTF doubles sequence for a first server A (partner B) versus a first
receiver C (partner D): **A→C, C→B, B→D, D→A**, repeating.

Checking "new receiver = new server's partner" against this sequence
fails immediately (after A→C, it would predict C→D, but the real sequence
is C→B). Checking "new receiver = *previous* server's partner" matches
every step:
- A→C, then new server = C (previous receiver ✓), new receiver = A's
  partner = B ✓ (matches C→B)
- new server = B (previous receiver ✓), new receiver = C's partner = D ✓
  (matches B→D)
- new server = D ✓, new receiver = B's partner = A ✓ (matches D→A, and
  the cycle closes back to A→C)

This confirmed rule — new server = previous receiver, new receiver =
*previous server's* partner — is what's implemented, expressed as a fixed
4-step lookup table (`_rotationCycle` in `doubles_rotation.dart`) indexed
by `blockIndex % 4` (`blockIndex` being the exact same quantity singles'
`currentServer` already computes: total points so far, divided by 2
points per block pre-deuce or 1 point per block at deuce). This is why
doubles rotation reuses `firstServerThisGame` and simple arithmetic on
public engine state rather than needing any new engine-side bookkeeping.

`test/doubles_rotation_test.dart` additionally verifies this rule
*generically* (not just against hardcoded expected values) — it asserts
`current.server == previous.receiver` and
`current.receiver == previousServerPartner` across 8 consecutive rotation
blocks, so the test would fail if the rule were ever violated regardless
of which specific seats are involved.

## 2. Test results

```
flutter analyze → No issues found!
flutter test    → 00:05 +108: All tests passed!
```

108 tests total: 83 from Phases 1–3 (all still passing, unchanged) + 25
new —

- `test/doubles_rotation_test.dart` (11 tests): the fixed A→C/C→B/B→D/D→A
  sequence pre-deuce (every 2 points) and at deuce (every 1 point,
  including the exact transition point into deuce); the "previous
  receiver becomes server, previous server's partner becomes receiver"
  rule verified generically across 8 blocks; behavior across a game
  boundary (next game's first-serving side flips, per singles' existing
  rule, reused unchanged); undo compatibility across both a rotation
  boundary and a game boundary; and symmetry starting from the other side.
- `test/doubles_widget_test.dart` (14 tests): the setup screen's mode
  toggle and 4-player preview (shown/hidden correctly, localized in all
  three languages); starting a doubles match navigates to the 4-player
  scoreboard; scoring only affects the tapped side and reuses the engine's
  game math (a best-of-3 match-complete dialog test, structurally
  identical to the existing singles one); voice announcements fire
  unchanged; server/receiver tooltips render the correct localized word;
  and the server icon visits all 4 players exactly once across a full
  rotation cycle.

No existing test was modified or deleted — every one of the 83 pre-Phase-4
tests passes as-is.

## 3. Design decisions flagged for your review

The phase spec left some real-world doubles details unspecified for a
scoreboard app (as opposed to a rules-enforcing referee tool). Here's
where I made a judgment call, and why.

### 3.1 Fixed partner order for the whole match, not re-chosen each game

Real ITTF doubles lets each pair choose who serves/receives first *at the
start of every game* (not just the first). This app fixes each side's
"slot 0" as whoever serves first *whenever that side serves first in a
game* — i.e., the same two structural roles are reused every game, rather
than prompting players to re-pick each time. Combined with the existing
(unchanged) singles rule that the next game's first-serving side is the
opponent of this game's, this fully determines the whole match's rotation
from a single setup-time choice (the coin toss), with no extra UI. This
was a deliberate scope simplification, not an oversight — a "who serves
first this game" prompt every game would be more accurate but adds UI
complexity the phase didn't ask for. Flagging in case you'd like that
prompt added later.

### 3.2 Game/match-won text says "Player 1"/"Player 2," not the pair's names

The phase spec says to reuse Phase 2/3's voice/announcement system rather
than redesign it for doubles. That system's `gameCompleteMessage`/
`matchCompleteMessage` templates and `CommentaryStrings.playerLabel` take
a single generic side name ("Player 1"/"Player 2"), unchanged from
singles. Meanwhile the on-court 4-player display numbers all four
individuals 1–4 (side one = Player 1 & Player 2, side two = Player 3 &
Player 4). I kept these consistent with *each other* by having doubles'
banners/dialogs *also* say "Player 1"/"Player 2" (reusing exactly the
same strings and meaning "side 1"/"side 2," not literally "the individual
labeled Player 1") rather than inventing a compound "Player 1 & Player 2"
name — the alternative would have required a new ARB joiner key and would
still disagree with what voice says (voice can't be changed, per scope),
so I judged consistency between the banner and the spoken announcement to
matter more than the banner matching the on-court numbering exactly. A
user could reasonably read "Player 1 wins the match!" and wonder why it
doesn't name both people on that side — flagging this explicitly as the
tradeoff made, not a hidden gap.

### 3.3 No custom player names — reused the app's existing "Player N" pattern

Singles has never had free-text name entry (Phases 1–3 use generic
localized "Player 1"/"Player 2" labels throughout, no customization
anywhere in the app). The phase's original PHASES.md wording ("4 name/color
slots instead of 2") suggested extending *existing* name customization,
but no such feature actually exists to extend. Rather than introduce new
scope (a text-entry UI, with its own localization/validation concerns) not
explicitly requested in the phase instructions given to me, I extended the
existing generic-label pattern to four slots ("Player 1"–"Player 4")
instead. Flagging in case real name entry is wanted as a follow-up.

### 3.4 No visual "Team 1"/"Team 2" heading

The 4-player board groups each side's two players spatially (stacked,
side-by-side halves, same tap-to-score zones as singles) without an
explicit "Team 1"/"Team 2" text heading above them. This seemed
sufficient given each side's two players are already visually grouped and
share one score, but a heading would be a low-risk addition if you'd
prefer one.

## 4. Terminology note

The only new user-facing vocabulary this phase introduced was "Receiving"
(English) and its German/French counterparts for `receivingTooltip`. Both
of my original choices were wrong, in the same way, and have been
corrected.

**What was wrong:** the initial choices — German "Annahme," French
"Réception" — each name the *technique* of returning a serve (the skill),
not the *role/person* doing it. The receiving tooltip labels a specific
player, so it needs the role noun, not the technique noun. Both were
originally flagged here as "moderate-high confidence, not independently
verified" — that caution turned out to be warranted.

**How it was caught:** external research, not native-speaker review —
same pattern as Phase 3's "Einstand"/"Gleichstand" correction. Official
sources for the receiving *role* are consistent: DTTB's own tischtennis.de
and FFTT's own official rules PDF both use the dedicated role noun rather
than the technique word — **Rückschläger** (German) and **relanceur**
(French).

**Fix applied:** `receivingTooltip` changed from "Annahme"/"Réception" to
"Rückschläger"/"Relanceur" in `lib/l10n/app_de.arb` and `app_fr.arb` (the
only place either word was used), regenerated via `flutter gen-l10n`.
`test/doubles_widget_test.dart` had one test asserting the old German
tooltip text ("server/receiver tooltips use the German terms Aufschlag
and Annahme"); updated to assert "Rückschläger." No French test asserted
the literal old string, so no other test changes were needed.

```
flutter analyze → No issues found!
flutter test    → 00:07 +108: All tests passed!
```

Test count unchanged (108) — this was a value correction, not new
coverage, exactly like Phase 3's deuce-term fix.

Everything else in this phase reused already-established,
already-flagged-or-confirmed vocabulary from Phase 3 (Aufschlag,
Seitenwechsel, Spielformat, Sätze, Spieler N, Manche, Joueur N, etc.) — no
other new domain terms.
