# Phase 3 Verification: Native German & French Localization

This document records what was built for Phase 3 (localization), the full
list of German/French strings added (for native-speaker review — see the
note at the top of PHASES.md: I don't read German/French fluently enough to
verify terminology myself), which strings are flagged as guesses rather
than confirmed terminology, test results, and two real bugs found and fixed
during implementation.

**Status:** built and passing (83/83 tests). Two real bugs found in this
phase's own new code during verification (not pre-existing) — both fixed,
see §5. A follow-up verification pass (§7) confirmed locale fallback for
unsupported/RTL languages (Spanish, Arabic) works correctly and added two
more tests. §8 corrects a wrong German deuce term found via external
research. §9 adapts the German best-of-N selector to say "Gewinnsätze"
(games needed to win) instead of the raw best-of-N number, matching how
German table tennis sources actually describe match format. One scope
decision needs your confirmation before Phase 4: no real German/French
bundled voice clips ship yet (see §4).

---

## 1. What was built

- **Localization scaffolding**: `flutter_localizations` + `intl`, ARB files
  under `lib/l10n/` (`app_en.arb` template, `app_de.arb`, `app_fr.arb`),
  `l10n.yaml` configured for non-synthetic generated output
  (`lib/l10n/gen/app_localizations.dart`, imported normally as
  `package:tabletennis_scoreboard/l10n/gen/app_localizations.dart`).
- **All existing UI strings localized**: `lib/screens/setup_screen.dart`
  and `lib/screens/scoreboard_screen.dart` now read every string through
  `AppLocalizations.of(context)` instead of English literals — app bar
  titles, button labels, tooltips, the toss/first-server prompt, the
  game/match-complete snackbar and dialog, and the games-won count.
- **Voice announcements extended to German and French**
  (`lib/services/commentary_strings.dart`, new): a `CommentaryStrings`
  class holds the phrase templates, device-TTS locale tag, and bundled-clip
  subfolder name for one language. `lib/services/match_commentary.dart`'s
  `announcementForPoint` now takes a `CommentaryStrings` parameter instead
  of hardcoded English, so every existing Phase 2 event (score, deuce, game
  won, match won, mid-game change of ends, match point) speaks in whichever
  language is configured. `lib/services/voice_announcer.dart` picks its TTS
  locale and clip folder from the same `CommentaryStrings` object, and
  gained an `announcePoint(engine, event, server)` convenience method so
  callers don't need to know about `CommentaryStrings` directly.
- **Auto-detection + manual override**: `ScoreboardScreen` resolves
  `Localizations.localeOf(context)` once (in `didChangeDependencies`) to
  pick the matching `CommentaryStrings` for its `VoiceAnnouncer`, so voice
  language follows whatever language the UI is showing. `SetupScreen` gained
  a language-picker menu (app bar, globe icon) offering System default /
  English / Deutsch / Français; `main.dart` holds the override as `Locale?`
  state (null = follow device locale) and passes it to `MaterialApp.locale`.
- **New a11y label**: the server-indicator icon (previously untooltipped)
  now has a localized "Serving"/"Aufschlag"/"Service" tooltip — a small,
  deliberate addition beyond a literal translation pass, since it's the
  natural home for the "Aufschlag"/"service" vocabulary term and didn't
  exist as translatable text before. Flagging this explicitly since it's
  the one place this phase added a *new* (if trivial) piece of UI rather
  than translating an existing one.
- **Not added**: no "game point" (Satzball / balle de set) or "service
  change" (Aufschlagwechsel / changement de service) voice announcements.
  Phase 2 never had these as events (it only has "match point," for the
  point that could win the *match*, not "game point" for the point that
  could win the *game*), and adding them would be new gameplay logic
  affecting English too, not just a translation of existing behavior —
  which the phase's own scope note ("don't touch ... English-only behavior
  beyond what's needed to add the two new languages") rules out. The
  vocabulary is real and correct; it's just currently unused. Flagging this
  as a candidate for a future phase, not a gap in this one.

## 2. Full string list for native review

### UI strings (`lib/l10n/app_{en,de,fr}.arb`)

| Key | English | German | French |
|---|---|---|---|
| appTitle | Table Tennis Scoreboard | Tischtennis-Anzeigetafel | Tableau de score de tennis de table |
| newMatchScreenTitle | New match | Neues Spiel | Nouveau match |
| languageMenuTooltip | Language | Sprache | Langue |
| languageSystemOption | System default | Systemstandard | Système |
| bestOfLabel | Best of | Spielformat *(see §9)* | Au meilleur de |
| bestOfSegmentLabel | {bestOf} (e.g. "3") | {gamesToWin} Gewinnsätze (e.g. "2 Gewinnsätze") *(see §9)* | {bestOf} (e.g. "3") |
| tossPrompt | Toss to decide who serves first | Münzwurf, um zu entscheiden, wer zuerst aufschlägt | Tirage au sort pour décider qui sert en premier |
| firstServerLabel | First server: {player} | Zuerst am Aufschlag: {player} | Premier serveur : {player} |
| tossButton | Toss coin | Münze werfen | Tirer à pile ou face |
| startMatchButton | Start match | Spiel starten | Démarrer le match |
| scoreboardTitle | Table Tennis | Tischtennis | Tennis de table |
| muteTooltip | Mute voice | Sprachausgabe stummschalten | Couper le son |
| unmuteTooltip | Unmute voice | Stummschaltung aufheben | Activer le son |
| undoTooltip | Undo | Rückgängig | Annuler |
| resetTooltip | Reset match | Spiel zurücksetzen | Réinitialiser le match |
| servingTooltip | Serving | Aufschlag | Service |
| player1Label | Player 1 | Spieler 1 | Joueur 1 |
| player2Label | Player 2 | Spieler 2 | Joueur 2 |
| gamesCountLabel | Games: {count} | Sätze: {count} | Manches : {count} |
| changeEndsSnackBar | Change ends | Seitenwechsel | Changement de côté |
| gameCompleteMessage | {player} wins the game — change ends | {player} gewinnt den Satz — Seitenwechsel | {player} remporte la manche — changement de côté |
| matchCompleteDialogTitle | Match complete | Spiel beendet | Match terminé |
| matchCompleteMessage | {player} wins the match! | {player} gewinnt das Spiel! | {player} remporte le match ! |
| newMatchButton | New match | Neues Spiel | Nouveau match |

### Voice-only phrase templates (`lib/services/commentary_strings.dart`)

These aren't shown on screen — they're spoken (live TTS) or matched to
bundled clip keys. `$w` is the winner's player label from the table above.

| Concept | English | German | French |
|---|---|---|---|
| Score (server, receiver) | `"$s, $r"` | `"$s, $r"` | `"$s, $r"` |
| Deuce | Deuce | Gleichstand | Égalité |
| Game won | `Game, $w. Change ends.` | `Satz, $w. Seitenwechsel.` | `Manche, $w. Changement de côté.` |
| Mid-game change-ends suffix | `. Change ends.` | `. Seitenwechsel.` | `. Changement de côté.` |
| Match won | `Match. $w wins the match.` | `Spiel. $w gewinnt das Spiel.` | `Match. $w gagne le match.` |
| Match point suffix | `. Match point.` | `. Matchball.` | `. Balle de match.` |

## 3. Confidence flags — please have a native speaker check these

**High confidence** (either given directly in the phase spec's reference
vocabulary, or extremely standard/unambiguous): Seitenwechsel,
changement de côté, Matchball, balle de match, Aufschlag, service,
Spieler 1/2, Joueur 1/2, Rückgängig, Annuler, Sätze/manche (game-count
noun — corroborated by the spec's own "Satzball"/"balle de set" using the
same root words), Tennis de table, Tischtennis.

**Resolved since the initial pass:** the German deuce term (originally
"Einstand") was wrong and has been corrected to "Gleichstand" — see §8 for
the full correction. The French deuce term, "Égalité," has been separately
verified as correct and needs no change. The German best-of-N selector
(originally "Best of," flagged below as a judgment call) has also been
replaced with research-backed "Gewinnsätze" wording — see §9.

**Moderate confidence — my own choices, not given by the spec, worth a
native check:**
- **"Manche"** vs **"set"** for a French table-tennis game: I used *manche*
  (the official FFTT federation term) for `gamesCountLabel` and
  `gameCompleteMessage`/the spoken "game won" phrase. The phase spec's own
  example vocabulary uses "set" (in "balle de set" = game point), which
  isn't a feature this phase implements (see §1), so there's no direct
  conflict, but a reviewer should confirm *manche* is the term they want
  used consistently rather than *set*.
- **"Stummschaltung aufheben"** (German unmute) and **"Système"** (French
  "system default"): functional, grammatically fine, but the exact idiom a
  native speaker would prefer for a UI label is a style call I can't verify.
- The invented sentence-level phrasing for game-won/match-won voice lines
  (e.g. `"Satz, $w. Seitenwechsel."`, `"Manche, $w. Changement de côté."`)
  is *my* construction mirroring the English original's structure, not
  official umpire wording in any of the three languages — same caveat that
  applied to the English phrasing back in Phase 2.
- `matchCompleteMessage` (French) uses a plain space before `!`
  ("remporte le match !"); strict French typography uses a narrow
  no-break space there. Simplified deliberately — flagging as a minor,
  known typographic simplification, not an oversight.

**Not used, flagged for awareness rather than correction:**
Aufschlagwechsel, changement de service, Satzball, balle de set — see §1
for why (no corresponding event exists to translate).

## 4. Bundled German/French voice clips: architecture only, no audio yet

Phase 2's English clips were synthesized offline via Windows' built-in
SAPI voices. This machine only has English (US/GB) SAPI/OneCore voices
installed — no German or French voice pack — so the same approach can't
produce real German/French speech here. I attempted to install the
language packs via `Install-Language` and it failed with Access Denied
(this session's shell isn't elevated, and I have no way to elevate it).

Per your direction, I proceeded without real audio: `VoiceAnnouncer` and
`CommentaryStrings` fully support a per-language clip folder
(`assets/audio/<language>/`), and `bundledClipKeys` (numbers 0–21 + the
four phrase keys) is shared across languages. `assets/audio/de/` and
`assets/audio/fr/` don't exist yet, so on a real device with no matching
system voice, the German/French clip fallback currently plays nothing —
every clip lookup fails to find its asset and is silently skipped, exactly
like Phase 2's existing "missing voice" graceful-degradation path (see
`test/voice_announcer_test.dart`, "a language with no bundled clips yet
degrades to silence, not a crash"). Live device TTS in German/French works
normally wherever the device has that voice installed; this only affects
the *fallback* path.

To finish this: record or synthesize the same 26 clips (`number_0.wav`
through `number_21.wav`, `game.wav`, `change_ends.wav`, `deuce.wav`,
`match_point.wav`) in German and French, matching the words in §2's voice
phrase table, drop them under `assets/audio/de/` and `assets/audio/fr/`,
and add both directories to `pubspec.yaml`'s `assets:` list (mirroring the
existing `assets/audio/en/` entry) — no code changes needed.

## 5. Two real bugs found and fixed during this phase

Both are in this phase's own new code, not pre-existing issues.

**Bug A — the "System default" language option could never actually be
selected.** The language-picker menu originally used `PopupMenuButton
<Locale?>` with `value: null` for "System default." Flutter's own
`PopupMenuButton` treats a `null` selection identically to the menu being
dismissed with no choice made (`popup_menu.dart` calls `onCanceled`
instead of `onSelected` when the popped value is `null`) — so tapping
"System default" silently did nothing, for a real user exactly as much as
in a test. Fixed by giving the menu its own non-nullable
`_LanguageMenuOption` enum (`system`/`en`/`de`/`fr`) and mapping `system`
to `null` only when calling back into the app's locale-override state.

**Bug B — an unsupported device locale silently fell back to German, not
English.** Flutter's default locale-resolution fallback
(`basicLocaleListResolution`) returns `supportedLocales.first` when no
device locale matches. The generated `AppLocalizations.supportedLocales`
list is alphabetical — `[de, en, fr]` — so a user whose device locale is,
say, Spanish or Japanese would have landed on German by default, not
English (the app's original/home language from Phases 1–2). Fixed with an
explicit `localeListResolutionCallback` in `main.dart` that matches by
language code against the app's supported languages and defaults to
English otherwise, so the fallback no longer depends on ARB-file ordering.

Both were caught by the new widget tests in
`test/localization_widget_test.dart` (a genuinely unsupported locale, and
toggling the override back to "System default") before this phase was
reported done — see that file's "falls back to English for an unsupported
device locale" and "'System default' reverts a manual override" tests.

## 6. Test results

```
flutter analyze → No issues found!
flutter test    → 00:05 +79: All tests passed!
```

79 tests total: the 53 from Phases 1–2, plus 24 new for Phase 3, plus 2
more added in the §7 follow-up verification pass —

- `test/match_commentary_test.dart`: +6 (`CommentaryLanguage.fromLanguageCode`
  mapping, `CommentaryStrings.forLanguage`, and a full-event-coverage test
  for each of German and French).
- `test/voice_announcer_test.dart`: +5 (German/French TTS locale requests,
  German/French clip-subfolder paths, graceful silence when a language has
  no bundled clips).
- `test/localization_widget_test.dart` (new file): +13 (device-locale
  auto-detection for en/de/fr and an unsupported locale, manual override
  and reverting to system default, the menu's checked state, localized
  tooltips/labels on the scoreboard screen for German and French, the
  scoreboard screen's default `VoiceAnnouncer` construction not crashing
  under a German locale, and end-to-end localized voice output for German
  and French via the scoreboard screen).

No existing test was deleted; three widget tests needed small fixes to
keep compiling/passing after this phase's changes (adding
`localizationsDelegates`/`supportedLocales` to a bare `MaterialApp` in
`scoreboard_voice_widget_test.dart`, adding the new required `strings:`
parameter to existing `announcementForPoint` calls in
`match_commentary_test.dart`, and updating one test's `CheckedPopupMenuItem`
generic type after Bug A's fix changed it from `Locale?` to a private enum).

## 7. Follow-up verification: locale fallback for unsupported languages

A later request specifically asked me to re-verify locale-fallback
behavior for device languages entirely outside en/de/fr (e.g. Spanish,
Arabic), since that's the scenario Bug B (§5) was about. Findings:

**1. Is there an explicit resolution callback?** Yes —
`_resolveDeviceLocale` in `lib/main.dart`, wired up via
`MaterialApp.localeListResolutionCallback`. It matches the device's
preferred locales against `AppLocalizations.supportedLocales` by language
code and returns `Locale('en')` if nothing matches. This is the same fix
from Bug B; nothing new was needed here, since it already covers "any
locale outside en/de/fr," not just the Spanish case originally tested.

**2. Does an unsupported locale crash or produce a broken UI?** No —
confirmed with a new test using **Arabic** (`Locale('ar')`) specifically,
not just Spanish, since Arabic is right-to-left and a more meaningful
stress case than another LTR language would be:
- `tester.takeException()` is `null` (no crash).
- The setup screen renders normally in English ("New match", "Toss coin").
- `Directionality.of(context)` resolves to `TextDirection.ltr` — the
  layout follows the *resolved* (English) locale, not a leftover
  right-to-left layout from the device's actual Arabic locale, which
  would otherwise look broken (mirrored layout with English text).
- The rest of the screen (segmented best-of selector, toss button, start
  button) is present and interactive, not just the app bar title —
  ruling out a partially-rendered/blank screen.

**3. Is the manual override still reachable after this fallback?** Yes —
confirmed with a new test: starting from an Arabic (unsupported) device
locale, so the screen is already showing the English fallback, the
language menu still opens and correctly switches to German, then French,
then back to "System default" (which correctly re-resolves to English,
since the device locale is still the unsupported Arabic one). No
exceptions at any step.

**New tests** (both in `test/localization_widget_test.dart`):
- `device-locale auto-detection` › *"falls back to English for an
  unsupported RTL device locale (Arabic) without crashing or leaving a
  broken layout"*
- `manual language override` › *"the manual override is still reachable
  and works after the device falls back to English from an unsupported
  (Arabic) locale"*

```
flutter analyze → No issues found!
flutter test    → 00:05 +79: All tests passed!
```

No regressions; the two new tests bring the suite from 77 to 79.

## 8. Correction: German deuce term ("Einstand" → "Gleichstand")

**What was wrong:** the German deuce phrase was originally "Einstand." That
word is specific to lawn tennis's 15-30-40 scoring system — it names the
moment both players return to 40-40 within that system. Table tennis has
no such structure (it's a flat point count with no equivalent of
"advantage"), so "Einstand" doesn't actually apply to a 10:10 table tennis
situation.

**How it was caught:** external research, not native-speaker review —
German table tennis sources (DTTB-affiliated club rules pages, tt-dm.de)
consistently use "Gleichstand" for a tied score, or simply state the score
("10:10"), never "Einstand." This was flagged from outside this project,
not by the native-speaker review process §2/§3 called for — worth noting
because it means the "moderate confidence, needs a native check" flag on
the original term (§3, now removed) was correctly cautious, but the actual
error was found by domain research rather than the review this document
asked for. The French deuce term, "Égalité," was checked against the same
kind of sourcing at the same time and confirmed correct — no change there.

**Fix applied:** `deuce: 'Einstand'` → `deuce: 'Gleichstand'` in
`lib/services/commentary_strings.dart` (the only place the word was
hardcoded — no ARB string used it). `test/voice_announcer_test.dart` had
one test using "Einstand" as a literal example string; updated to
"Gleichstand" for consistency, though that test doesn't read from
`CommentaryStrings.de` directly so it wasn't asserting the word choice
itself. `test/match_commentary_test.dart`'s German deuce coverage reads
`strings.deuce` dynamically rather than a hardcoded string, so it picked
up the correction automatically with no edit needed.

```
flutter analyze → No issues found!
flutter test    → 00:04 +79: All tests passed!
```

Test count unchanged (79) — this was a value correction, not new coverage.

## 9. German best-of-N selector: "Gewinnsätze" instead of the raw number

**What was wrong:** the setup screen's format selector showed the raw
`bestOf` value (3/5/7) as each segment's label for every language,
alongside a `bestOfLabel` heading — German's heading was the untranslated
"Best of" (already flagged in §3 as a judgment call, not a confirmed
convention). Research into German table tennis rules sources found this
doesn't match how the format is actually described in German: club rules
pages consistently phrase it in terms of **Gewinnsätze** — the number of
*winning* games needed — not the total possible games, e.g. "3
Gewinnsätze im Einzel" for what this app calls best-of-5 (`gamesToWin =
(bestOf ~/ 2) + 1 = 3`).

**Fix applied — display only, engine untouched:**
- `lib/l10n/app_en.arb` / `app_de.arb` / `app_fr.arb`: added
  `bestOfSegmentLabel`, an ARB key with two placeholders (`bestOf`,
  `gamesToWin`) so each locale's translation can use whichever number
  fits its own phrasing. English and French use `"{bestOf}"` (unchanged
  behavior — still shows the raw 3/5/7). German uses `"{gamesToWin}
  Gewinnsätze"`, so the three segments now read "2 Gewinnsätze," "3
  Gewinnsätze," "4 Gewinnsätze" for bestOf 3/5/7 respectively.
- `app_de.arb`'s `bestOfLabel` heading changed from "Best of" to
  "Spielformat" ("match format") — a generic, low-risk word (not
  domain-specific jargon, so it didn't need the same research-backed
  verification as "Gewinnsätze") — since a `bestOfLabel` heading was still
  wanted for visual/layout consistency with English and French, even
  though each German segment is now already self-descriptive.
- `lib/screens/setup_screen.dart`: the segmented button's segments are now
  built from `[3, 5, 7].map(...)`, calling
  `l10n.bestOfSegmentLabel(bestOf, (bestOf ~/ 2) + 1)` for each segment's
  label instead of a hardcoded `Text('3')`/`Text('5')`/`Text('7')`. The
  segment **values** (3, 5, 7) — what actually gets passed to
  `TableTennisScoringEngine(bestOf: ...)` — are unchanged; only the label
  text differs by language. `(bestOf ~/ 2) + 1` is the same formula the
  engine itself uses for `gamesToWin`, so the displayed number is
  guaranteed consistent with actual engine behavior.

**Tests added** (`test/localization_widget_test.dart`, new group
"best-of selector localization (Gewinnsätze)"):
- English shows raw "3"/"5"/"7" (unchanged), and no "Gewinnsätze" text
  appears anywhere.
- French shows raw "3"/"5"/"7" (unchanged) alongside "Au meilleur de".
- German shows "2 Gewinnsätze"/"3 Gewinnsätze"/"4 Gewinnsätze" and
  "Spielformat"; the raw numbers no longer appear as standalone segment
  labels.
- End-to-end equivalence: selects away from the default first, then taps
  "3 Gewinnsätze" in the German UI, starts a match, and confirms it
  behaves exactly like English's plain "5" segment — winning 2 games does
  *not* end the match, but a 3rd game does (best-of-5's real semantics:
  3 games needed to win).

```
flutter analyze → No issues found!
flutter test    → 00:05 +83: All tests passed!
```

83 tests total (79 → 83, four new for this section). No regressions —
every existing test that selects the English "3"/"5"/"7" segments (e.g.
`widget_test.dart`'s best-of-3 match-completion tests) is unaffected,
since English's segment text is unchanged.
