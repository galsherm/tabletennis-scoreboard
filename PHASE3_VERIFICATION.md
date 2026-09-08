# Phase 3 Verification: Native German & French Localization

This document records what was built for Phase 3 (localization), the full
list of German/French strings added (for native-speaker review — see the
note at the top of PHASES.md: I don't read German/French fluently enough to
verify terminology myself), which strings are flagged as guesses rather
than confirmed terminology, test results, and two real bugs found and fixed
during implementation.

**Status:** built and passing (77/77 tests). Two real bugs found in this
phase's own new code during verification (not pre-existing) — both fixed,
see §5. One scope decision needs your confirmation before Phase 4: no real
German/French bundled voice clips ship yet (see §4).

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
| bestOfLabel | Best of | Best of *(kept, see §3)* | Au meilleur de |
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
| Deuce | Deuce | Einstand | Égalité |
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

**Moderate confidence — my own choices, not given by the spec, worth a
native check:**
- **Einstand** (German deuce) / **Égalité** (French deuce): plausible
  borrowed tennis/table-tennis terms, but I'm not certain either is what a
  German or French umpire would actually say for table tennis specifically
  (vs. e.g. just repeating the tied score). Flagging both.
- **"Best of"** kept untranslated for German (`bestOfLabel`): I judged this
  a common enough borrowed term in German sports/esports UI, but this is a
  judgment call, not a confirmed convention. The French side has a real
  idiom instead ("Au meilleur de"), which is asymmetric and worth
  double-checking makes sense.
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
flutter test    → 00:15 +77: All tests passed!
```

77 tests total: the 53 from Phases 1–2, plus 24 new for Phase 3 —

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
