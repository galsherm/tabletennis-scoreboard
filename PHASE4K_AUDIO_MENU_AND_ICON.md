# Phase 4K: Real Audio Ducking Fix, Menu Color Bug, App Icon

Follow-up fixes from further real-device user testing on top of Phase 4J,
plus a new app icon. **Status:** 253/253 tests passing (252 previous + 1
new), `flutter analyze` clean. Every fix below was reproduced and
re-verified on the same real Android device (`RZCX60372PZ`) used in prior
phases; the icon was additionally verified on a clean emulator's home
screen and app drawer.

**Update, same day:** the user reported the audio ducking fix below
still wasn't working in real use after this doc was first written. That
report was correct — re-testing found a genuine overlapping-announcement
race condition that a single-announcement test never exercised. See
§1a for the full re-investigation and the actual fix, found and verified
with fresh, literal `adb` output rather than re-asserting the original
write-up.

---

## 1. Audio ducking: Phase 4J's fix was real but incomplete — found and fixed

Phase 4J shipped `focus: true` and claimed this made ducking work,
citing a `dumpsys audio` snapshot showing `GAIN_TRANSIENT_MAY_DUCK` and
Spotify staying `PLAYING`. Told that "it's fully muting music, speaking,
then restoring music" in real use, this phase re-tested from scratch —
rebuilt and reinstalled the exact Phase 4J APK first, then reproduced —
rather than trusting the earlier write-up.

### What re-testing found

**With a podcast episode playing** (spoken-word content), scoring a
point in the app caused Spotify to fully **pause** — confirmed via
literal `adb shell dumpsys media_session` output showing
`state=PlaybackState {state=PAUSED(2), ...}` for the whole duration of
the announcement, not ducked. This matches what was reported.

Reading `adb shell dumpsys audio`'s Focus stack at the same moment
explained why:

```
source:... pack: com.spotify.music ... gain: GAIN
  flags: DELAY_OK|PAUSES_ON_DUCKABLE_LOSS ... loss: LOSS_TRANSIENT_CAN_DUCK
  attr: AudioAttributes: usage=USAGE_MEDIA content=CONTENT_TYPE_SPEECH ...
source:... pack: com.example.tabletennis_scoreboard ...
  gain: GAIN_TRANSIENT_MAY_DUCK ... loss: none
  attr: AudioAttributes: usage=USAGE_MEDIA content=CONTENT_TYPE_UNKNOWN ...
```

Two separate things are visible here:

1. **This app's own request was already the correct type** —
   `GAIN_TRANSIENT_MAY_DUCK`, never a type that asks others to pause —
   both before and after this phase's changes. Phase 4J wasn't wrong
   about that part.
2. **Spotify's own focus request carries `PAUSES_ON_DUCKABLE_LOSS`.**
   This is a flag Spotify sets on *its own* `AudioFocusRequest`,
   telling Android "if you'd normally just ask me to duck, convert
   that into a full pause instead." Android honors this per-holder
   preference — it is not something the interrupting app (this one)
   can override, by design. Spotify was doing this specifically while
   playing spoken-word content (`CONTENT_TYPE_SPEECH`): ducking one
   voice under another is bad UX, so a podcast pausing for a brief
   announcement rather than distorting under it is Spotify's own,
   reasonable choice — the same policy this app already implements on
   iOS (`interruptSpokenAudioAndMixWithOthers`: pause other *spoken*
   audio, duck non-spoken audio).

**With actual music playing** (a Spotify playlist, then a podcast
network's own music track), the same repro produced genuine ducking:

```
source:... pack: com.spotify.music ... gain: GAIN
  flags: DELAY_OK ... loss: LOSS_TRANSIENT_CAN_DUCK
  attr: AudioAttributes: usage=USAGE_MEDIA content=CONTENT_TYPE_MUSIC ...
```

No `PAUSES_ON_DUCKABLE_LOSS` flag on music content, and
`dumpsys media_session` showed `state=PLAYING(3)` throughout the
announcement, confirming real ducking (not a pause) for music — this
part of Phase 4J's fix was already working correctly, just not
verified against enough content types to notice the podcast gap.

**Conclusion: Phase 4J's Android fix (`focus: true`) was correct as far
as it went.** The "fully muting" behavior reported was real, but it was
Spotify's own opt-in pause-on-duck preference for podcast content — not
a wrong focus type from this app. This is disclosed rather than
"fixed away," because it can't be fixed away: forcing another app to
duck against its own declared preference isn't something the Android
focus API allows a requester to do.

### What this phase actually fixed

Reading `flutter_tts` v4.2.5's Kotlin source
(`FlutterTtsPlugin.kt`) found one real, fixable gap: its
`AudioFocusRequest.Builder(AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)` call
never sets `AudioAttributes` at all, so Android registers it as a bare
`USAGE_MEDIA`/`CONTENT_TYPE_UNKNOWN` request (visible above). Android's
own guidance for exactly this use case — a brief spoken announcement
layered over other audio, the same category as turn-by-turn navigation
prompts — is `USAGE_ASSISTANCE_SONIFICATION`/`CONTENT_TYPE_SPEECH`,
which `flutter_tts` has no API to configure.

Fixed by adding a small native Android channel instead of relying on
the plugin's built-in `focus` boolean:

- **`android/app/src/main/kotlin/.../MainActivity.kt`**: a
  `com.example.tabletennis_scoreboard/audio_ducking` `MethodChannel`
  with `requestDuckingFocus`/`abandonDuckingFocus`, building the
  `AudioFocusRequest` directly with the correct `AudioAttributes`,
  `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`, and `setWillPauseWhenDucked(false)`
  made explicit.
- **`lib/services/tts_engine.dart`**: `FlutterTtsEngine` now calls this
  channel directly (`_AndroidAudioDucking`) before `speak()` and passes
  `focus: false` to `flutter_tts` itself, so the plugin doesn't make a
  second, differently-configured request alongside it. Focus is
  released via `setCompletionHandler`/`setCancelHandler`/`setErrorHandler`
  — all three, so a cancelled or failed announcement can't leave this
  app holding focus indefinitely.

**Re-verified after the fix, same two scenarios:**

- Music: focus stack now shows this app's request coming from
  `MainActivity$$ExternalSyntheticLambda0` (proof the native path is
  actually exercised, not the plugin's own) with
  `attr: AudioAttributes: usage=USAGE_ASSISTANCE_SONIFICATION content=CONTENT_TYPE_SPEECH`
  — Spotify keeps `state=PLAYING` and its own entry correctly shows
  `loss: LOSS_TRANSIENT_CAN_DUCK`, then both revert automatically once
  the app's own entry is abandoned a couple of seconds later.
- Podcast: same correct request type/attributes from this app, and
  Spotify **still** pauses (confirmed again — `state=PAUSED(2)`, then
  correctly returns to `PLAYING` once focus is abandoned). This is
  unchanged by design, per the explanation above — and this run, unlike
  the pre-fix run, showed Spotify actually auto-resuming the podcast on
  its own once this app released focus (pre-fix, it had stayed paused
  indefinitely across several checks). This is consistent with Android
  documenting the properly-attributed transient-assistant focus type as
  the trigger for that auto-resume behavior in apps that set
  `PAUSES_ON_DUCKABLE_LOSS`, though this wasn't something this fix set
  out to fix and isn't guaranteed by any app the same way.

**iOS is unchanged from Phase 4J and remains unverified on a real
device** — no iOS hardware or simulator was available in this
environment. `tts_engine_test.dart`'s existing doc comment already
discloses this; nothing new to add here.

### 1a. Follow-up: a real overlapping-announcement race, found by not trusting a single clean test

After this section above was written and committed, the user reported
still hearing music fully stop and restart rather than duck, on the
same device, with actual music (not a podcast) — directly contradicting
the evidence above. Rather than re-assert the existing write-up, this
was re-tested from scratch, live, multiple times, with literal command
output pasted at each step (not summarized).

A single deliberate test (one tap, one announcement) reproduced the
same clean result as before: correct focus type, Spotify's
`PlaybackState` staying `PLAYING` throughout. That result was genuine,
but it wasn't the whole picture — it only tested one isolated
announcement, and `ScoreboardScreen._scorePoint` calls
`_voice.announcePoint(...)` **without awaiting it**, with nothing
debouncing rapid scoring taps. A real match scores points in bursts, so
this was stress-tested with five rapid taps in quick succession (0.4s
apart) instead of one:

```
09-09 22:44:53:695 requestAudioFocus() ... clientId=...@ae1b13e ...
09-09 22:44:54:268 requestAudioFocus() ... clientId=...@a0d8b9f ...
09-09 22:44:54:286 abandonAudioFocus() ... clientId=...@a0d8b9f
09-09 22:44:54:882 requestAudioFocus() ... clientId=...@44914ec ...
09-09 22:44:54:893 abandonAudioFocus() ... clientId=...@44914ec
09-09 22:44:55:438 requestAudioFocus() ... clientId=...@20600b5 ...
09-09 22:44:55:458 abandonAudioFocus() ... clientId=...@20600b5
09-09 22:44:56:020 requestAudioFocus() ... clientId=...@1c3a34a ...
09-09 22:44:56:061 abandonAudioFocus() ... clientId=...@1c3a34a
```

Each request→abandon pair is only **11-21ms apart** — physically far
too fast for real speech to have played. That gap is the actual
smoking gun: something was releasing audio focus almost immediately
after grabbing it, while overlapping announcements were still
supposed to be speaking.

**Root cause:** `MainActivity.kt`'s native side tracked audio focus with
a single mutable `AudioFocusRequest` field, overwritten by each new
`requestDuckingFocus` call. With overlapping announcements (which are
entirely reachable in real play, given `announcePoint` isn't awaited
and taps aren't debounced), an *older* utterance's completion/cancel
callback firing *after* a *newer* utterance had already requested focus
would call `abandonDuckingFocus`, which abandoned whatever the *current*
(newer) `AudioFocusRequest` reference was — releasing the newer,
still-needed hold instead of the older, actually-stale one. Repeated
overlaps produced exactly the rapid grab/release churn seen above,
which is a very plausible match for "music fully stops and restarts":
Spotify's volume would be yanked back to full and re-ducked repeatedly
in the space of a second or two, rather than a single clean duck.

**Fix** (`lib/services/tts_engine.dart`, `_AndroidAudioDucking` —
entirely on the Dart side, no further native changes needed): switched
from a single request/abandon pair to reference counting. `requestFocus`
increments a hold count and only calls the native channel on the first
concurrent hold (0→1); `releaseFocus` (renamed from `abandonFocus`,
called from the completion/cancel/error handlers) decrements it and
only calls the native channel once every concurrent hold has ended
(→0). A separate `resetFocus`, used only by `FlutterTtsEngine.stop()`
(reached via `VoiceAnnouncer.setMuted`), unconditionally zeroes the
count and abandons focus — muting is a deliberate "stop everything now"
action, not one more hold ending.

**Re-verified with the identical rapid 5-tap stress test, same device,
same music track, after the fix:**

```
09-09 22:50:50:588 requestAudioFocus() ... clientId=...@b6c48f3 ...
09-09 22:50:54:439 abandonAudioFocus() ... clientId=...@b6c48f3
```

One request, one abandon, **3.85 seconds apart** — a realistic span for
five queued announcements to actually speak through, instead of five
separate 15ms flaps. The focus stack afterward showed Spotify's entry
back to `loss: none`, and `dumpsys media_session` confirmed
`state=PLAYING` throughout the entire burst. Full regression suite
re-run after this change: 253/253 passing, `flutter analyze` clean —
unchanged, since this fix only touches the platform-gated Android path
(see `tts_engine_test.dart`'s doc comment for why that path has no
direct unit-test coverage on this non-mobile host).

This does not contradict the original finding above about podcasts —
that remains Spotify's own `PAUSES_ON_DUCKABLE_LOSS` choice for spoken
content, unrelated to this race. This fix is specifically about *music*
ducking becoming unreliable under rapid, overlapping announcements,
which is the scenario the user was actually hitting in real play.

## 2. Menu background color bug: fixed

Confirmed on-device: the settings menu (and both its submenu flyouts)
rendered with a visibly wrong pale pink/peach tint in light mode (and a
warmer near-black in dark mode) instead of this app's actual
`AppPalette.surface`.

**Root cause:** Material 3's `MenuStyle`/`ButtonStyle` defaults derive
an elevated surface's rendered color by blending `surfaceTintColor`
(which defaults to `ColorScheme.primary` — this app's orange accent)
over the background color. The menu was never reading a "wrong" color;
it was correctly applying a Material 3 design-system default this app's
`buildAppTheme` never opted the new `MenuAnchor`/`SubmenuButton`
widgets out of (Phase 4I's `popupMenuTheme` in `app_theme.dart` only
ever styled the old `PopupMenuButton`, which doesn't do this
tint-blending — the Phase 4J migration to `MenuAnchor` inherited a
Material 3 behavior that never applied before).

**Fix** (`lib/screens/setup_screen.dart`): added `_menuStyle()` and
`_menuItemStyle()` helpers, applied to the top-level `MenuAnchor`, both
`SubmenuButton`s (`style` for their own row, `menuStyle` for their
flyout), and every `MenuItemButton`:
- `backgroundColor` explicitly set to `context.palette.surface`.
- `surfaceTintColor` explicitly set to `Colors.transparent`, disabling
  the blend entirely.
- Each row's `foregroundColor`/`iconColor` explicitly set to
  `context.palette.scoreText`, so menu text/icons match this app's own
  color role instead of Material's auto-derived `onSurface`.
- The flat `Divider` between the submenus and "Remove Ads / Pro" now
  takes an explicit `color: context.palette.divider` too (it happened
  to already look right since `dividerColor` is set globally, but this
  keeps every element of the menu on the same explicit-color footing
  rather than one piece resolving through global theme by coincidence).

**Re-verified visually in both themes** on-device: the menu (collapsed,
Theme expanded, Language expanded) now shows a clean white background
in light mode and the app's real near-black surface in dark mode, with
no pink/brown tint in either.

**Test added** (`test/theme_and_names_test.dart`, new group "Setup
screen: menu surface colors (Phase 4K)"): asserts
`MenuAnchor.style.backgroundColor`/`surfaceTintColor` and
`SubmenuButton.menuStyle`'s equivalents resolve to
`AppPalette.surface`/`Colors.transparent`, and that a `MenuItemButton`'s
`foregroundColor` resolves to `AppPalette.scoreText` — a real
regression test: this would have caught the bug the moment
`MenuAnchor` was first adopted, since it fails without the new styling
and passes with it.

## 3. Coin flip sound effect: skipped, as explicitly permitted

The request allowed skipping this if it needed new asset licensing or
turned out to be more effort than expected. Both applied:

- No licensed sound asset was available to source in this offline
  environment (no browser/network tool was loaded for this session), so
  a truly "found" sound was never an option here.
- A synthesized placeholder clink (built from scratch with Python's
  standard-library `wave`/`struct`/`math` — no licensing question,
  since nothing was downloaded) was prototyped and sounds reasonable,
  but wiring it in safely turned out to be more than "quick": every
  other sound in this app (`ClipPlayer`, `TtsEngine`) is an injectable
  interface specifically so widget tests can substitute a fake instead
  of touching a real platform audio channel — `SetupScreen`'s coin toss
  has no such seam today, and `CoinFlipIndicator` is exercised by a
  large number of existing widget tests (`toss_and_team_labels_test.dart`
  and others) that tap the coin repeatedly. Calling a real
  `AudioPlayersClipPlayer` directly from `_tossCoin()` risks those
  tests failing on Flutter's "a Timer is still pending" check, since
  `AudioPlayersClipPlayer.playClip` awaits completion with a 5-second
  timeout that has no real platform implementation under `flutter
  test`. Doing this properly means threading a new injectable
  dependency through `SetupScreen` and updating every affected test to
  inject a fake — real, non-trivial work for a "small nice-to-have,"
  so it was skipped rather than rushed in a way that could quietly
  break the suite or ship a half-wired dependency. The synthesized
  prototype file was not committed.

## 4. New app icon

Implemented the requested design — a rounded-square-look icon split
diagonally into near-black (`#0B0F14`) and orange (`#FF8A34`), a white
ball (`#F5F7FA`) crossing the divide, and a subtle motion trail (a
curved white stroke around 30% opacity) — and wired it through the
actual build.

**Source art** (`assets/icon/`, generated at 1024×1024 with Python +
Pillow, since no existing SVG/design tool was available in this
environment):
- `icon.png` — the full design (diagonal + ball + trail), used as-is
  for iOS and legacy Android. Deliberately **not** pre-rounded — both
  platforms apply their own corner/shape masking, and baking rounding
  into the source would double it.
- `icon_background.png` — the diagonal split alone, full bleed, used as
  the Android adaptive-icon background layer.
- `icon_foreground.png` — the ball + trail alone on a transparent
  background, sized and centered so the ball itself stays within
  Android's adaptive-icon safe zone (the inner ~66% of the canvas) —
  it won't be clipped oddly regardless of which mask shape (circle,
  squircle, rounded square) a given launcher applies. The motion trail
  extends beyond that zone deliberately; a decorative trailing effect
  bleeding to the edge and getting mask-clipped is normal/expected
  (most real adaptive icons do this with background elements), unlike
  clipping the actual subject.

**Build wiring**: added `flutter_launcher_icons: ^0.14.4` as a dev
dependency and a `flutter_launcher_icons:` config block in
`pubspec.yaml` pointing at the three images above, with
`remove_alpha_ios: true` (the App Store rejects icons carrying an alpha
channel; this icon's background is fully opaque everywhere already, so
this only changes file encoding, not appearance). Ran
`dart run flutter_launcher_icons`, which regenerated every Android
density (`mipmap-{m,h,xh,xxh,xxx}dpi` legacy icons, matching
`drawable-*dpi` adaptive foreground/background layers, and the
`mipmap-anydpi-v26/ic_launcher.xml` that wires the adaptive pair
together) and every iOS `AppIcon.appiconset` size, from `20x20@1x`
through the `1024x1024` App Store marketing icon.

**Verified on-device, not just the generated files**: installed the
rebuilt debug APK on the connected Android emulator (used instead of
the real device specifically to avoid navigating its owner's personal
home screen again, per the same privacy discipline as Phase 4J) and
screenshotted both the home screen dock and the full app drawer. The
icon renders correctly circle-masked (this launcher's adaptive mask
shape) in both places, clearly showing the diagonal split and the
white ball with no muddiness. A separate small-size render check
(scaled to 48×48, the smallest common launcher size) confirmed the
design stays legible at that size — the diagonal split, ball, and trail
all remain individually distinguishable rather than blurring into a
single blob.

**Not verified**: iOS icon rendering on a real device/simulator — none
was available in this environment, consistent with every other
iOS-side gap already disclosed in this app's phase docs.

## Test summary

- `test/theme_and_names_test.dart`: new group "Setup screen: menu
  surface colors (Phase 4K)" — the menu color regression test.
- `test/tts_engine_test.dart`: unchanged from Phase 4J — its existing
  doc comment already explains why `flutter_tts`'s platform-gated
  focus/category code can't be observed from `flutter test`, and that
  reasoning applies equally to the new native-channel path (also
  Android/iOS-gated, also unreachable from a non-mobile test host).
  The native `MainActivity.kt` audio-focus code itself has no unit-test
  coverage for the same structural reason every other platform-channel
  code in this app doesn't — its correctness was verified on-device
  instead, per the evidence above.
- No test coverage was added for the coin sound or the app icon, since
  neither shipped a testable code path (the sound was skipped outright;
  the icon is static build configuration/assets with no runtime logic).
