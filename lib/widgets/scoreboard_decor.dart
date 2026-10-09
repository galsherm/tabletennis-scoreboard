import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Marks one half of the scoreboard as the serving side: an accent wash
/// fading down the half, under a solid accent bar along its top edge.
///
/// Purely decorative and derived from [serving] alone, which both
/// scoreboard screens read straight off the engine — so it follows the
/// serve across points, undo and game boundaries without any state of
/// its own. The serve icon inside [child] stays the indicator that
/// carries the tooltip and test keys; this only adds weight to it.
class ServingSideBackdrop extends StatelessWidget {
  final bool serving;
  final Widget child;

  const ServingSideBackdrop({
    super.key,
    required this.serving,
    required this.child,
  });

  static const _barHeight = 4.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final glow = palette.serverGlow;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: serving ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      glow,
                      glow.withValues(alpha: glow.a * 0.23),
                      glow.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: _barHeight,
                    width: double.infinity,
                    child: ColoredBox(color: palette.accent),
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// One dot per game needed to win the match, filled for each game this
/// side has won. A picture of the count the "Games: N" caption beneath
/// it already states, so it is hidden from screen readers.
class GamePips extends StatelessWidget {
  final int won;
  final int toWin;

  const GamePips({super.key, required this.won, required this.toWin});

  static const _size = 12.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < toWin; i++)
            Container(
              width: _size,
              height: _size,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < won ? palette.scoreText : null,
                border: i < won
                    ? null
                    : Border.all(color: palette.neutralBar, width: 2),
              ),
            ),
        ],
      ),
    );
  }
}
