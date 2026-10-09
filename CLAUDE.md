# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Flutter courtside table tennis scoreboard (singles + doubles, voice announcements, en/de/fr), shipped on Google Play as `com.kozmokramer.tabletennisscoreboard`. Android is the only platform actually released; the other platform folders are unmodified `flutter create` scaffolding.

The repo directory name still says "Phase 1"; the project is through Phase 7 plus the 4B–4Q polish passes.

## Commands

```bash
flutter pub get
flutter analyze
flutter test                                        # whole suite
flutter test test/scoring_engine_test.dart          # one file
flutter test test/scoring_engine_test.dart --plain-name "deuce"   # one test by name substring
flutter gen-l10n                                    # after editing lib/l10n/*.arb
flutter run                                         # debug
flutter run --profile                               # used for store screenshots
flutter build appbundle                             # Play Console upload
flutter build apk --release                         # release smoke test (see below)
dart run flutter_launcher_icons                     # after changing assets/icon/*
```

- `lib/l10n/gen/` is generated but **committed**. After changing any `.arb` file, run `flutter gen-l10n` and commit the regenerated output alongside it. Add every new key to all three of `app_en.arb` (the template), `app_de.arb`, `app_fr.arb`.
- Release builds are signed from `android/key.properties` (git-ignored) when it exists and fall back to debug signing otherwise; see README "Release signing".
- R8 only runs on release builds, so `flutter test` / `flutter run` cannot catch release-only crashes (one already happened: WorkManager's Room DB being stripped, fixed in `android/app/proguard-rules.pro`). Before a Play upload, install the release APK on a real device and play a few points.

## Architecture

### Layers

- `lib/models/` — pure Dart, no Flutter imports. `TableTennisScoringEngine` is the single source of truth for a match.
- `lib/services/` — pure derivation functions over the engine, plus thin wrappers around platform plugins.
- `lib/screens/`, `lib/widgets/` — UI. `lib/theme/app_theme.dart` is the design system.
- `lib/config/feature_flags.dart` — the monetization master switch.

### State is derived, not stored

The engine stores only the current game's points, the completed games, and who served first this game. Everything else is recomputed on demand from that:

- `currentServer` comes from total points + first server, so it cannot drift from the score.
- Undo is a snapshot stack, not an algebraic reversal.
- `addPoint` returns one `PointEvent` describing what that point caused (game won, change of ends, match won). The UI reacts to that event rather than polling state, which is why only one banner ever shows per point.
- **Doubles reuses the singles engine unchanged.** The engine knows two *sides* (`Player.one` / `Player.two`), never four people. `currentDoublesServingState(engine)` in `services/doubles_rotation.dart` is a pure function that maps the score onto the fixed A→C, C→B, B→D, D→A cycle. Partner order is fixed for the whole match (a deliberate simplification of ITTF rules; see `PHASE4_VERIFICATION.md`).
- `announcementForPoint` in `services/match_commentary.dart` is likewise a pure function of engine state deciding what to say; `VoiceAnnouncer` only handles how it is spoken.

Keep new behaviour in this shape: derive from the engine, so it stays correct across undo and game boundaries for free. `ScoreboardScreen` and `DoublesScoreboardScreen` are separate, parallel screens — a behaviour change to one usually needs mirroring in the other.

### App-lifetime state lives in `main.dart`

`TableTennisScoreboardApp` owns locale override, theme mode, mute, and the single `MonetizationController`, and threads them down through `SetupScreen` into whichever scoreboard screen is pushed. They live there so they survive returning to setup between matches. Theme mode is persisted (`ThemePreference`); mute and locale override are session-only.

Locale resolution uses an explicit `localeListResolutionCallback` falling back to English. Do not remove it: generated `supportedLocales` is alphabetical (de, en, fr), so Flutter's default would fall back to German.

### Platform plugins never crash the app

Every plugin sits behind an abstract interface with a real implementation that swallows its own errors and degrades silently (no voice / no ad / not Pro): `TtsEngine`, `ClipPlayer`, `SoundEffectPlayer`, `AdsService`, `PurchaseGateway`, `ConsentService`, `ReviewService`. This is what lets the whole app run under `flutter test` with no plugins present. New plugin usage should follow the same pattern.

Voice: `VoiceAnnouncer` uses device TTS when the language is installed, otherwise bundled clips under `assets/audio/<lang>/`. `CommentaryStrings` carries the per-language phrases, TTS locale, and clip folder. Only English clips are bundled; de/fr rely on device TTS.

Rating: `ReviewPrompter` (`services/review_prompter.dart`) backs both the "Rate this app" menu item (opens the store listing) and the one-time automatic request after the third completed match (in-app review sheet); the pure `shouldAutoPromptReview` holds the rules. The in-app sheet is quota-limited by Google and may silently show nothing, so `requestReview` must never be wired to a button. The sheet only appears in Play-installed builds.

### Monetization is built but switched off

`monetizationEnabled` in `lib/config/feature_flags.dart` is `false` for launch. `MonetizationController` is the only reader: when off it never initialises AdMob or UMP consent, and `isPro` reads `true`, so every Pro-gated feature (ad-free play) is unlocked. Match export was planned as a Pro benefit but was never implemented and was removed from the Pro benefits; do not build it unless asked. The ads/purchase/consent code, its tests, and the Pro dialog are intentionally kept intact — do not delete them as dead code. `AD_ID`/AdServices permissions are stripped from the Android manifest (`tools:node="remove"`) while ads are off and must be restored if the flag is flipped.

Still-placeholder values that matter when re-enabling: iOS AdMob IDs, `proProductId` in `purchase_gateway.dart`. See README "Phase 5" and `PHASE7_MONETIZATION_DISABLED_FOR_LAUNCH.md`.

### Theming

Colours are semantic roles on `AppPalette` (a `ThemeExtension`), read as `context.palette.accent` etc. — never hardcoded colours or `Colors.xxx` at call sites. Both light and dark palettes are real designs; dark is the default. `context.palette` silently falls back to the dark palette when the extension is missing, which hides light-mode bugs in tests that use a bare `MaterialApp` — widget tests that care about theme must build with `buildAppTheme(...)` (see `_themedApp` in `test/theme_parity_test.dart`). The setup screen's hero band is deliberately dark in both themes and overrides the app-wide system-bar overlay style set in `main.dart`.

## Testing conventions

- Screens and the root app take optional collaborators (`voiceAnnouncer`, `monetization`, `initialNames`, sound players) that default to real instances; tests inject fakes through them. Fakes are small private classes implementing the service interface, defined per test file rather than shared.
- Tests touching anything backed by `shared_preferences` (theme, Pro flag, score-edit hint) call `SharedPreferences.setMockInitialValues({...})` first.
- Monetization tests construct `MonetizationController` with an explicit `monetizationEnabled` override rather than depending on the global flag, so they keep exercising the enabled path while the app ships with it off.

## Docs in the repo

- `PHASES.md` — overall plan and what each phase deliberately deferred. Its status line is out of date.
- `PHASE*_*.md` — one write-up per phase with the decisions and bugs found. Code comments reference these by filename, so read the named doc before changing the code it annotates.
- `STORE_LISTING.md`, `screenshots/store/` — Play Store copy and assets. Store screenshots are captured from a profile build on a real device via `adb`; see `PHASE4Q_FINAL_STORE_SCREENSHOTS.md`.
- `privacy_policy/*.md` are the sources for the hosted `docs/*.html` (GitHub Pages); `lib/services/privacy_links.dart` holds the URLs. Keep the three in sync.

## Working rules

- Write and update README.md in English. App UI strings are localized (EN/DE/FR) via the `.arb` files.
- Every task ends with a written verification report: files changed, full test-run summary, and `git log --oneline -5`. Never say "committed" without showing the git log.
- All existing tests (currently 308) must keep passing. Add tests for any new logic.
- Do not change the scoring engine, voice, or unrelated screens unless the task says so.
- Do not build, sign, or upload release bundles, and never touch the keystore or `key.properties`, unless asked.
- Do not flip `monetizationEnabled` or re-enable ads/purchases.
- The app is in Google Play review/testing: do not change `applicationId`, and do not alter Play Console settings.
- Before implementing any new UI, show several design options first and wait for the user to choose; do not start coding UI until he picks.
- When asked to show or decide one specific thing (e.g. one button), show only that. Do not invent or restructure other screens.
- Test runs: use the Samsung S23 if connected; otherwise start an emulator automatically. Keep the screen on and skip lock/fingerprint in dev runs. No manual steps for the user.
- If platform folders are missing, `flutter create .` regenerates them.

## Terminology (do not "fix")

- German: "Gleichstand" (not "Einstand"), "Gewinnsätze" (display-only; 3/5/7 → 2/3/4, engine unchanged), "Rückschläger" (receiver).
- French: "Manche", "Égalité", "Relanceur" (receiver), "Paire" (doubles pairing, not "Équipe").
- Serve rotation: every 2 points, every 1 at deuce (ITTF 2.13.3). Doubles: new receiver = previous server's partner.