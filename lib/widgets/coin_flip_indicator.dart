import 'dart:math';

import 'package:flutter/material.dart';

import '../models/player.dart';
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
/// Phase 4I also added physical weight to the motion: the flip now
/// front-loads its spin (a steep `easeOutExpo` deceleration, rather than
/// the gentler `easeOutCubic` before) so it reads as "thrown hard, then
/// settling," an arcing lift-and-fall synced to that spin to suggest the
/// coin actually leaving and returning to the table, a brief decaying
/// bounce once it lands, and a soft shadow beneath it that shrinks and
/// fades as the coin rises and grows and darkens as it comes back down —
/// the standard "object leaving the ground" visual cue.
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

  const CoinFlipIndicator({
    super.key,
    required this.player1Label,
    required this.player2Label,
    required this.winner,
    required this.tossSequence,
    required this.onTap,
    required this.onComplete,
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

  /// Enlarged from Phase 4C's original 40 — a two-word label needs more
  /// room to read clearly than the plain disc did.
  static const _diameter = 88.0;

  /// How high (in logical pixels) the coin appears to lift mid-flip —
  /// purely a visual arc, not a real physics simulation.
  static const _liftHeight = 26.0;

  @override
  State<CoinFlipIndicator> createState() => _CoinFlipIndicatorState();
}

class _CoinFlipIndicatorState extends State<CoinFlipIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _flipController;
  late final AnimationController _idleController;
  bool _isFlipping = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: CoinFlipIndicator._totalDuration,
    );
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

  @override
  void didUpdateWidget(covariant CoinFlipIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tossSequence != oldWidget.tossSequence) {
      _isFlipping = true;
      _flipController.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() => _isFlipping = false);
        widget.onComplete();
      });
    }
  }

  @override
  void dispose() {
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
            final turns = widget.winner == Player.one ? 3.0 : 3.5;
            final spinT = (t / CoinFlipIndicator._spinFraction).clamp(0.0, 1.0);
            angle = Curves.easeOutExpo.transform(spinT) * turns * 2 * pi;
            final showHeads = cos(angle) >= 0;
            label = showHeads ? widget.player1Label : widget.player2Label;
            mirrored = !showHeads;
          }

          // height: 0 = resting on the table, 1 = fully lifted. An arc
          // during the spin (linear-time sine, independent of the spin's
          // own easing, for a natural lift-and-fall) followed by one
          // small decaying bounce once landed.
          double height;
          if (t <= CoinFlipIndicator._spinFraction) {
            final p = (t / CoinFlipIndicator._spinFraction).clamp(0.0, 1.0);
            height = sin(p * pi);
          } else {
            final bp = ((t - CoinFlipIndicator._spinFraction) /
                    (1 - CoinFlipIndicator._spinFraction))
                .clamp(0.0, 1.0);
            height = 0.28 * (1 - bp) * sin(bp * pi).abs();
          }
          // A subtle idle bob (a few pixels) invites a first tap without
          // being distracting — only while nothing has happened yet. A
          // single hump (0 -> 1 -> 0) over the idle controller's one-shot
          // forward run, not a repeating ping-pong — see initState.
          final idleBob = isIdle ? sin(_idleController.value * pi) : 0.0;
          final lift = height * CoinFlipIndicator._liftHeight +
              idleBob * 4.0;
          final scale = 1.0 + 0.16 * height + idleBob * 0.02;
          final shadowScale = 1.0 - 0.45 * height - idleBob * 0.08;
          final shadowOpacity = 0.30 - 0.18 * height - idleBob * 0.05;

          const shadowBaseWidth = CoinFlipIndicator._diameter * 0.8;
          const shadowBaseHeight = CoinFlipIndicator._diameter * 0.22;

          return SizedBox(
            width: CoinFlipIndicator._diameter + 32,
            height: CoinFlipIndicator._diameter + CoinFlipIndicator._liftHeight + 24,
            child: Stack(
              alignment: Alignment.bottomCenter,
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
                    child: _CoinFace(label: label, mirrored: mirrored),
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

class _CoinFace extends StatelessWidget {
  /// `null` means idle/untossed — shown as a hint icon instead of text.
  final String? label;
  final bool mirrored;

  const _CoinFace({required this.label, required this.mirrored});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
        : Icon(
            Icons.sports_tennis,
            key: const Key('coinIdleIcon'),
            size: 32,
            color: palette.onAccent.withValues(alpha: 0.75),
          );
    final face = Container(
      width: CoinFlipIndicator._diameter,
      height: CoinFlipIndicator._diameter,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // A radial gradient plus a darker rim gives the coin real
        // dimensionality (a light "catch" near the top-left, deepening
        // toward the edge) instead of the flat single-color disc from
        // earlier phases — see PHASE4I_POLISH_ROUND2.md.
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 1.1,
          colors: [
            Color.lerp(palette.accent, Colors.white, 0.25)!,
            palette.accent,
            palette.accentDim,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: palette.accentDim, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: content,
    );
    if (!mirrored) return face;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scaleByDouble(-1, 1, 1, 1),
      child: face,
    );
  }
}
