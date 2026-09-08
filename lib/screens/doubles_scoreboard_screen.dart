import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/doubles_seat.dart';
import '../models/player.dart';
import '../models/player_names.dart';
import '../models/scoring_engine.dart';
import '../services/commentary_strings.dart';
import '../services/doubles_rotation.dart';
import '../services/voice_announcer.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_score_text.dart';
import '../widgets/editable_name_label.dart';

/// Doubles scoreboard: reuses [TableTennisScoringEngine] exactly as
/// singles does (it only ever knows about two *sides* scoring points —
/// nothing about doubles' four individual players, or their serve
/// rotation, changes how points/games/the match are scored). What's new
/// here is purely who-serves/who-receives display, via
/// [currentDoublesServingState], and a 4-name layout instead of 2.
///
/// Game/match-won banners refer to sides as "Team 1"/"Team 2" (see
/// [_teamLabel] — Phase 4C), distinct from the on-court display's four
/// individually-numbered players, since "Player 1" winning would be
/// ambiguous about whether that means one person or their whole side.
/// Voice announcements use the same "Team 1"/"Team 2" wording for a
/// doubles game/match win, via [CommentaryStrings.teamLabel] — they used
/// to say "Player 1"/"Player 2" here even in doubles (a bug: voice and
/// the on-screen banner disagreed about the same event), fixed in
/// PHASE4D_TEAM_CLARITY_AND_TRANSITION.md. A team heading above each
/// side's two player names (also Phase 4D) makes the pairing visually
/// obvious without inferring it from layout alone.
///
/// Custom individual player names (Phase 4F, [PlayerNames]) only affect
/// the four on-court labels — a renamed "Alex" for slot 1 never changes
/// what the team-level banner/voice calls the side, which stays "Team
/// 1"/"Team 2" regardless, since a personal nickname for one of two
/// teammates doesn't answer "what do we call the pair." See
/// PHASE4F_THEME_AND_NAMES.md.
class DoublesScoreboardScreen extends StatefulWidget {
  final int bestOf;
  final Player firstServingTeam;

  /// Overridable for tests; defaults to a real [VoiceAnnouncer], same as
  /// [ScoreboardScreen].
  final VoiceAnnouncer? voiceAnnouncer;

  /// Custom names for the 4 on-court slots, usually carried over from
  /// the setup screen's preview (Phase 4F) — defaults to empty (all 4
  /// default labels) if not given.
  final PlayerNames? initialNames;

  const DoublesScoreboardScreen({
    super.key,
    required this.bestOf,
    required this.firstServingTeam,
    this.voiceAnnouncer,
    this.initialNames,
  });

  @override
  State<DoublesScoreboardScreen> createState() =>
      _DoublesScoreboardScreenState();
}

class _DoublesScoreboardScreenState extends State<DoublesScoreboardScreen> {
  late TableTennisScoringEngine _engine;
  late VoiceAnnouncer _voice;
  bool _voiceInitialized = false;
  late final PlayerNames _names;

  @override
  void initState() {
    super.initState();
    _engine = TableTennisScoringEngine(
      bestOf: widget.bestOf,
      firstServer: widget.firstServingTeam,
    );
    _names = widget.initialNames ?? PlayerNames();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_voiceInitialized) {
      _voiceInitialized = true;
      _voice = widget.voiceAnnouncer ??
          VoiceAnnouncer(
            strings: CommentaryStrings.forLanguage(
              CommentaryLanguage.fromLanguageCode(
                Localizations.localeOf(context).languageCode,
              ),
            ),
          );
    }
  }

  void _scorePoint(Player scorer) {
    if (!_engine.canScore) return;
    final event = _engine.addPoint(scorer);
    final server = _engine.currentServer; // who serves next, not who just served
    setState(() {});

    // isDoubles: true — voice must say "Team 1"/"Team 2" for a doubles
    // game/match win, matching the on-screen banner (_teamLabel below).
    // Previously this fell through to the singles "Player 1"/"Player 2"
    // wording even in doubles — see PHASE4D_TEAM_CLARITY_AND_TRANSITION.md.
    // No nameFor override here: custom individual names never change the
    // team-level wording — see the class doc comment.
    _voice.announcePoint(
        engine: _engine, event: event, server: server, isDoubles: true);

    if (event.matchCompleted) {
      _showMatchCompleteDialog(event.matchWinner!);
    } else if (event.gameCompleted) {
      _showGameCompleteBanner(event.gameWinner!);
    } else if (event.changeEndsNow) {
      _showChangeEndsBanner();
    }
  }

  void _toggleMute() => setState(() => _voice.toggleMuted());

  void _undo() => setState(() => _engine.undo());

  /// Resets both the match and any custom on-court names — "New match"
  /// starts genuinely fresh. See PHASE4F_THEME_AND_NAMES.md.
  void _resetMatch() => setState(() {
        _engine.resetMatch();
        _names.clear();
      });

  /// The side's team-level display name for banners/dialogs — "Team
  /// 1"/"Team 2", not "Player 1"/"Player 2": with 4 individually-numbered
  /// players on screen, "Player 1" winning would be ambiguous about
  /// whether that means one specific person or their whole side. See
  /// PHASE4C_TOSS_AND_TEAM_LABELS.md.
  String _teamLabel(Player team) {
    final l10n = AppLocalizations.of(context);
    return team == Player.one ? l10n.team1Label : l10n.team2Label;
  }

  String _defaultSlotLabel(int slot) {
    final l10n = AppLocalizations.of(context);
    return switch (slot) {
      1 => l10n.player1Label,
      2 => l10n.player2Label,
      3 => l10n.player3Label,
      _ => l10n.player4Label,
    };
  }

  String _slotLabel(int slot) => _names.resolve(slot, _defaultSlotLabel(slot));

  void _setSlotName(int slot, String? name) =>
      setState(() => _names.set(slot, name));

  void _showChangeEndsBanner() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('changeEndsSnackBar'),
        content: Text(AppLocalizations.of(context).changeEndsSnackBar),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showGameCompleteBanner(Player winner) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('gameCompleteSnackBar'),
        content: Text(AppLocalizations.of(context)
            .gameCompleteMessage(_teamLabel(winner))),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMatchCompleteDialog(Player winner) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        key: const Key('matchCompleteDialog'),
        title: Text(l10n.matchCompleteDialogTitle),
        content: Text(l10n.matchCompleteMessage(_teamLabel(winner))),
        actions: [
          TextButton(
            key: const Key('newMatchButton'),
            onPressed: () {
              Navigator.of(context).pop();
              _resetMatch();
            },
            child: Text(l10n.newMatchButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final serving = currentDoublesServingState(_engine);

    bool isServing(DoublesSeat seat) => serving.server == seat;
    bool isReceiving(DoublesSeat seat) => serving.receiver == seat;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scoreboardTitle),
        actions: [
          IconButton(
            key: const Key('muteButton'),
            icon: Icon(_voice.isMuted ? Icons.volume_off : Icons.volume_up),
            iconSize: AppMetrics.iconButtonSize,
            tooltip: _voice.isMuted ? l10n.unmuteTooltip : l10n.muteTooltip,
            onPressed: _toggleMute,
          ),
          IconButton(
            key: const Key('undoButton'),
            icon: const Icon(Icons.undo),
            iconSize: AppMetrics.iconButtonSize,
            tooltip: l10n.undoTooltip,
            onPressed: _engine.canUndo ? _undo : null,
          ),
          IconButton(
            key: const Key('resetButton'),
            icon: const Icon(Icons.refresh),
            iconSize: AppMetrics.iconButtonSize,
            tooltip: l10n.resetTooltip,
            onPressed: _resetMatch,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: _DoublesTeamZone(
              key: const Key('team1Zone'),
              teamHeading: l10n.team1Label,
              teamHeadingKey: const Key('team1Heading'),
              slot0Label: _slotLabel(1),
              slot0DefaultLabel: _defaultSlotLabel(1),
              slot1Label: _slotLabel(2),
              slot1DefaultLabel: _defaultSlotLabel(2),
              editHint: l10n.editNameHint,
              onSlot0NameChanged: (name) => _setSlotName(1, name),
              onSlot1NameChanged: (name) => _setSlotName(2, name),
              slot0Serving: isServing(const DoublesSeat(Player.one, 0)),
              slot0Receiving: isReceiving(const DoublesSeat(Player.one, 0)),
              slot1Serving: isServing(const DoublesSeat(Player.one, 1)),
              slot1Receiving: isReceiving(const DoublesSeat(Player.one, 1)),
              points: _engine.player1Points,
              gamesLabel: l10n.gamesCountLabel(_engine.player1Games),
              servingTooltip: l10n.servingTooltip,
              receivingTooltip: l10n.receivingTooltip,
              pointsKey: const Key('team1PointsText'),
              slot0ServerIconKey: const Key('team1Slot0ServerIcon'),
              slot0ReceiverIconKey: const Key('team1Slot0ReceiverIcon'),
              slot1ServerIconKey: const Key('team1Slot1ServerIcon'),
              slot1ReceiverIconKey: const Key('team1Slot1ReceiverIcon'),
              slot0NameTextKey: const Key('player1NameText'),
              slot0NameFieldKey: const Key('player1NameField'),
              slot1NameTextKey: const Key('player2NameText'),
              slot1NameFieldKey: const Key('player2NameField'),
              onTap: () => _scorePoint(Player.one),
            ),
          ),
          VerticalDivider(width: 1, color: context.palette.divider),
          Expanded(
            child: _DoublesTeamZone(
              key: const Key('team2Zone'),
              teamHeading: l10n.team2Label,
              teamHeadingKey: const Key('team2Heading'),
              slot0Label: _slotLabel(3),
              slot0DefaultLabel: _defaultSlotLabel(3),
              slot1Label: _slotLabel(4),
              slot1DefaultLabel: _defaultSlotLabel(4),
              editHint: l10n.editNameHint,
              onSlot0NameChanged: (name) => _setSlotName(3, name),
              onSlot1NameChanged: (name) => _setSlotName(4, name),
              slot0Serving: isServing(const DoublesSeat(Player.two, 0)),
              slot0Receiving: isReceiving(const DoublesSeat(Player.two, 0)),
              slot1Serving: isServing(const DoublesSeat(Player.two, 1)),
              slot1Receiving: isReceiving(const DoublesSeat(Player.two, 1)),
              points: _engine.player2Points,
              gamesLabel: l10n.gamesCountLabel(_engine.player2Games),
              servingTooltip: l10n.servingTooltip,
              receivingTooltip: l10n.receivingTooltip,
              pointsKey: const Key('team2PointsText'),
              slot0ServerIconKey: const Key('team2Slot0ServerIcon'),
              slot0ReceiverIconKey: const Key('team2Slot0ReceiverIcon'),
              slot1ServerIconKey: const Key('team2Slot1ServerIcon'),
              slot1ReceiverIconKey: const Key('team2Slot1ReceiverIcon'),
              slot0NameTextKey: const Key('player3NameText'),
              slot0NameFieldKey: const Key('player3NameField'),
              slot1NameTextKey: const Key('player4NameText'),
              slot1NameFieldKey: const Key('player4NameField'),
              onTap: () => _scorePoint(Player.two),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoublesTeamZone extends StatelessWidget {
  /// "Team 1"/"Team 2" (or localized equivalent) — a heading above this
  /// side's two player names so it's visually obvious at a glance which
  /// pair of names forms one team, rather than having to infer it from
  /// two unlabeled stacked rows. See PHASE4D_TEAM_CLARITY_AND_TRANSITION.md.
  final String teamHeading;
  final Key teamHeadingKey;
  final String slot0Label;
  final String slot0DefaultLabel;
  final String slot1Label;
  final String slot1DefaultLabel;
  final String editHint;
  final ValueChanged<String?> onSlot0NameChanged;
  final ValueChanged<String?> onSlot1NameChanged;
  final bool slot0Serving;
  final bool slot0Receiving;
  final bool slot1Serving;
  final bool slot1Receiving;
  final int points;
  final String gamesLabel;
  final String servingTooltip;
  final String receivingTooltip;
  final Key pointsKey;
  final Key slot0ServerIconKey;
  final Key slot0ReceiverIconKey;
  final Key slot1ServerIconKey;
  final Key slot1ReceiverIconKey;
  final Key slot0NameTextKey;
  final Key slot0NameFieldKey;
  final Key slot1NameTextKey;
  final Key slot1NameFieldKey;
  final VoidCallback onTap;

  const _DoublesTeamZone({
    super.key,
    required this.teamHeading,
    required this.teamHeadingKey,
    required this.slot0Label,
    required this.slot0DefaultLabel,
    required this.slot1Label,
    required this.slot1DefaultLabel,
    required this.editHint,
    required this.onSlot0NameChanged,
    required this.onSlot1NameChanged,
    required this.slot0Serving,
    required this.slot0Receiving,
    required this.slot1Serving,
    required this.slot1Receiving,
    required this.points,
    required this.gamesLabel,
    required this.servingTooltip,
    required this.receivingTooltip,
    required this.pointsKey,
    required this.slot0ServerIconKey,
    required this.slot0ReceiverIconKey,
    required this.slot1ServerIconKey,
    required this.slot1ReceiverIconKey,
    required this.slot0NameTextKey,
    required this.slot0NameFieldKey,
    required this.slot1NameTextKey,
    required this.slot1NameFieldKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        highlightColor: context.palette.accent.withValues(alpha: 0.12),
        splashColor: context.palette.accent.withValues(alpha: 0.18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  teamHeading,
                  key: teamHeadingKey,
                  style: AppTypography.eyebrow(context),
                ),
              ),
              const SizedBox(height: 8),
              _DoublesPlayerRow(
                label: slot0Label,
                defaultLabel: slot0DefaultLabel,
                editHint: editHint,
                onNameChanged: onSlot0NameChanged,
                serving: slot0Serving,
                receiving: slot0Receiving,
                servingTooltip: servingTooltip,
                receivingTooltip: receivingTooltip,
                serverIconKey: slot0ServerIconKey,
                receiverIconKey: slot0ReceiverIconKey,
                nameTextKey: slot0NameTextKey,
                nameFieldKey: slot0NameFieldKey,
              ),
              const SizedBox(height: 6),
              _DoublesPlayerRow(
                label: slot1Label,
                defaultLabel: slot1DefaultLabel,
                editHint: editHint,
                onNameChanged: onSlot1NameChanged,
                serving: slot1Serving,
                receiving: slot1Receiving,
                servingTooltip: servingTooltip,
                receivingTooltip: receivingTooltip,
                serverIconKey: slot1ServerIconKey,
                receiverIconKey: slot1ReceiverIconKey,
                nameTextKey: slot1NameTextKey,
                nameFieldKey: slot1NameFieldKey,
              ),
              Expanded(
                child: Center(
                  child: AnimatedScoreText(points: points, scoreKey: pointsKey),
                ),
              ),
              const SizedBox(height: 6),
              Text(gamesLabel, style: AppTypography.gamesLabel(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoublesPlayerRow extends StatelessWidget {
  final String label;
  final String defaultLabel;
  final String editHint;
  final ValueChanged<String?> onNameChanged;
  final bool serving;
  final bool receiving;
  final String servingTooltip;
  final String receivingTooltip;
  final Key serverIconKey;
  final Key receiverIconKey;
  final Key nameTextKey;
  final Key nameFieldKey;

  const _DoublesPlayerRow({
    required this.label,
    required this.defaultLabel,
    required this.editHint,
    required this.onNameChanged,
    required this.serving,
    required this.receiving,
    required this.servingTooltip,
    required this.receivingTooltip,
    required this.serverIconKey,
    required this.receiverIconKey,
    required this.nameTextKey,
    required this.nameFieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: serving
              ? Tooltip(
                  message: servingTooltip,
                  child: Icon(Icons.sports_tennis,
                      key: serverIconKey,
                      size: 18,
                      color: context.palette.accent),
                )
              : receiving
                  ? Tooltip(
                      message: receivingTooltip,
                      // Same shape as the server icon above — reused
                      // (not a separate arrow glyph) and rendered dimmed
                      // rather than solid, so the pairing reads as
                      // "who has it strongly vs. who's about to get it"
                      // without needing a label. See
                      // PHASE4F_THEME_AND_NAMES.md — no established icon
                      // convention exists for "receiver" in this app
                      // category, so one shared visual vocabulary beats
                      // introducing a second symbol to learn.
                      child: Icon(
                        Icons.sports_tennis,
                        key: receiverIconKey,
                        size: 18,
                        color: context.palette.mutedText.withValues(alpha: 0.55),
                      ),
                    )
                  : null,
        ),
        const SizedBox(width: 6),
        EditableNameLabel(
          displayName: label,
          defaultLabel: defaultLabel,
          style: AppTypography.compactPlayerLabel(context),
          editHint: editHint,
          textKey: nameTextKey,
          fieldKey: nameFieldKey,
          onChanged: onNameChanged,
        ),
      ],
    );
  }
}
