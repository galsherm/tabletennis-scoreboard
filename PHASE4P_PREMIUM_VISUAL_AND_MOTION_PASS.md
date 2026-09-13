# Phase 4P: Premium Visual and Motion Polish Pass

A comprehensive UI/motion pass across the setup screen, scoreboard
screen, and coin-flip toss, based on live mockup review. Six related
changes, described below with what was verified and why each design
choice was made.

## 1. Setup screen redesign

### Hero band

`SetupScreen`'s plain Material `AppBar` is gone, replaced by a custom
`_SetupHeroBand`: a fixed dark near-black background with a large
orange diagonal wedge in the upper-right corner (painted by
`_HeroDiagonalPainter`, a `CustomPainter` so it always exactly fills
whatever size the band ends up being, rather than hand-tuned pixel
offsets), the hamburger menu at the top-left, and the "New match" title
in large bold white text at the bottom-left. Nothing else lives in this
band — no extra icons, no subtitle — matching the brief's "keep it
clean, not cluttered."

**Deliberately not theme-adaptive.** The band always uses
`AppPalette.dark.background`/`.accent` regardless of the app's own
light/dark setting, the same way the app icon and Play Store feature
graphic are fixed brand marks that don't change with the in-app theme.
The hamburger's own icon color is force-overridden to white for the
same reason (a local `Theme` wrap around just that button, using
`IconButtonThemeData.foregroundColor`), since the app's normal
`scoreText`-based icon color would be invisible (near-black) against
this band in light mode. The *opened* menu flyout is unaffected by that
override — `_menuStyle`/`_menuItemStyle` already hardcode
`context.palette.surface`/`.scoreText` explicitly rather than relying
on ambient theme defaults, so it correctly still follows the app's real
light/dark theme.

A standard `AppBar` genuinely can't do this layout — a large bold title
anchored to the *bottom* of a ~150dp band, with the menu icon at the
top, doesn't fit AppBar's fixed 56dp single-row toolbar model at all.

### Grouped control sections

The mode toggle + player-name previews, and the best-of selector, are
each wrapped in a new `_SectionGroup` — a thin (2px) orange line along
just the top edge, not a full card border on all four sides. This was
the specific brief: each control reads as its own distinct unit without
the heavier "boxed-in" look a full border would give.

### Start match button

Now `l10n.startMatchButton.toUpperCase()` (matching the existing
`_eyebrow()` heading's own `.toUpperCase()` pattern — the underlying
localized string is unchanged, only the display transform), with
`letterSpacing: 1.2`, bold weight, and a trailing `Icons.arrow_forward`.

### The coin remains the only toss control

Already true before this phase (Phase 4I removed the separate "Toss
coin" button), but while reviewing this, a genuinely dead, unused ARB
string named exactly `tossButton: "Toss coin"` was found still sitting
in all three locale files — never referenced as display text anywhere,
just a leftover from before Phase 4I. Removed from all three `.arb`
files as part of this cleanup, so "no separate button" is also true of
the translated string tables, not just the UI.

### A real layout regression found and fixed while building this

The hero band (~150dp, permanently on-screen, not scrollable) plus the
two `_SectionGroup`s' extra padding pushed "Start match" — and, in
doubles mode with a renamed team, even the coin/toss button — low
enough to sit outside the default `flutter test` viewport (800×600
logical px) in roughly a dozen existing tests that tapped those buttons
without first calling `tester.ensureVisible(...)`. This is a real
change in real-world terms too: on a genuinely short phone screen, a
user might now need to scroll before reaching "Start match," which
wasn't true before. Fixed by adding `ensureVisible` calls at every such
tap site across `test/widget_test.dart`, `quick_score_correction_test.
dart`, `localization_widget_test.dart`, `team_clarity_and_transition_
test.dart`, `names_sync_and_dialog_test.dart`, and
`toss_and_team_labels_test.dart` — mirroring the pattern
`doubles_widget_test.dart` already used for doubles' taller content.

## 2. Scoreboard screen redesign

### Circular "chip" icon backgrounds

New `lib/widgets/chip_icon_button.dart` (`ChipIconButton`) wraps the
mute/undo/reset `IconButton`s in a subtle translucent circular
background (`palette.scoreText` at 8% opacity — reads as a soft light
chip in dark mode, a soft dark chip in light mode, without hardcoding a
theme-specific color). Shared by both `ScoreboardScreen` and
`DoublesScoreboardScreen`. The existing test keys (`muteButton`,
`undoButton`, `resetButton`) stay on the actual inner `IconButton` —
not the new wrapper — so every existing test that does
`tester.widget<IconButton>(find.byKey(...))` keeps working unmodified.

### Editable name dashed underline — unchanged

Per the brief, `EditableNameLabel`'s existing dashed-underline
affordance was left exactly as it was; nothing in this phase touched
it.

### Center divider accent

New `lib/widgets/center_divider_accent.dart` (`CenterDividerAccent`)
replaces the plain `VerticalDivider` between the two score halves with
the same full-height neutral divider *plus* a short (36dp) accent-
colored bar centered on it — not a tint on the whole divider, not a
longer line. Shared by both scoreboard screens.

## 3. Coin visual redesign

`_CoinFace` in `lib/widgets/coin_flip_indicator.dart` no longer uses a
radial gradient, a highlight/shine circle, or a blurred `boxShadow`.
Replaced with two flat concentric circles: a darker rim (`accentDim`)
offset 5px down-and-right behind the main face, standing in for
thickness/a cast shadow without an actual blur, and the face itself as
a single flat `accent`-colored circle with a 2.5px `accentDim` edge
stroke. Live review had specifically found the old gradient/shine
combination reading as *less* convincing than a simpler flat treatment,
not more.

### The idle "TAP TO TOSS" label

The idle coin previously showed a ping-pong-paddle icon; it now shows
the text label "TAP TO TOSS" (new `tapToTossLabel` ARB key — German
"ANTIPPEN," French "APPUYEZ," both deliberately short rather than
literal translations, following this project's established precedent
of prioritizing brevity over literal wording when space is tight — see
`proBuyButton`'s own shortening history in PHASE5_MONETIZATION.md
§10.2). The coin's diameter grew from 88 to 104 to give this label
comfortable room.

**Explicitly verified to fit on one line — not just eyeballed.** New
`test/coin_visual_test.dart` pumps the real `CoinFlipIndicator` idle
state for every shipped language's actual `tapToTossLabel` string at
the coin's real (104px) size, and checks: `maxLines: 1` is set (a
regression guard — without it, a long-enough translation could wrap
instead of shrinking), a `FittedBox(fit: BoxFit.scaleDown)` ancestor
exists (the actual mechanism that guarantees single-line fit regardless
of language — a `RenderParagraph` given the unbounded width `FittedBox`
provides its child never wraps, so this pair is what makes "always one
line" true, not any one hand-picked font size), and the rendered height
after that shrink stays above a legibility floor (catches a
translation so long it would be scaled down to near-nothing). All three
languages pass.

**Why `CoinFlipIndicator` takes `idleLabel` as a plain string
parameter, not `AppLocalizations.of(context)` internally:** this
exactly mirrors how `player1Label`/`player2Label` already work — the
*caller* (`SetupScreen`) resolves the localized string and passes it
down. This was tried the other way first (looking up
`AppLocalizations.of(context)` inside `_CoinFace` directly) and broke
several existing tests that construct `CoinFlipIndicator` inside a bare
`MaterialApp` with no `AppLocalizations` delegate registered at all —
exactly the pattern most of this widget's own tests already use. A
`String idleLabel = 'TAP TO TOSS'` default parameter keeps every one of
those tests working unmodified while `SetupScreen` passes the real
localized value.

## 4. Coin-flip animation: full flight path

Same `AnimationController`-driven architecture as before (Phase 4I) —
still `_flipController` + `_idleController`, still no
`AnimatedSwitcher` (avoiding the exact double-mount widget-test issue
that pattern caused previously) — with the amplitude/curves of what
each phase draws substantially increased:

- **Launch and arc**: `_liftHeight` went from 26 to 150 logical px, and
  the coin now shrinks toward `_peakShrink` (35%) at the peak of that
  arc — the same `height` value (already an existing sine-arc,
  unchanged in shape) now drives *both* the lift and an inverse scale,
  so the coin visibly gets smaller as it "gets farther away," not just
  higher.
- **More rotations**: 5.0/5.5 full turns (was 3.0/3.5), since the coin
  now has real airtime to actually spin through them.
- **Landing bounce**: replaced Phase 4I's small residual *height* bounce
  with a genuine `Curves.easeOutBack` *scale* overshoot once `t` crosses
  `_spinFraction` — a brief pop past 1.0 that eases back to exactly 1.0,
  which is what an "ease-out-back style landing" actually is, rather
  than a literal secondary hop.

**Deliberately did not change `_totalDuration`, `_spinMs`, `_bounceMs`,
or `_spinFraction`'s meaning at all** — only what each phase visually
draws. This is why the entire pre-existing timing-sensitive test suite
(the sound-sync boundary test's exact millisecond assertions, "settles
well under 1 second," every partial-pump assertion) kept passing
completely unmodified through this redesign; a full choreography
rewrite that also changed timing would have needed to touch all of
those too.

### A real layout bug found and fixed while building this

Initially, the coin's outer `SizedBox` reserved `diameter + liftHeight
+ 24` of permanent vertical space — correct for the old 26px lift, but
at the new 150px lift this ballooned the setup screen's total height
enough to push "Start match" off the default test viewport in nearly
every test in the suite (not just the dozen doubles/redesign-adjacent
ones from §1). Fixed by keeping the `SizedBox`'s reserved size fixed at
the coin's *resting* footprint only, and adding `clipBehavior:
Clip.none` to the `Stack` inside it so the coin's actual flight paints
outside those bounds during the animation without permanently
reserving that space in the scrollable layout — the coin only *visits*
that space mid-flip, it doesn't live there.

## 5. Sound/visual sync

**Finding: the trigger mechanism was already correct.** `
_maybePlayLandingSound` is — and, checking the history, always was —
an `AnimationController` listener (`_flipController.addListener(...)`),
fired the instant `_flipController.value` crosses `_spinFraction`. There
was no `Timer`-based delay anywhere in this codebase to remove; the
brief's description of the bug ("triggered from a Timer that guesses
the duration") doesn't match what was actually in `coin_flip_
indicator.dart`.

**The more plausible real root cause: first-play platform audio
latency.** A freshly-constructed `audioplayers` `AudioPlayer` can carry
real decoder/buffering startup latency on its *first* `play()` call —
independent of when that call is made — which is exactly the kind of
gap a real device reviewer would perceive as "the sound plays late,"
even though the app-side trigger fired at the exactly correct animation
frame. Added `SoundEffectPlayer.preload(String assetPath)` (implemented
via `audioplayers`' `AudioPlayer.setSource`, which buffers without
playing) and call it fire-and-forget from `CoinFlipIndicator.initState`
— well before any real toss can happen — so the landing clink's actual
first `play()` call, whenever it occurs, is no longer also its first
buffering pass.

**What was verified, and what an AI genuinely can't attest to.**
Verified in code and via the existing timing tests: the trigger still
fires at exactly the `_spinFraction` frame boundary (unchanged, still
covered by the exact-millisecond sound test), and `preload()` is called
once per `CoinFlipIndicator` instance before any toss. What this can't
verify from a terminal: whether the clink is now *perceptibly*
synchronized to a human ear on a real device — that's an inherently
subjective, audible judgment call, not something a screenshot, a log
line, or a passing test can confirm. This needs an actual person to
listen on the real device once it's back in hand; the code-level
guarantee (preloaded before first real playback, triggered on the exact
correct frame) is the most this phase can responsibly claim without
that.

## 6. Score-edit discoverability hint

New `lib/services/score_edit_hint_store.dart`
(`ScoreEditHintStore`, a `SharedPreferences`-backed flag, mirroring
`ThemePreference`/`ProStatusStore`'s existing pattern exactly) and
`lib/widgets/score_edit_hint.dart` (`ScoreEditHint`) — a widget that
wraps the score digit and plays a single gentle breathing pulse (scale
1.0 → 1.02 → 1.0 over 1.4s, `Curves.easeInOut` both ways) driven by its
own `AnimationController`, completely independent of `AnimatedScoreText`'s
existing score-change "pop" (a separate `TweenAnimationBuilder` keyed
on the score value) — the two animations can never fight over the same
tween or cancel each other, since neither widget knows the other
exists.

**Exactly once, ever, per install.** `ScoreEditHint._maybePlay()` checks
`ScoreEditHintStore.hasShown()` on mount; if already shown, it never
calls `_controller.forward()` at all — the digit never animates. If
not, it calls `markShown()` *before* playing (not after), so even a
screen popped mid-pulse still counts as "already offered," matching
"never again" rather than "never again unless interrupted." One
deliberate consequence: since both `_PlayerZone`/`_DoublesTeamZone`
instances wrap their own `ScoreEditHint` around the *same* shared
persisted flag, and both mount in the same frame, both score digits
typically pulse together the first time — this reads as a single,
symmetric "here's how this works" moment rather than a bug, and wasn't
worth the extra coordination complexity a strictly single-instance
guarantee would need for a barely-noticeable hint.

**Verified exactly once and persisting, not just eyeballed.** New
`test/score_edit_hint_test.dart`: on a fresh (`{}`) mocked
`SharedPreferences`, the pulse's `Transform.scale` is measurably above
1.0 mid-animation and settles back to exactly 1.0, and
`ScoreEditHintStore().hasShown()` reads `true` immediately afterward.
Separately, pre-seeding `{'score_edit_hint_shown': true}` (simulating
an app restart after the hint already played once) confirms the scale
never leaves 1.0 at any point — the animation genuinely never starts,
not just "finishes very fast."

## Testing

- `test/coin_visual_test.dart` (new) — the idle label's single-line fit,
  explicitly verified for every shipped language at the coin's actual
  size (§3).
- `test/score_edit_hint_test.dart` (new) — the one-time pulse fires
  exactly once and persists (§6).
- `test/toss_and_team_labels_test.dart` — updated: `_FakeSoundEffectPlayer`
  now implements the new `SoundEffectPlayer.preload`; `coinIdleIcon` key
  renamed to `coinIdleLabel` throughout (it's a label now, not an icon);
  a doubles-mode retry loop gained `ensureVisible` for the now-lower
  toss button.
- `test/theme_and_names_test.dart` — the app-bar structural test rewritten
  for the hero band (asserts `find.byType(AppBar)` now finds nothing, and
  that the hamburger sits above the title — a direct regression guard
  that the redesign is actually in place); two doubles-preview tests
  gained `ensureVisible` calls.
- `test/widget_test.dart`, `test/quick_score_correction_test.dart`,
  `test/localization_widget_test.dart`,
  `test/team_clarity_and_transition_test.dart`,
  `test/names_sync_and_dialog_test.dart` — `ensureVisible` added at every
  "Start match"/toss tap site that didn't already have it (§1, §4).

`flutter analyze`: no issues. `flutter test`: all 298 tests pass (293
before this phase + 5 new: 3 in `coin_visual_test.dart`, 2 in
`score_edit_hint_test.dart`).

## What was captured in screenshots vs. what needed real-device verification

Static screenshots (setup screen — idle and post-toss, scoreboard
screen mid-match, English) were captured on a real Android device
(Samsung SM-S911B) running a fresh install of this build, and are
referenced in the session's own reply, not duplicated here. The motion
pieces (§4's flight choreography, §6's breathing pulse) and the audio
piece (§5) are inherently not capturable in a still image.

On the real device, also checked via `logcat` (not just the test
suite): no `FATAL EXCEPTION` at any point across the session (app
install, launch, toss, match start, scoring), and the landing clink's
`preload()` call genuinely fires at app launch — a `setDataSource` for
`coin_flip.wav` appears in the log the moment the app starts, tens of
seconds before the first real toss's `play()` call (visible as a
`requestAudioFocus()` from the `audioplayers` plugin) — confirming the
buffering really does happen ahead of time as designed, not just in
theory. What logcat and the test suite together *can't* establish is
whether the clink now sounds perceptibly synchronized to a human ear —
that's an inherently subjective judgment only a person listening on the
device can make; see §5 above for the full reasoning on why this is as
far as code-level verification can responsibly go.

One design observation from reviewing the real screenshots, flagged
rather than silently "fixed": the hero band's orange diagonal
currently cuts through the second word of "New match," rather than
staying clear of the title text the way the Play Store feature graphic
keeps its ball clear of its own tagline. This wasn't an explicit
constraint for the hero band in the brief (only the feature graphic's
own spec called out "not overlapping any text"), and reads as a
deliberate, fairly common "title crossing an accent shape" treatment
rather than a mistake — but it's worth a second look before treating
this as final.
