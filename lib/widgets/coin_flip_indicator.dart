import 'dart:math';

import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/sound_effect_player.dart';
import '../theme/app_theme.dart';

/// The coin itself is the toss control (Phase 4I) — there is no separate
/// "Toss coin" button anywhere in this app. Before the first toss it sits
/// idle with a gentle breathing animation as an affordance that it's
/// tappable; tapping it (in either the idle or a just-landed resting
/// state) calls [onTap], which the caller uses to decide a new [winner]
/// and bump [tossSequence] — this widget notices the sequence change in
/// [didUpdateWidget] and plays the flip. This mirrors why the caller
/// decides `winner` up front rather than this widget rolling its own
/// randomness — see the class doc below for the rest of the flip
/// mechanics, unchanged since Phase 4C.
///
/// The winning side's label is legible right on the coin face once it
/// lands — not as separate text elsewhere on screen — see
/// PHASE4C_TOSS_AND_TEAM_LABELS.md.
///
/// The coin has two fixed faces — [player1Label] is always "heads,"
/// [player2Label] is always "tails" — and [winner] decides only how many
/// half-turns the flip makes: an integer number of full turns lands
/// heads-up, one extra half-turn lands tails-up. Either way exactly one
/// face is ever built at a time (a hard cut at the rotation's midpoint,
/// like a real coin — never a cross-fade), so there's never a moment with
/// two same-keyed widgets mounted together.
///
/// Phase 4I added physical weight to the motion: the flip front-loads
/// its spin (a steep `easeOutExpo` deceleration, rather than the
/// gentler `easeOutCubic` before) so it reads as "thrown hard, then
/// settling," an arcing lift-and-fall synced to that spin, and a soft
/// shadow beneath it that shrinks and fades as the coin rises and grows
/// and darkens as it comes back down — the standard "object leaving the
/// ground" visual cue.
///
/// Phase 4P ("full flight path") pushed that arc much further: the
/// coin now lifts high enough, and shrinks enough at the peak, to read
/// as launched up and away rather than a small in-place hop, spins
/// through more full rotations while airborne, and — once the arc
/// brings it back down to the table (still the exact instant
/// [_spinFraction] marks, unchanged) — the landing itself is a genuine
/// `Curves.easeOutBack` scale overshoot (a brief pop past 1.0 that eases
/// back to rest), not a small residual height bounce. Deliberately kept
/// on the *same* two-phase [_flipController] timeline and total
/// duration as before (nothing here changes [_totalDuration] or
/// [_spinFraction]'s meaning) — only the amplitude/curve of what each
/// phase draws changed, which is why every pre-existing timing-based
/// test (the sound-sync boundary, "settles well under 1 second," the
/// mid-flip assertions) kept passing unmodified through this redesign.
/// See PHASE4P_PREMIUM_VISUAL_AND_MOTION_PASS.md.
class CoinFlipIndicator extends StatefulWidget {
  /// Shown on the coin's "heads" face.
  final String player1Label;

  /// Shown on the coin's "tails" face.
  final String player2Label;

  /// Which side the coin is showing/settling on. `null` means no toss has
  /// happened yet — the coin renders its idle, tap-to-toss state instead
  /// of a face.
  final Player? winner;

  /// Bumped by the caller every time a new toss is requested (a tap while
  /// idle, or a re-toss after a result). This widget only plays the flip
  /// animation when this value changes between builds — a rebuild for an
  /// unrelated reason (e.g. a locale switch changing the labels) must
  /// never accidentally replay it.
  final int tossSequence;

  /// Called when the coin itself is tapped — whether idle (never tossed)
  /// or resting after a previous toss. Ignored while a flip is actively
  /// playing, so a rapid double-tap can't overlap two animations.
  final VoidCallback onTap;

  /// Called once, when the flip animation finishes.
  final VoidCallback onComplete;

  /// Silences the landing clink (Phase 4K follow-up) when the app's own
  /// mute setting is on — the same setting [VoiceAnnouncer.isMuted]
  /// controls during a match, threaded down here since the toss happens
  /// before a match (and its [VoiceAnnouncer]) exists yet. Defaults to
  /// `false` so every existing direct construction of this widget (this
  /// file's own tests included) keeps behaving exactly as before.
  final bool muted;

  /// Overridable for tests, so they can assert a landing sound was
  /// requested without touching a real platform audio channel — mirrors
  /// [ScoreboardScreen.voiceAnnouncer]'s optional-with-safe-default
  /// pattern. Defaults to a real [AudioPlayersSoundEffectPlayer].
  final SoundEffectPlayer? soundEffectPlayer;

  /// Shown on the coin's idle, not-yet-tossed face (Phase 4P) — "TAP TO
  /// TOSS" or its localized equivalent. Resolved by the caller via
  /// `AppLocalizations` (see `SetupScreen`), the same way
  /// [player1Label]/[player2Label] already are, rather than this widget
  /// reaching for `AppLocalizations.of(context)` itself — that keeps
  /// [CoinFlipIndicator] usable from a bare `MaterialApp` with no
  /// `AppLocalizations` delegate at all, which is exactly how most of
  /// this widget's own tests construct it. Defaults to the English copy
  /// so none of those existing tests needed to start passing it.
  final String idleLabel;

  const CoinFlipIndicator({
    super.key,
    required this.player1Label,
    required this.player2Label,
    required this.winner,
    required this.tossSequence,
    required this.onTap,
    required this.onComplete,
    this.muted = false,
    this.soundEffectPlayer,
    this.idleLabel = 'TAP TO TOSS',
  });

  /// Total flip duration, spin-plus-bounce combined — comfortably under a
  /// second so tests (and impatient players) never wait long. Kept as raw
  /// millisecond ints (rather than dividing two `Duration`s) so
  /// `_spinFraction` below stays a genuine compile-time constant —
  /// `Duration.inMilliseconds` isn't itself const-evaluable.
  static const _spinMs = 700;
  static const _bounceMs = 150;
  static const _totalMs = _spinMs + _bounceMs;
  static const _totalDuration = Duration(milliseconds: _totalMs);
  static const _spinFraction = _spinMs / _totalMs;

  /// Enlarged from Phase 4C's original 40, then again in Phase 4P to
  /// give the idle "TAP TO TOSS" label (see [_CoinFace]) comfortable
  /// room — a two-word result label or a short caps hint both need more
  /// room to read clearly than the plain disc did.
  static const _diameter = 104.0;

  /// How far down-and-right the darker rim circle sits behind the main
  /// face (Phase 4P's "simpler, more physically convincing" redesign —
  /// see [_CoinFace]) — a flat offset silhouette standing in for
  /// thickness/a cast shadow, deliberately not a blurred drop-shadow or
  /// gradient.
  static const _rimOffset = 5.0;

  /// How high (in logical pixels) the coin appears to lift mid-flip —
  /// a purely visual arc, not a real physics simulation. Phase 4P
  /// enlarged this substantially (from Phase 4I's 26) specifically so
  /// the flip reads as "launched up and away," not a small in-place
  /// hop — paired with [_peakShrink] below, which shrinks the coin as
  /// it approaches this height, the same "gets smaller as it gets
  /// farther away" cue a real thrown object gives.
  static const _liftHeight = 150.0;

  /// How much smaller (as a fraction of full size) the coin gets at the
  /// very peak of its arc — e.g. 0.35 means it shrinks to 65% size at
  /// the top of the flight before growing back to full size on the way
  /// down. Part of Phase 4P's flight redesign; see [_liftHeight].
  static const _peakShrink = 0.35;

  /// Language-independent — a coin clink isn't speech, so unlike the
  /// bundled announcement clips it doesn't live under a per-language
  /// subfolder.
  static const _landingSoundAsset = 'audio/coin_flip.wav';

  @override
  State<CoinFlipIndicator> createState() => _CoinFlipIndicatorState();
}

class _CoinFlipIndicatorState extends State<CoinFlipIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _flipController;
  late final AnimationController _idleController;
  late final SoundEffectPlayer _sound;
  bool _isFlipping = false;

  /// Guards the landing clink to fire at most once per flip — the
  /// listener below is checked on every animation tick, and without this
  /// it would re-fire on every tick once the spin phase has ended.
  bool _landingSoundFired = false;

  @override
  void initState() {
    super.initState();
    _sound = widget.soundEffectPlayer ?? AudioPlayersSoundEffectPlayer();
    // Best-effort, fire-and-forget: buffers the landing clink well ahead
    // of the first real toss so that later `play()` call doesn't carry a
    // fresh player's own decoder/buffering startup latency — see
    // [SoundEffectPlayer.preload] and PHASE4P_PREMIUM_VISUAL_AND_MOTION_
    // PASS.md for why this, not the trigger mechanism (already tied to
    // the animation controller's own frame callback), was the real
    // source of a perceptible landing/sound gap on a real device.
    _sound
        .preload(CoinFlipIndicator._landingSoundAsset)
        .catchError((_) {});
    _flipController = AnimationController(
      vsync: this,
      duration: CoinFlipIndicator._totalDuration,
    );
    _flipController.addListener(_maybePlayLandingSound);
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.winner != null) {
      // Mounted already-decided (shouldn't happen in this app's own
      // flow, but a defensive default so an external caller passing an
      // initial winner doesn't get stuck mid-animation-state).
      _flipController.value = 1.0;
    } else {
      // A single gentle pulse invites the first tap — deliberately a
      // one-shot forward run, not `repeat()`. A continuously-repeating
      // animation never stops scheduling frames, so `pumpAndSettle()`
      // would time out on every test that pumps the setup screen (the
      // coin is now always on screen, unlike Phase 4C's version which
      // only mounted after a toss) — this was tried first and broke the
      // entire suite. See PHASE4I_POLISH_ROUND2.md.
      _idleController.forward();
    }
  }

  /// Plays the landing clink at the exact instant the coin actually
  /// touches down — the spin phase's own arc math (see [build]'s
  /// `height` calculation) returns to 0 exactly when [_flipController]
  /// crosses `_spinFraction`, before the brief `easeOutBack` scale-pop
  /// landing bounce begins.
  /// That's the true "landing" beat, not the moment the whole animation
  /// (spin *and* bounce) finishes — which is what [CoinFlipIndicator.
  /// onComplete] fires on instead, since it's used to unlock "Start
  /// match," not to time this sound.
  void _maybePlayLandingSound() {
    if (!_isFlipping || _landingSoundFired) return;
    if (_flipController.value < CoinFlipIndicator._spinFraction) return;
    _landingSoundFired = true;
    if (widget.muted) return;
    _sound.play(CoinFlipIndicator._landingSoundAsset).catchError((_) {});
  }

  @override
  void didUpdateWidget(covariant CoinFlipIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tossSequence != oldWidget.tossSequence) {
      _isFlipping = true;
      _landingSoundFired = false;
      _flipController.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() => _isFlipping = false);
        widget.onComplete();
      });
    }
  }

  @override
  void dispose() {
    _flipController.removeListener(_maybePlayLandingSound);
    _flipController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_isFlipping) return;
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Kept as the historical "tossButton" key: this is still the one
      // control that triggers a toss, just embodied by the coin itself
      // now rather than a separate button next to it — see
      // PHASE4I_POLISH_ROUND2.md. Every other test in this app that just
      // needs "trigger a toss" (not testing the coin specifically) keeps
      // working unchanged against this key.
      key: const Key('tossButton'),
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flipController, _idleController]),
        builder: (context, _) {
          final isIdle = widget.winner == null && !_isFlipping;
          final t = _flipController.value;

          double angle = 0;
          String? label;
          var mirrored = false;
          if (!isIdle) {
            // Phase 4P: more full rotations than Phase 4I's 3/3.5 — the
            // coin now has real airtime (see `height`/`_liftHeight`
            // below) to actually spin through them, rather than mostly
            // just flipping in place.
            final turns = widget.winner == Player.one ? 5.0 : 5.5;
            final spinT = (t / CoinFlipIndicator._spinFraction).clamp(0.0, 1.0);
            angle = Curves.easeOutExpo.transform(spinT) * turns * 2 * pi;
            final showHeads = cos(angle) >= 0;
            label = showHeads ? widget.player1Label : widget.player2Label;
            mirrored = !showHeads;
          }

          // height: 0 = resting on the table, 1 = fully lifted (the peak
          // of the flight). A linear-time sine arc, independent of the
          // spin's own easing, for a natural launch-and-return — the
          // coin is back at height 0 (landed) exactly when `t` crosses
          // `_spinFraction`, which is also the instant
          // `_maybePlayLandingSound` fires the clink and is now where
          // the *entire* landing bounce lives (see `scale` below) —
          // height itself just stays at 0 through the whole bounce
          // phase; it never leaves the table again once landed.
          double height = 0;
          if (t <= CoinFlipIndicator._spinFraction) {
            final p = (t / CoinFlipIndicator._spinFraction).clamp(0.0, 1.0);
            height = sin(p * pi);
          }

          // scale: shrinks toward `_peakShrink` as height approaches its
          // peak (the "getting farther away" cue for the upward launch,
          // paired with `height`/`_liftHeight` above), grows back to 1.0
          // as it returns — then, once landed, a genuine
          // `Curves.easeOutBack` overshoot (briefly > 1.0, easing back to
          // exactly 1.0 by the time the whole animation finishes) stands
          // in for the "slight overshoot/bounce before settling" landing
          // Phase 4P asked for, replacing Phase 4I's small residual
          // height bounce.
          double scale = 1.0 - CoinFlipIndicator._peakShrink * height;
          if (t > CoinFlipIndicator._spinFraction) {
            final bp = ((t - CoinFlipIndicator._spinFraction) /
                    (1 - CoinFlipIndicator._spinFraction))
                .clamp(0.0, 1.0);
            final overshoot = Curves.easeOutBack.transform(bp) - 1.0;
            scale = 1.0 + 0.16 * overshoot;
          }
          // A subtle idle bob (a few pixels) invites a first tap without
          // being distracting — only while nothing has happened yet. A
          // single hump (0 -> 1 -> 0) over the idle controller's one-shot
          // forward run, not a repeating ping-pong — see initState.
          final idleBob = isIdle ? sin(_idleController.value * pi) : 0.0;
          final lift = height * CoinFlipIndicator._liftHeight + idleBob * 4.0;
          scale += idleBob * 0.02;
          final shadowScale = 1.0 - 0.45 * height - idleBob * 0.08;
          final shadowOpacity = 0.30 - 0.18 * height - idleBob * 0.05;

          const shadowBaseWidth = CoinFlipIndicator._diameter * 0.8;
          const shadowBaseHeight = CoinFlipIndicator._diameter * 0.22;

          return SizedBox(
            // Deliberately NOT diameter + liftHeight: the coin's actual
            // flight (see `lift` above) paints well outside this box
            // (via the `Clip.none` Stack below) rather than this
            // reserving that much permanent layout space around an
            // otherwise-resting coin — the setup screen is a
            // `SingleChildScrollView`, but "Start match" ending up
            // pushed far enough down to sit outside a test's (or a
            // small phone's) viewport is a real, not just theoretical,
            // failure mode this specifically avoids.
            width: CoinFlipIndicator._diameter + 32,
            height: CoinFlipIndicator._diameter + 32,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  bottom: 6,
                  child: Container(
                    width: shadowBaseWidth * shadowScale,
                    height: shadowBaseHeight * shadowScale,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: shadowOpacity),
                      borderRadius: BorderRadius.all(Radius.elliptical(
                        shadowBaseWidth * shadowScale / 2,
                        shadowBaseHeight * shadowScale / 2,
                      )),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6 + lift,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0018)
                      ..rotateY(angle)
                      ..scaleByDouble(scale, scale, scale, 1),
                    child: _CoinFace(
                      label: label,
                      idleLabel: widget.idleLabel,
                      mirrored: mirrored,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The coin's visible face — Phase 4P replaced the earlier
/// gradient-plus-blurred-shadow disc with a simpler, more physically
/// convincing pair of flat concentric shapes: a darker rim circle
/// offset slightly down-and-right behind the main face (standing in for
/// thickness/a cast shadow, live review found a real gradient/shine
/// overlay here read as *less* convincing, not more) and the face
/// itself as a single flat brand-orange circle with a thin darker-orange
/// edge stroke for definition. No highlight/shine circle — reviewed and
/// deliberately left out.
class _CoinFace extends StatelessWidget {
  /// `null` means idle/untossed — shown as [idleLabel] instead of a
  /// result.
  final String? label;
  final String idleLabel;
  final bool mirrored;

  const _CoinFace({
    required this.label,
    required this.idleLabel,
    required this.mirrored,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const diameter = CoinFlipIndicator._diameter;
    const boundsSize = diameter + CoinFlipIndicator._rimOffset;

    final content = label != null
        ? FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label!,
              key: const Key('coinFaceLabel'),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: palette.onAccent,
              ),
            ),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              idleLabel,
              key: const Key('coinIdleLabel'),
              textAlign: TextAlign.center,
              // Must always render on a single line — the FittedBox
              // above shrinks it as needed to guarantee that regardless
              // of how long a given language's translation is, rather
              // than relying on any one hand-picked font size actually
              // fitting; see test/coin_visual_test.dart, which verifies
              // this explicitly (not just by eye) for every shipped
              // language at the coin's real diameter. See
              // PHASE4P_PREMIUM_VISUAL_AND_MOTION_PASS.md.
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: palette.onAccent.withValues(alpha: 0.85),
              ),
            ),
          );

    final face = Stack(
      clipBehavior: Clip.none,
      children: [
        // The darker rim — a flat offset silhouette, not a blur, so it
        // reads as a distinct edge of thickness rather than a soft glow.
        Positioned(
          left: CoinFlipIndicator._rimOffset,
          top: CoinFlipIndicator._rimOffset,
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.accentDim,
            ),
          ),
        ),
        Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.accent,
            border: Border.all(color: palette.accentDim, width: 2.5),
          ),
          child: content,
        ),
      ],
    );
    final sized = SizedBox(width: boundsSize, height: boundsSize, child: face);
    if (!mirrored) return sized;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scaleByDouble(-1, 1, 1, 1),
      child: sized,
    );
  }
}
