import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One of the scoreboard app bar's mute/undo/reset icons, on a 44px hit
/// target (see [AppMetrics.toolbarTouchTarget]). It used to sit on a
/// translucent circular "chip" (Phase 4P, hence the name); the Arena
/// pass dropped the fill for a plain icon. A thin wrapper: [buttonKey],
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
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: IconButton(
        key: buttonKey,
        icon: Icon(icon),
        iconSize: iconSize,
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppMetrics.toolbarTouchTarget),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
