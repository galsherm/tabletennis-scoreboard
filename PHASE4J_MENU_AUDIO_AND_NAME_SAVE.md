# Phase 4J: Menu Icon/Structure, Audio Ducking Verification, Name-Save Bug

Four fixes based on real-device user testing: a clearer/repositioned menu
icon, real nested submenus instead of a flat list, an actually-verified
(and actually-fixed) audio-ducking bug, and a genuine name-editing bug
where a typed name could be silently discarded.

**Status:** built and passing (252/252 tests — 248 previous + 4 new).
`flutter analyze`: no issues. Items 1, 2, and 4 verified visually on a
real connected Android device; item 3 verified with concrete `adb shell
dumpsys audio` evidence on the same device (Android only — see §3's
honest disclosure about iOS).

---

## 1 & 2. Menu icon and nested submenu structure

Phase 4I's consolidated menu was a flat `PopupMenuButton` behind a
vertical-dots (`Icons.more_vert`) icon on the right. Two changes:

**Icon:** switched to a hamburger (`Icons.menu`) — more universally
recognized at a glance as "there's a menu here" than the dots pattern,
per the request. **Placement: moved to the app bar's `leading` (left)
slot.** Reasoning, having rendered and compared both on the real device:
a hamburger icon is conventionally associated with the *left* side in
almost every app a user has seen (it's the standard "open the drawer/
main menu" position), so putting it on the right would read as visually
mismatched with that convention — like a hamburger icon doing an
overflow-icon's job in the wrong spot. On the left, it reads as
intentional and matches user expectations from every other app that uses
this glyph. The trade-off: this app has no navigation drawer, so a user
familiar with "hamburger = drawer" might tap expecting one — but the
menu that opens (Theme/Language/Pro) is discoverable enough in context
that this didn't seem like a real cost worth keeping the icon on the
right for. Screenshot: `New match` app bar showing "☰ New match" with
nothing in the actions area.

**Structure:** rebuilt on `MenuAnchor`/`SubmenuButton`/`MenuItemButton`
(Flutter's newer Material 3 menu widgets) instead of `PopupMenuButton`,
specifically because `PopupMenuButton` has no nested-submenu support at
all — there was no way to make "Theme" a collapsed row that expands to
reveal Light/Dark/System without it. `SubmenuButton` draws its own
expand chevron automatically (no custom icon needed). "Remove Ads /
Pro" stays a flat `MenuItemButton` — a single purchase flow doesn't
benefit from an extra expand step the way a 3-4 option picker does.

Each option's checkmark is now a plain `Icon(Icons.check)` in the
`MenuItemButton`'s `leadingIcon` slot (shown conditionally) rather than
`CheckedPopupMenuItem`'s built-in `checked` property, which doesn't
exist on `MenuItemButton`. Tests key the checkmark itself
(`themeOptionDark_check`, etc.) to assert selection state.

**Screenshots (real device):**
- Collapsed: "☰" tapped, showing "Theme ▸ / Language ▸ / ⊘ Remove Ads /
  Pro" with a divider before the flat Pro action.
- Theme expanded: tapping "Theme" flies out "System default / Light /
  ✓ Dark".
- Language expanded: tapping "Language" flies out "✓ 🌐 System default
  / 🇬🇧 English / 🇩🇪 Deutsch / 🇫🇷 Français" — confirming Phase 4I's
  flags still render correctly and without overflow inside the new
  submenu structure.

**A real overflow bug found and fixed while building this:** the same
class of bug as Phase 4I's popup-menu overflow, but this time inside a
`MenuItemButton`. Longer localized labels (German's "Werbung entfernen
/ Pro" for the flat Pro item; flag + "Français"/"Systemstandard" for
language/theme items) overflowed the available width in the same way —
Material menu surfaces size themselves based on available screen space
near their anchor, not purely on content. Fixed the same way as before:
`Flexible(child: Text(..., overflow: TextOverflow.ellipsis))` instead
of a bare `Text` for every label that could plausibly run long.

## 3. Audio ducking: verified, found genuinely broken, fixed, re-verified

**This was not assumed — it was tested end-to-end on a real device
before touching any code**, per the explicit instruction not to just
re-assert Phase 2's config. Method: played a podcast in Spotify on the
connected Android device, switched to this app, scored a point (which
triggers `VoiceAnnouncer.announcePoint` → device TTS, since English is
installed on this device), and inspected `adb shell dumpsys audio`'s
live audio focus stack immediately before and after.

**Before any fix — confirmed broken:** the focus stack showed *only*
Spotify's own entry (`gain: GAIN`, `loss: none`) both before and during
the announcement. No entry for this app ever appeared. The announcement
was audibly mixing with the podcast with zero coordination — not
ducking, not pausing, not silent — exactly the "poor ducking" pattern
the original research flagged as a common competitor complaint.

**Root cause, found by reading the `flutter_tts` v4.2.5 plugin source
directly** (`$PUB_CACHE/hosted/pub.dev/flutter_tts-4.2.5`), not
guessed:
- Android: `FlutterTts.speak(String text, {bool focus = false})` —
  **defaults to `false`**. The plugin's Kotlin side
  (`FlutterTtsPlugin.kt`) only calls `requestAudioFocus()` (requesting
  `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`) `if (focus)`. This app's
  `FlutterTtsEngine.speak()` called `_tts.speak(text)` with no `focus`
  argument — i.e. always the `false` default — so the plugin never
  asked Android for audio focus at all, on every single announcement,
  since this app was first built.
- iOS: `FlutterTtsEngine`'s constructor set the audio session category
  to `ambient` with no options. Per Apple's own `AVAudioSession`
  semantics (documented in the plugin's own doc comments, sourced from
  `developer.apple.com`), the `duckOthers` option **can only be set
  under the `playback` or `playAndRecord` category** — `ambient`
  doesn't support it at all. The `ambient` category mixes with other
  audio at full volume with no ducking, unconditionally.

**Fix** (`lib/services/tts_engine.dart`):
- Android: `_tts.speak(text, focus: true)`.
- iOS: `setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
  IosTextToSpeechAudioCategoryOptions.duckOthers,
  IosTextToSpeechAudioCategoryOptions.
  interruptSpokenAudioAndMixWithOthers])` — the second option is
  Apple's own recommended pairing with `duckOthers` for apps with
  "occasional spoken audio" (their example: turn-by-turn navigation,
  exercise apps — this app's match announcements fit the same
  description): duck non-spoken audio (music) but fully pause-and-
  resume other *spoken* audio (podcasts, other TTS) rather than
  overlapping two voices unintelligibly.

**After the fix — re-verified on the same device, same method:**

```
# During the announcement:
pack: com.spotify.music   gain: GAIN                loss: LOSS_TRANSIENT_CAN_DUCK
pack: com.example.tabletennis_scoreboard  gain: GAIN_TRANSIENT_MAY_DUCK  loss: none

# ~2 seconds later, announcement finished:
pack: com.spotify.music   gain: GAIN                loss: none
```

This app's process now appears in the focus stack requesting
`GAIN_TRANSIENT_MAY_DUCK`; Spotify's own entry correctly transitions to
`LOSS_TRANSIENT_CAN_DUCK` (the official "duck, don't stop" response)
for the duration of the announcement, then automatically reverts to
`loss: none` once it ends. Cross-checked against `dumpsys
media_session`: Spotify's `PlaybackState` stayed `PLAYING` throughout,
position continuously advancing — it was never paused, only ducked, and
resumed at full volume with no manual intervention.

**Honest disclosure — iOS is not empirically verified.** No iOS device
or simulator was available in this environment. The iOS fix is based on
correctly applying Apple's own documented `AVAudioSession` category/
option semantics (verified by reading both the plugin's source and its
doc comments, which cite Apple's own documentation), not on an observed
result the way the Android fix is. This should be spot-checked on a
real iOS device before release.

**Why this couldn't be a `flutter test` unit test either** (see
`test/tts_engine_test.dart`'s doc comment for the full reasoning): both
`flutter_tts` code paths are internally gated by `dart:io`'s
`Platform.isAndroid`/`Platform.isIOS` — checks against the *test host's*
real OS (this repo's tests run on Windows), never "as" a mobile
platform. Neither code path can execute, and therefore neither can be
observed, from any `flutter test` run regardless of mocking the
channel. What the new test *does* cover is the existing best-effort
contract (constructing `FlutterTtsEngine` never throws, even if the
platform channel is unavailable) — real verification for the ducking
behavior itself is necessarily on-device, which is what was done here.

## 4. Bug: a name typed and then tapped away from (not submitted) was discarded

**Reproduced first, on the real device, before writing any fix** — per
the same "confirm it's real, then fix it properly" discipline as item
3. `EditableNameLabel` already had a focus-loss listener that commits
on blur (`_onFocusChange` → `_commit()`), which looked correct on
inspection — so the bug had to be somewhere in *whether* focus loss
ever actually happens, not in what happens once it does.

**Confirmed root cause via direct reproduction:** tapping a genuinely
non-interactive area of the screen (e.g. the "BEST OF" heading text,
which has no `GestureDetector`/`InkWell` of its own) does not, by
itself, move Flutter's focus away from a currently-focused `TextField`
— nothing else claims the tap, so nothing tells the field to unfocus,
so `_onFocusChange` never fires, so the typed name is left sitting in
an uncommitted, still-open edit field. This is distinct from tapping an
*actual* button/control elsewhere (confirmed this already worked
correctly before any fix — tapping "Start match" while mid-edit
correctly saved the name first), since Material widgets request focus
for themselves on tap, which incidentally unfocuses whatever had it.
The gap was specifically "tap on dead space," which is exactly what a
user means by "tap away."

**Fix** (`lib/screens/setup_screen.dart`): wrapped the setup screen's
entire body in a `GestureDetector` (`behavior: HitTestBehavior.opaque`)
whose `onTap` explicitly calls `FocusScope.of(context).unfocus()`. This
is the standard Flutter pattern for "tap anywhere dismisses/commits the
active field," applied once at the screen level rather than needing
bespoke changes to `EditableNameLabel` itself — the widget's own
commit-on-blur logic was already correct; it just needed a guarantee
that blur actually happens for every kind of tap-away, not only taps
that land on some other interactive widget.

**Re-verified on the real device, same repro:** typed "Sam" into
Player 1's field, tapped the exact same "BEST OF" heading that
previously left it stuck — the field now correctly commits and returns
to its read-only display showing "Sam," keyboard dismissed.

**Test added** (`test/names_sync_and_dialog_test.dart`): types a name,
taps `find.text('BEST OF')` (deliberately *not* calling
`receiveAction(TextInputAction.done)`, since the whole point is the
non-Enter path), and asserts the name was saved and the field returned
to read-only display.

## Test summary

- `test/theme_and_names_test.dart`: new group covering the hamburger
  icon's identity/placement and the collapsed-vs-expanded submenu
  structure; the three existing theme-menu tests updated for the extra
  "expand Theme" tap step and the `_check`-keyed checkmark assertions
  (replacing the `CheckedPopupMenuItem.checked` property, which no
  longer exists now that these are `MenuItemButton`s).
- `test/localization_widget_test.dart`: `_openLanguageMenuAndSelect`
  updated for the extra "expand Language" tap step; the "checks the
  currently active option" test updated the same way as the theme
  tests above.
- `test/names_sync_and_dialog_test.dart`: new test for the tap-away
  name-save fix (§4).
- `test/tts_engine_test.dart` (new file): documents why the audio-
  ducking fix can't be meaningfully unit-tested on this host, and
  covers the one thing that can be: `FlutterTtsEngine` never throws.

No changes were made to the German 2/3/4 vs. English/French 3/5/7
best-of segment numbering, and no changes to the in-app `appTitle` ARB
strings (both untouched by this phase's work, per no reason to touch
them).
