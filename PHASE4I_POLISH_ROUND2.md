# Phase 4I: Polish Round 2 — Toss Name Bug, App Name, Coin Redesign, Menu Consolidation, Flags

Five independent fixes/improvements requested together: a real toss/custom-name
desync bug, a shortened launcher app name, a from-scratch coin interaction
(tap-to-toss, physical weight, idle affordance), one consolidated app-bar
overflow menu replacing three separate icons, and flag emoji in the language
picker.

**Status:** built and passing (248/248 tests — 242 previous + 6 new).
`flutter analyze`: no issues. Verified visually on a real connected Android
device (screenshots described in each section below).

---

## 1. Real bug: the coin toss ignored custom names

**Root cause:** `SetupScreen._sideLabel()` — the function that decides what
text the coin shows for each side — returned the generic localized label
(`l10n.player1Label`/`l10n.team1Label`, etc.) unconditionally, never
consulting `_names` (the `PlayerNames` instance holding whatever custom
name/team name was set in the preview above). This is the exact same class
of bug fixed for doubles voice/banner wording in Phase 4D (a display
surface reading from the wrong source of truth for a name), just never
caught here — every other place a name is shown (`ScoreboardScreen.
_playerLabel`, `DoublesScoreboardScreen._teamLabel`) already resolved
through `_names` correctly; the toss coin was the one place that didn't.

**Fix:** `_sideLabel` now resolves through `_names.resolve()` (singles) or
`_names.resolveTeam()` (doubles) first, falling back to the generic label —
identical logic to the two screens above.

**Tests added** (`test/toss_and_team_labels_test.dart`, new group "custom
names on the toss result"):
- Renames Player 1 to "Alex" on the setup screen, retosses (bounded to 20
  attempts, since the winner is random) until player one's side wins, and
  asserts the coin shows "Alex" — with an inline assertion on every attempt
  that a renamed side never shows its generic default ("Player 1") even
  when the *other* side wins that particular toss.
- Same for a doubles custom team name ("Thunderbolts" instead of "Team 1").

Both tests are written to fail cleanly (not hang) if the bug reappears: a
bounded retry loop with an explicit failure message, rather than a
`do...while` that would spin forever against a real regression.

## 2. Shortened app display name

**What was checked before changing anything:** this project has no
`res/values/strings.xml` at all — the Android launcher label was a raw
`android:label="tabletennis_scoreboard"` literal directly in
`AndroidManifest.xml`, and no `values-de`/`values-fr` locale-specific
resource folders exist anywhere in `android/app/src/main/res/`.

**What changed:**
- Created `android/app/src/main/res/values/strings.xml` with
  `<string name="app_name">TT Scoreboard</string>`, and changed the
  manifest's `android:label` to `@string/app_name` — the idiomatic Android
  approach, and what the reference to "strings.xml app_name" in the
  request implies, even though this project didn't have that file yet.
- `ios/Runner/Info.plist`'s `CFBundleDisplayName` changed from
  "Tabletennis Scoreboard" to "TT Scoreboard".
- Confirmed "TT Scoreboard" isn't a name already in wide use for this
  niche per the request's own research note (a couple of similarly-named
  "Live TT Scoreboard"-type apps exist, not this exact name).

**Not localized per-language** — deliberately: there are no
`values-de`/`values-fr` folders in this project, and a launcher name is
conventionally one fixed string across all languages regardless (the
in-app UI, not the home-screen caption, is where this app's per-language
text lives).

**Flagging as requested — the in-app `appTitle` ARB strings were left
unchanged** ("Table Tennis Scoreboard" / German / French full names,
shown in the setup screen's app bar and the OS task switcher). Reasoning:
the launcher grid is the one place text visibly truncates at a fixed small
width under a small icon; the app bar and task switcher both have
meaningfully more horizontal room and haven't shown truncation. If the
full name should also become "TT Scoreboard" in-app for consistency with
the launcher, that's a one-line change to three ARB files — flagging
rather than assuming, per the request.

## 3. Coin redesign: tap-to-toss, physical weight, idle affordance

**The "Toss coin" button is gone entirely.** The coin itself
(`CoinFlipIndicator`, now a `StatefulWidget` instead of stateless) is the
toss control — it's mounted continuously (not remounted fresh per toss via
a keyed rebuild, unlike Phase 4C), sits idle before the first toss, and a
tap anywhere on it (a generous `HitTestBehavior.opaque` hit area, not just
the visible circle) triggers a new toss.

**Idle affordance:** before the first toss, the coin shows a small
`Icons.sports_tennis` glyph instead of a face, with a single gentle
one-shot pulse (a subtle scale/lift "breathe," `sin`-shaped over one
forward run of a dedicated `AnimationController`) inviting the first tap.

**A real bug caught before this shipped:** the first implementation used
`AnimationController.repeat(reverse: true)` for that idle pulse — a
continuously-repeating animation that *never* stops scheduling frames.
Since the coin is now always on screen (not just after tossing), this
broke `pumpAndSettle()` — which waits for no more scheduled frames — on
essentially every test that pumps the setup screen at all, across the
entire suite (widget_test.dart, theme_and_names_test.dart,
localization_widget_test.dart, and more — over 60 failures from one root
cause). Fixed by making the idle animation a one-shot forward run instead
of a repeating one; it settles, `pumpAndSettle()` converges, and the
visual effect (one gentle pulse right when the screen appears) is
essentially what was intended anyway.

**Physical weight, requested specifically:**
- **Faster initial spin, settling into the landing:** the rotation now
  uses `Curves.easeOutExpo` (steep early deceleration) instead of Phase
  4C's `easeOutCubic`, so the flip reads as "thrown hard, then catching
  itself" rather than a uniform spin.
- **An arc, not just a spin:** the coin visibly lifts and falls during the
  flip (a `sin`-shaped height curve driving both a vertical translation
  and a slight scale-up at the peak, suggesting it's closer to the camera
  mid-air) rather than rotating in place.
- **A landing bounce:** after the spin portion of the animation (~700 of
  850ms total), one small decaying bounce plays before fully settling.
- **A ground shadow:** an ellipse beneath the coin shrinks and fades as
  the coin rises, and grows/darkens as it descends — the standard visual
  cue for "this object just left the ground" — tied to the same height
  value driving the coin's own motion.
- **More dimensionality on the coin face itself:** a radial gradient
  (lighter catch-light top-left, darkening toward the edge, using the
  existing `AppPalette.accentDim` token for the dark end — no new colors
  introduced) plus a darker rim border and a drop shadow, replacing the
  flat single-color disc from Phase 4C.

**Total duration** stayed under 900ms (850ms) — comfortably within the
existing "settles well under 1 second" test's margin, so the flip still
feels snappy despite the added bounce tail.

**Re-entrancy guard:** tapping the coin again while a flip is already in
progress is a no-op (`_isFlipping` guard), so a fast double-tap can't
overlap two animations — covered by a new test.

**Screenshots (real device, Samsung Galaxy, `flutter run` to the
connected hardware used for Phase 5's testing):**
- Idle state: the gradient coin with the small tennis-ball/paddle icon,
  no separate button below it, "Toss to decide who serves first" prompt
  above.
- Landed result: "Player 1" on the coin face with visible shadow and
  gradient shading, "Start match" enabled.

## 4. Consolidated app-bar overflow menu

The theme picker, language picker, and Pro icon — three separate
`IconButton`/`PopupMenuButton` widgets in the app bar — are now one
`PopupMenuButton<_OverflowAction>` behind a single "⋮" (`Icons.more_vert`)
icon, grouped into THEME / LANGUAGE / (Pro action) sections with dividers
and non-interactive section-label headers. Each item keeps exactly the
functionality it had as its own icon; only the entry point moved.

**A flat `_OverflowAction` enum** (rather than three separate typed
menus) backs the single `PopupMenuButton`, for the same reason the old
language-only menu needed its own enum: `PopupMenuButton.onSelected` is
never invoked for a `null` selection (Flutter can't distinguish "chose
null" from "dismissed without choosing"), so "System default" language
needs a real enum value to be selectable through the same button as
everything else.

**A real overflow bug found and fixed while building this:** adding a
leading flag/icon glyph to menu item rows that previously held only text
overflowed `RenderFlex` for longer localized strings — most visibly
German's "Werbung entfernen / Pro" (Pro item) and, in combination with a
flag, "Français"/"Systemstandard" (language items) — because a Material
popup menu's available width is capped by how much screen space remains
between its anchor (the app-bar icon) and the screen edge, not just by
its content's natural size. Fixed by wrapping each row's label in
`Flexible(child: Text(..., overflow: TextOverflow.ellipsis))` instead of
a bare `Text`, plus tightening each item's own padding
(`EdgeInsets.symmetric(horizontal: 10)` vs. the 16px-a-side default) to
give longer labels more room before truncation ever kicks in. This
surfaced as ~90 failing tests across every file that opens the menu in
German (the RenderFlex overflow is a rendering-layer exception, not a
plain test assertion failure) before being traced to this cause.

**Test key changes:** `themeMenuButton` and `languageMenuButton` are both
replaced by one `overflowMenuButton`; the individual option keys
(`themeOptionSystem`, `languageOptionEn`, etc.) and `proMenuButton` are
unchanged, just now reached by opening the one menu first. Updated across
`theme_and_names_test.dart`, `localization_widget_test.dart`, and
`monetization_widget_test.dart` (four spots that used to tap
`proMenuButton` directly as a standalone icon now open the overflow menu
first).

**Screenshot (real device):** the open menu showing THEME (System
default / Light / ✓Dark) and LANGUAGE (🌐 System default, checked / 🇬🇧
English / 🇩🇪 Deutsch / 🇫🇷 Français) sections with a divider, and "Remove
Ads / Pro" below — confirms no truncation/overflow in the shipped
(English) configuration and that the flags render cleanly as real
emoji glyphs, not tofu boxes, on this hardware.

## 5. Flag emoji in the language picker

Each language option now shows a small leading glyph: 🌐 for "System
default" (not a specific country, so a globe rather than a flag), 🇬🇧 for
English, 🇩🇪 for Deutsch, 🇫🇷 for Français — plain Unicode emoji, not image
assets.

**Emoji vs. image assets, decided in favor of emoji:** this app's actual
targets are Android and iOS, both of which render flag emoji natively and
consistently with no extra asset weight or maintenance. Flag-emoji
rendering inconsistency is a real issue only on some desktop
platforms/older Windows versions — not a concern here, and confirmed
rendering correctly on the real Android device used for testing (see
screenshot above). If this project ever targets Windows/web as a primary
platform, revisit with small SVG/PNG flag assets instead.

## Test summary

- `test/toss_and_team_labels_test.dart`: rewritten for the new tap-to-toss
  interaction (idle icon presence, `onTap`/`tossSequence`/nullable
  `winner` params on direct `CoinFlipIndicator` construction, a
  re-entrancy-guard test) plus the two new custom-name regression tests
  from §1. All pre-existing toss/team-label assertions kept, using the
  same `Key('tossButton')` (now on the coin's gesture detector) so the
  many *other* test files that just need "trigger a toss" needed no
  changes at all.
- `test/localization_widget_test.dart`: `languageMenuButton` →
  `overflowMenuButton`; three assertions that checked the old "Toss coin"
  button's localized text now check the still-present `tossPrompt` text
  instead (the button that text lived on no longer exists).
- `test/theme_and_names_test.dart`: `themeMenuButton` →
  `overflowMenuButton`; a `CheckedPopupMenuItem<ThemeMode>` cast fixed to
  `<dynamic>` (the item's type parameter is now the shared
  `_OverflowAction` enum, not `ThemeMode`).
- `test/monetization_widget_test.dart`: four spots now open the overflow
  menu before reaching `proMenuButton`, which is no longer a
  directly-tappable standalone icon.

No changes were made to the German 2/3/4 vs. English/French 3/5/7
best-of segment numbering, per explicit instruction — that remains the
confirmed-intentional linguistic choice from earlier phases.
