# Table Tennis Scoreboard — Phase Plan

Full build plan, phase by phase. Each phase notes what to build, what to
explicitly defer, and why — so whoever/whatever implements it (including a
future Claude session working directly in this codebase) has the context
without needing the original research reports.

**Status:** Phases 1–4 complete and verified (108/108 tests passing). See
PHASE3_VERIFICATION.md for the full German/French string list, confidence
flags for a native-speaker review, and one open item (no real German/French
bundled voice clips ship yet — architecture only, see that doc §4).
PHASE4_VERIFICATION.md documents doubles' rotation derivation and several
scope decisions flagged for review (fixed partner order for the match,
generic "Player 1"/"Player 2" wording in doubles game/match-won
announcements).

---

## Phase 1 — Core scoring engine + UI ✅ DONE

**Built:** Singles scoring engine (`lib/models/scoring_engine.dart`):
points → games (11, win-by-2, deuce) → match (best-of-3/5/7), serve
rotation (every 2 points, every 1 at deuce — ITTF Law 2.13.3), change of
ends (after every game, plus mid-game at 5 points in the deciding game —
Law 2.14), undo (snapshot stack), reset. Two-tap UI
(`lib/screens/scoreboard_screen.dart`, `lib/screens/setup_screen.dart`):
large tap zones, server indicator, undo/reset buttons, game/match
completion banners. Unit tests (`test/scoring_engine_test.dart`) and
automated widget tests (`test/widget_test.dart`).

**Deferred:** everything below.

---

## Phase 2 — Voice announcements ✅ DONE

**Built:** `flutter_tts` + `audioplayers` dependencies. A pure commentary
layer (`lib/services/match_commentary.dart`) that decides what to say from
engine state alone (score, "Deuce" once tied at 10+, "Game"/"Change ends"
on game completion, "Match point" whenever the next point could end the
match, match-won) — unit-tested with no TTS/audio involved. A
`VoiceAnnouncer` (`lib/services/voice_announcer.dart`) that speaks via the
device voice when a matching language is installed (checked through
`TtsEngine.isLanguageAvailable`, `lib/services/tts_engine.dart`) and
otherwise falls back to a bundled English clip set
(`assets/audio/en/*.wav` — numbers 0–21 plus "Game", "Change ends",
"Deuce", "Match point", synthesized offline via Windows SAPI as
placeholder-quality real speech, not TTS-at-runtime); any TTS/audio
failure is swallowed so voice never crashes or blocks scoring. A mute
toggle in the scoreboard app bar (`muteButton`) stops any in-flight
speech/clip immediately. `ScoreboardScreen` takes an optional
`voiceAnnouncer` for test injection. Tests in `test/match_commentary_test.dart`,
`test/voice_announcer_test.dart`, `test/scoreboard_voice_widget_test.dart`.

**Original build scope:**
- Add `flutter_tts` dependency (native platform TTS — free, works offline
  once the language voice pack is installed on-device).
- After each point, announce the new score (e.g. "5, 3" or localized
  equivalent) via TTS.
- Announce key events: game won, match won, "change ends".
- A mute toggle in the scoreboard screen's app bar — TTS must never
  auto-play if the user has muted it, and should not interrupt/duck
  other audio (e.g. music) more than necessary.
- Detect whether the device has the needed voice installed via
  `flutter_tts`'s `isLanguageAvailable`; if not available, fail gracefully
  (no crash, silently skip voice) rather than blocking the UI.
- Bundle a small set of pre-recorded/pre-synthesized audio clips for
  numbers 0–21 plus key phrases ("Game", "Change ends", "Deuce", "Match
  point") in English, as a fallback/complement to live device TTS — this
  guarantees consistent quality regardless of which voice is installed on
  a given phone.

**Defer:** cloud TTS APIs, non-English clip sets (that's Phase 3), custom
voice selection UI.

**Why:** Voice is the single most-requested and most-praised feature
across every competitor reviewed in research — and also the easiest
feature to get wrong (competitors were criticized for voice that can't be
muted or that hijacks music playback), so the mute toggle and graceful
fallback are not optional extras.

---

## Phase 3 — Native German & French localization ✅ DONE

**Built:** `flutter_localizations` + `intl`, ARB files under `lib/l10n/`
(`app_en.arb` template, `app_de.arb`, `app_fr.arb`), generated via
`flutter gen-l10n` into `lib/l10n/gen/app_localizations.dart`. Every UI
string in `setup_screen.dart`/`scoreboard_screen.dart` now goes through
`AppLocalizations.of(context)`. Voice announcements extended to German and
French: `CommentaryStrings` (`lib/services/commentary_strings.dart`) holds
the phrase templates + TTS locale + clip-folder name per language;
`match_commentary.dart` and `voice_announcer.dart` take/use it instead of
hardcoded English. Language auto-detected from device locale via an
explicit `localeListResolutionCallback` in `main.dart` (see below — the
implicit Flutter default was found to fall back to the wrong language),
with a manual override in `SetupScreen`'s app bar (System default /
English / Deutsch / Français). See PHASE3_VERIFICATION.md for the full
string list (flagged for native review), and two real bugs found and fixed
in this phase's own new code: `PopupMenuButton` silently ignoring a
`null`-valued menu selection (broke the "System default" option), and
Flutter's default locale-fallback landing on German rather than English
for an unsupported device locale (fixed with the explicit callback above).
Tests in `test/localization_widget_test.dart` plus additions to
`test/match_commentary_test.dart` and `test/voice_announcer_test.dart`.

**Original build scope:**
- Flutter's standard localization setup (`flutter_localizations` +
  `.arb` files, or an equivalent i18n package) for UI strings.
- Human-quality (not machine-translated) German and French strings using
  correct table-tennis terminology:
  - German: *Aufschlag* (serve), *Aufschlagwechsel* (change of serve),
    *Seitenwechsel* (change of ends), *Satzball* (game point), *Matchball*
    (match point).
  - French: *service*, *changement de service*, *changement de côté*,
    *balle de set*, *balle de match*.
- Voice announcements (from Phase 2) in German and French — extend the
  pre-recorded clip set to these two languages; get a short native-speaker
  review pass before shipping (a few minutes of listening, not a
  translation job, since the vocabulary is tiny and repetitive — see the
  MVP doc's "no dedicated translation API needed" note).
- Language auto-detected from device locale, with a manual override in
  settings.

**Defer:** any language beyond English/German/French for now; RTL
language support.

**Why:** This is the actual differentiating "wedge" identified in
research — proven demand in Germany/France (DTTB: ~527,000 members) with
no genuinely native-quality competitor app. Shipping English-only
undersells the whole thesis.

---

## Phase 4 — Doubles support ✅ DONE

**Built:** `TableTennisScoringEngine` reused completely unchanged for
doubles scoring (it only ever knows about two *sides*; one new getter,
`firstServerThisGame`, was added — purely additive, exposes state already
tracked). Doubles rotation (`lib/models/doubles_seat.dart`,
`lib/services/doubles_rotation.dart`) is a pure function of the engine's
current score: a fixed 4-step server/receiver cycle (A→C, C→B, B→D, D→A)
derived from and verified against the "previous receiver becomes server,
previous server's partner becomes receiver" rule — see
PHASE4_VERIFICATION.md §1a for the full derivation. New
`DoublesScoreboardScreen` (parallel to `ScoreboardScreen`, reusing the
same engine/voice/locale wiring) shows all 4 players with server
("Aufschlag"/"Serving"/"Service") and receiver
("Annahme"/"Receiving"/"Réception", new) icons. `SetupScreen` gained a
Singles/Doubles mode toggle and a 4-player preview. Voice announcements
untouched — same score/deuce/change-ends/match-point system as singles,
in all three languages. Tests in `test/doubles_rotation_test.dart` (11,
the rotation logic) and `test/doubles_widget_test.dart` (14, setup +
scoreboard UI). See PHASE4_VERIFICATION.md for design decisions flagged
for review (fixed partner order per side for the whole match rather than
re-chosen each game; game/match-won banners say generic "Player
1"/"Player 2" rather than the specific pair's names, to stay consistent
with voice, which wasn't redesigned).

**Original build scope:**
- Extend the scoring engine (or add a parallel doubles engine reusing the
  same core rules) for 4 players: service rotates through all 4 players
  every 2 points (every 1 at deuce), with the server always serving
  diagonally into the receiver's right half-court (ITTF Law 2.06.3 /
  2.13.6).
- UI: 4 name/color slots instead of 2, clear indication of the current
  server + receiver pairing (not just "whose turn," since in doubles the
  serve/receive assignment rotates through a fixed 4-player cycle).

**Defer:** team-match orchestration (multiple doubles/singles rubbers
making up one team event) — this is exactly the complexity trap that made
a competitor app ("Score Table Tennis") get criticized as
over-engineered. Keep doubles to a single match.

**Why:** A well-bounded rules addition (the ITTF laws for doubles rotation
are precise and finite) that meaningfully broadens who can use the app,
without the runaway scope of full tournament/team management.

---

## Phase 5 — Monetization

**Build:**
- AdMob integration: at most one discreet banner, or a single interstitial
  shown only at match-end — never mid-match, never using
  location-targeting (the single most common complaint across every
  competitor reviewed).
- One one-time in-app purchase, "Remove Ads / Pro" (~€2.99, localized
  pricing), unlocking: ad removal, extra themes/colors, match-history
  export.
- Optional: a rewarded-ad path ("watch one ad to unlock Pro for this
  session") as a soft on-ramp before asking for the purchase.

**Defer:** subscriptions entirely. (Research finding: the one direct
competitor using a subscription model, SmartScorer, is stuck at ~1,000
installs vs. 50,000–100,000+ for ad-supported one-time-purchase
competitors — subscriptions appear to suppress adoption in this specific
category.)

**Why:** Matches the proven pricing pattern in this niche (darts
scoreboards etc. overwhelmingly use one-time unlocks) and keeps the app's
core promise (no signup, no recurring charge) intact.

---

## Phase 6 — Club / federation go-to-market

**Not code — distribution work:**
- A short German + French one-page landing site with a demo video.
- Pitch **myTischtennis.de** and regional Landesverband news editors for
  an app-roundup mention.
- Contact the DTTB's Sportentwicklung / "Frei.Zeit.Tischtennis!" desk,
  positioned explicitly for **recreational/school/outdoor play** — not
  sanctioned league scoring (the DTTB has an official free league-scoring
  solution, Scorix, rolling out from the 2025/26 season — don't compete
  with it, position around it).
- Native-language ASO: store listing title/description/keywords in German
  and French, not just the in-app UI.

---

## How to hand a phase to Claude Code (or any coding assistant) in your IDE

Paste this (edit the phase number/description) as your prompt, from
inside the project root:

> I'm building on top of an existing Flutter table tennis scoreboard app.
> Phases 1–4 (core scoring engine + UI, voice announcements, German/French
> localization, doubles support) are done and all tests pass — see
> `PHASES.md` in this repo for the full phase plan and
> `lib/models/scoring_engine.dart` for the existing scoring engine's API
> (don't break its existing public interface or tests unless the phase
> requires it). Please implement **Phase 5 — Monetization** exactly as
> scoped in `PHASES.md`: AdMob integration (one discreet banner or a
> single match-end interstitial, never mid-match), and a one-time "Remove
> Ads / Pro" in-app purchase. Add unit/widget tests for the new behavior
> alongside the existing tests in `test/`. Keep changes scoped to this
> phase — don't start subscriptions or Phase 6's distribution work.

Swap "Phase 5 — Monetization" and its description for whichever phase
you're starting next.
