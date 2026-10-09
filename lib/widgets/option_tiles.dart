import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A single-choice selector drawn as a row of separate, equal-width
/// tiles — the setup screen's Singles/Doubles and best-of pickers.
/// Exactly one option is always selected: the chosen tile is filled
/// with the accent and carries a check mark, the others are quiet
/// surface tiles.
class OptionTiles<T> extends StatelessWidget {
  /// Each option's value and its already-localized label.
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const OptionTiles({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  static const _minHeight = 52.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, (value, label)) in options.indexed) ...[
          if (index > 0) const SizedBox(width: _gap),
          Expanded(
            child: _OptionTile(
              label: label,
              selected: value == selected,
              onTap: () => onSelected(value),
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = selected ? palette.onAccent : palette.mutedText;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: selected ? BorderSide.none : BorderSide(color: palette.divider),
    );
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? palette.accent : palette.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: OptionTiles._minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Center(
                // Shrinks a long label (or a large system font) to the
                // tile's width rather than wrapping or overflowing it.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected) ...[
                        Icon(Icons.check, size: 18, color: foreground),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: AppTypography.uiFamily,
                          fontSize: 17,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
