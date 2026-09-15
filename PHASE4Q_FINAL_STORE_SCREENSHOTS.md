# Phase 4Q: Debug Banner, Hero Band Height Fix, and Final Store Screenshots

Three small fixes and a full recapture of the Play Store screenshot
set, following up on Phase 4P's edge-to-edge hero band change and its
own follow-up fix (the diagonal not reaching the true right screen
edge).

## 1. Debug banner safeguard

`MaterialApp` now sets `debugShowCheckedModeBanner: false` explicitly
(`lib/main.dart`). This is a no-op in profile/release builds (the
banner never renders there), but earlier store screenshots in this
session had been taken from a plain `flutter run` debug build, which
left the red "DEBUG" ribbon visible in the corner of every capture.
Belt and suspenders: every store screenshot in this pass was captured
from a **profile** build (`flutter run --profile`), not debug, matching
how earlier phases' screenshots avoided this; the explicit flag means a
future debug-build capture can't reintroduce it either.

## 2. Hero band height / setup screen fit

Phase 4P's edge-to-edge change (painting the hero band's background up
underneath the status bar, `lib/main.dart`) made the band noticeably
taller than before, which pushed "Start match" below the fold on a
real device — the setup screen needed a scroll to reach it. Fixed by
trimming vertical spacing in `lib/screens/setup_screen.dart`, keeping
the edge-to-edge background effect itself untouched:

- Hero band's own bottom inset: 20 → 12px.
- Gap between the hamburger menu and the title: 32 → 18px.
- Scrollable body's top/bottom padding: 24/32 → 16/20px.
- Gap between the mode-toggle section and the best-of section: 24 → 16px.
- Gap between the best-of section and the toss prompt: 36 → 20px.
- Gap between the coin and "Start match": 28 → 16px.
- Each `_SectionGroup`'s internal top padding: 16 → 12px.
- Gap between the mode toggle and the name/team-slot previews: 20 → 12px.

Verified on the same real device (Samsung Galaxy S23, 1080×2340,
density 3.0) used for the Phase 4P and prior Phase 4Q diagonal-edge
fix: "Start match" is now visible without scrolling, with visible
margin to spare above the on-screen navigation bar, in both singles and
doubles mode and in both themes.

## 3. Final store screenshot recapture

All screenshots under `screenshots/store/` were recaptured from a
fresh **profile** build on the real device above, now that every
recent visual/motion fix is in: the edge-to-edge hero band, its
right-edge fix, this phase's height fix, the coin redesign and flight
animation from Phase 4P, and the no-debug-banner guarantee above.
Captured by driving the actual running app (menu → language/theme
submenus, the mode toggle, the coin, "Start match") via `adb shell
input tap` and `adb shell screencap`, reusing the existing filenames
and reusing the toss result across locale/theme switches within a
setup-screen session where possible, rather than re-tossing each time.

Recaptured (12 files, existing naming convention unchanged):

- `en_setup_menu.png`, `de_setup_menu.png`, `fr_setup_menu.png` — setup
  screen, dark, singles.
- `en_scoreboard_singles.png`, `de_scoreboard_singles.png`,
  `fr_scoreboard_singles.png` — scoreboard, dark, singles.
- `en_scoreboard_doubles.png`, `de_scoreboard_doubles.png`,
  `fr_scoreboard_doubles.png` — scoreboard, dark, doubles.
- `en_scoreboard_singles_light.png`, `de_scoreboard_singles_light.png`,
  `fr_scoreboard_singles_light.png` — scoreboard, light, singles.

`feature_graphic_{en,de,fr}.png` were left untouched — they're designed
composite assets, not raw device screenshots, and none of this phase's
fixes touch their content.

## Verification

`flutter analyze`: no issues. `flutter test`: 305/305 pass (including
the two width-specific hero-diagonal tests added for the prior Phase 4Q
right-edge fix, which are unaffected by this phase's spacing changes).
The height fix and the full screenshot set were both verified visually
on the real device described above.
