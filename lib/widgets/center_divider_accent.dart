import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The scoreboard's center divider between the two score halves: a very
/// faint hairline that fades in from the top and out toward the bottom,
/// so the halves read as separate without a hard rule between them. The
/// serving side is marked by its own backdrop (see
/// `ServingSideBackdrop`), not by this line.
class CenterDividerAccent extends StatelessWidget {
  const CenterDividerAccent({super.key});

  @override
  Widget build(BuildContext context) {
    final line = context.palette.scoreText;
    return SizedBox(
      width: 2,
      height: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              line.withValues(alpha: 0),
              line.withValues(alpha: 0.18),
              line.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
