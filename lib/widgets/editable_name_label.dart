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
/// Only ever used on the setup screen (Phase 4H) — once a match starts,
/// names render as plain, uneditable `Text` instead (see
/// `ScoreboardScreen`/`DoublesScoreboardScreen`), keeping the in-match
/// screen focused purely on score.
///
/// The affordance is a thin dashed underline beneath the name (Phase
/// 4H), not an icon: an icon was tried first (PHASE4G_NAMES_SYNC_AND_
/// DIALOG.md) to fix a real discoverability gap — a `Tooltip` alone
/// only appears on long-press/hover, so nothing on screen suggested a
/// name could be renamed — but user testing preferred the subtler,
/// established "dashed underline means editable" convention (as used
/// e.g. by Google Contacts) over adding a second glyph next to every
/// name.
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
    return InkWell(
      key: widget.textKey == null ? null : Key('${widget.textKey}_tap'),
      onTap: _startEditing,
      child: Tooltip(
        message: widget.editHint,
        child: Text(
          widget.displayName,
          key: widget.textKey,
          // A thin dashed underline signals "this is editable" without
          // an icon competing with the name for attention — see the
          // class doc comment.
          style: widget.style.copyWith(
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dashed,
            decorationColor: context.palette.faintText,
            decorationThickness: 1.2,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}
