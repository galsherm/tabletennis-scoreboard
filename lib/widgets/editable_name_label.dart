import 'package:flutter/material.dart';

import '../models/player_names.dart';
import '../theme/app_theme.dart';

/// A player/team name that becomes an inline text field when tapped —
/// see PHASE4F_THEME_AND_NAMES.md. Not a separate settings screen or
/// dialog: tapping the name swaps it in place for a focused `TextField`
/// pre-filled with the current text; submitting (or tapping away)
/// commits the trimmed result, or reverts to [defaultLabel] if left
/// blank.
///
/// A small pencil icon sits right after the text in read mode — added in
/// PHASE4G_NAMES_SYNC_AND_DIALOG.md after user testing found the name
/// was tappable but gave no visible sign of it: a `Tooltip` alone only
/// appears on long-press/hover, which isn't a visible affordance at all,
/// so nothing on screen suggested a name could be renamed. The icon is
/// deliberately small and muted (`faintText`) so it reads as a quiet
/// hint, not competing with the name itself for attention.
class EditableNameLabel extends StatefulWidget {
  /// The name currently shown — either a previously-set custom name or
  /// [defaultLabel].
  final String displayName;

  /// Shown when the custom name is cleared back to blank.
  final String defaultLabel;

  final TextStyle style;

  /// Called with the new trimmed custom name, or `null` if the edit
  /// resulted in reverting to [defaultLabel] (left blank, whitespace
  /// only, or too long — see [PlayerNames.set]).
  final ValueChanged<String?> onChanged;

  /// Tooltip/semantic hint shown in read mode (e.g. "Tap to rename").
  final String editHint;

  final Key? textKey;
  final Key? fieldKey;

  const EditableNameLabel({
    super.key,
    required this.displayName,
    required this.defaultLabel,
    required this.style,
    required this.onChanged,
    required this.editHint,
    this.textKey,
    this.fieldKey,
  });

  @override
  State<EditableNameLabel> createState() => _EditableNameLabelState();
}

class _EditableNameLabelState extends State<EditableNameLabel> {
  bool _editing = false;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.displayName);
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _editing) _commit();
  }

  void _startEditing() {
    _controller.text = widget.displayName;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _controller.selection =
          TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    });
  }

  void _commit() {
    final trimmed = _controller.text.trim();
    setState(() => _editing = false);
    final isDefault = trimmed.isEmpty ||
        trimmed.length > PlayerNames.maxLength ||
        trimmed == widget.defaultLabel;
    widget.onChanged(isDefault ? null : trimmed);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 80, maxWidth: 160),
        child: IntrinsicWidth(
          child: TextField(
            key: widget.fieldKey,
            controller: _controller,
            focusNode: _focusNode,
            maxLength: PlayerNames.maxLength,
            style: widget.style,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              counterText: '',
              border: UnderlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 2),
            ),
            onSubmitted: (_) => _commit(),
          ),
        ),
      );
    }
    // A small edit-pencil sized relative to the name's own font, so it
    // stays proportionate whether it's sitting next to a 19pt singles
    // name or a 15pt compact doubles one.
    final iconSize = (widget.style.fontSize ?? 16) * 0.68;
    return InkWell(
      key: widget.textKey == null ? null : Key('${widget.textKey}_tap'),
      onTap: _startEditing,
      child: Tooltip(
        message: widget.editHint,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                widget.displayName,
                key: widget.textKey,
                style: widget.style,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.edit,
              key: widget.textKey == null
                  ? null
                  : Key('${widget.textKey}_editIcon'),
              size: iconSize,
              color: context.palette.faintText,
            ),
          ],
        ),
      ),
    );
  }
}
