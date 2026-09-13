import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The scoreboard's center divider between the two score halves — the
/// existing full-height neutral [VerticalDivider], plus (Phase 4P) a
/// short accent-colored mark centered on it, rather than tinting the
/// whole divider or lengthening it — the accent is a small deliberate
/// detail here, not a structural line.
class CenterDividerAccent extends StatelessWidget {
  const CenterDividerAccent({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        VerticalDivider(width: 1, color: context.palette.divider),
        Container(
          width: 3,
          height: 36,
          decoration: BoxDecoration(
            color: context.palette.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
