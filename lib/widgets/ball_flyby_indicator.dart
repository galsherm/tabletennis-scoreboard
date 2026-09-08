import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A brief ping-pong-ball flyby, shown full-screen while moving from the
/// setup screen to the scoreboard — a fast, sports-broadcast-style
/// transition flourish, not a game animation. See
/// PHASE4D_TEAM_CLARITY_AND_TRANSITION.md.
///
/// Follows the same pattern as `CoinFlipIndicator`/`AnimatedScoreText`: a
/// single [TweenAnimationBuilder] mount, not [AnimatedSwitcher] or two
/// cross-fading widgets, so there's never a moment with two balls mounted
/// under the same key. [onComplete] fires exactly once, via
/// [TweenAnimationBuilder.onEnd] — no manual `Timer`.
class BallFlybyIndicator extends StatelessWidget {
  /// Called once, when the flyby finishes.
  final VoidCallback onComplete;

  const BallFlybyIndicator({super.key, required this.onComplete});

  /// Comfortably under a second, as requested — a flourish, not a delay.
  static const _duration = Duration(milliseconds: 450);
  static const _diameter = 26.0;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _duration,
      curve: Curves.easeInOutCubic,
      onEnd: onComplete,
      builder: (context, t, child) {
        // Travels from just off the left edge to just off the right edge
        // (not edge-to-edge exactly, so it visibly enters and exits rather
        // than appearing/disappearing already on-screen).
        final dx = lerpDouble(-1.3, 1.3, t)!;
        // A shallow upward arc (peaking at the midpoint) reads as a real
        // shot's flight rather than a flat slide — subtle, not bouncy.
        final dy = -0.22 * sin(t * pi);
        return Align(
          alignment: Alignment(dx, dy),
          child: child,
        );
      },
      child: Container(
        width: _diameter,
        height: _diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}
