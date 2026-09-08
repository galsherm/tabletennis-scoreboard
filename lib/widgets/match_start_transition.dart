import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fraction of the transition's total duration at which the ball reaches
/// the text (screen horizontal center). Everything before this is the
/// approach; the impact-squash and the ball's continued
/// bounce-departure both start exactly here and run concurrently for the
/// rest of the timeline — pulled out to a top-level constant (with the
/// functions below) so the choreography's timing can be asserted
/// directly in tests, independent of pumping a real widget through real
/// frame durations.
const matchStartImpactT = 0.5;

/// Constant horizontal velocity, off-left to off-right — a physically
/// plausible projectile-style path (real projectiles keep a constant
/// horizontal speed; only the vertical arc curves).
double matchStartBallDx(double t) => lerpDouble(-1.3, 1.3, t)!;

/// One big arc for the approach, landing exactly at y=0 (the text's
/// vertical center) at [matchStartImpactT], then two decaying bounces as
/// the ball skips away to the right — continuous at the seam (both
/// halves evaluate to 0 exactly at [matchStartImpactT]).
double matchStartBallDy(double t) {
  if (t <= matchStartImpactT) {
    final u = t / matchStartImpactT;
    return -0.42 * sin(pi * u);
  }
  final u = (t - matchStartImpactT) / (1 - matchStartImpactT);
  return -0.18 * (1 - u) * sin(pi * u * 2).abs();
}

/// 0..1, peaking exactly at [matchStartImpactT] and falling off within
/// ~0.08 of it either side — drives a brief flatten/widen on the ball
/// itself at the moment of contact, echoing the text's dent. Widened
/// slightly from Phase 4E's 0.06 (see the extended [_duration] below) so
/// the impact flash lasts long enough to actually register as a beat,
/// not just a flicker.
double matchStartImpactProximity(double t) =>
    (1 - ((t - matchStartImpactT).abs() / 0.08)).clamp(0.0, 1.0);

/// 0 before impact (text stays undeformed while the ball approaches),
/// jumping to 1 exactly at [matchStartImpactT] and decaying smoothly
/// afterward — the decay overlaps the ball's continued rightward bounce
/// rather than waiting for it, so "text recovers" and "ball departs" are
/// the same stretch of time, not two sequential steps.
double matchStartTextEnvelope(double t) {
  if (t < matchStartImpactT) return 0.0;
  final u = (t - matchStartImpactT) / (1 - matchStartImpactT);
  return exp(-u * 7);
}

/// Gaussian falloff from the impact character index: only the 2-3
/// characters nearest the point of contact dent noticeably — a
/// *localized* deformation, not the whole word scaling uniformly.
double matchStartCharFalloff(int charIndex, double impactIndex) =>
    exp(-pow(charIndex - impactIndex, 2) / (2 * 1.4 * 1.4));

/// The full choreographed match-start transition (Phase 4E), replacing
/// Phase 4D's plain ball flyby: a ball arcs in from the left, strikes the
/// centered cheer text (denting it locally at the point of contact), then
/// continues bouncing off to the right while the text springs back —
/// see PHASE4E_MATCH_START_TRANSITION.md for the full design rationale.
///
/// One [AnimationController] drives everything from a single mounted
/// widget — the same "single clean mount" rule `CoinFlipIndicator` and
/// `AnimatedScoreText` follow, avoiding [AnimatedSwitcher]'s double-mount
/// pitfall — so ball position, ball squash, and every character's text
/// deformation are all pure functions of one shared `t`, which is what
/// keeps the three motions (approach, impact, recovery-while-departing)
/// reading as one continuous gesture instead of three separate steps.
class MatchStartTransition extends StatefulWidget {
  /// The centered phrase to animate — e.g. "Let's Play!". Deformed
  /// per-character around the impact moment, so it's rendered character
  /// by character rather than as one `Text`.
  final String text;

  /// Called once, when the whole sequence finishes.
  final VoidCallback onComplete;

  const MatchStartTransition({
    super.key,
    required this.text,
    required this.onComplete,
  });

  @override
  State<MatchStartTransition> createState() => _MatchStartTransitionState();
}

class _MatchStartTransitionState extends State<MatchStartTransition>
    with SingleTickerProviderStateMixin {
  /// Extended twice now: Phase 4D's 450ms flyby-only duration became
  /// Phase 4E's 900ms full choreography, and this pass extends it again
  /// to 1100ms — the impact/squash moment at 900ms was still reading as
  /// a touch too quick to actually register before it was gone. Still
  /// comfortably brief; it's the impact window (see
  /// [matchStartImpactProximity]) that gained the most relative
  /// breathing room, not a slower overall feel.
  static const _duration = Duration(milliseconds: 1100);

  static const _ballDiameter = 26.0;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chars = widget.text.split('');
    final impactIndex = (chars.length - 1) / 2;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final envelope = matchStartTextEnvelope(t);
        final proximity = matchStartImpactProximity(t);

        return Stack(
          alignment: Alignment.center,
          children: [
            Row(
              key: const Key('matchStartTextRow'),
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < chars.length; i++)
                  _DeformedChar(
                    char: chars[i],
                    squash: envelope * matchStartCharFalloff(i, impactIndex),
                  ),
              ],
            ),
            Align(
              alignment:
                  Alignment(matchStartBallDx(t), matchStartBallDy(t)),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scaleByDouble(1.0 + 0.35 * proximity,
                      1.0 - 0.3 * proximity, 1.0, 1.0),
                child: Container(
                  key: const Key('transitionBall'),
                  width: _ballDiameter,
                  height: _ballDiameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.palette.accent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One character of the transition phrase, compressed vertically (and
/// slightly widened) by [squash] — pivoting from its own baseline so it
/// reads as being pressed down into a surface rather than shrinking in
/// place.
class _DeformedChar extends StatelessWidget {
  final String char;
  final double squash;

  const _DeformedChar({required this.char, required this.squash});

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.identity()
        ..translateByDouble(0.0, 6.0 * squash, 0.0, 1.0)
        ..scaleByDouble(
            1.0 + 0.25 * squash, 1.0 - 0.5 * squash, 1.0, 1.0),
      child: Text(char, style: AppTypography.transitionHeadline(context)),
    );
  }
}
