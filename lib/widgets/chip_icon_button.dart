import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// An [IconButton] on a subtle translucent circular "chip" background —
/// Phase 4P's replacement for the scoreboard app bar's bare mute/undo/
/// reset icons, which previously floated on empty app-bar space with no
/// visual grouping of their own. Purely decorative: [buttonKey],
/// [onPressed], [tooltip] etc. behave exactly like a plain [IconButton]
/// with the same parameters — existing tests that find the inner button
/// by key and cast it to `IconButton` are unaffected by this wrapper.
class ChipIconButton extends StatelessWidget {
  /// Applied to the inner [IconButton] itself (not this wrapper), so
  /// `find.byKey(...)` + `tester.widget<IconButton>(...)` keeps working
  /// exactly as it did before this chip background existed.
  final Key? buttonKey;
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final VoidCallback? onPressed;

  const ChipIconButton({
    super.key,
    this.buttonKey,
    required this.icon,
    required this.iconSize,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.palette.scoreText.withValues(alpha: 0.08),
        ),
        child: IconButton(
          key: buttonKey,
          icon: Icon(icon),
          iconSize: iconSize,
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
