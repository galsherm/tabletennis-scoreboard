import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/doubles_seat.dart';
import '../models/player.dart';
import '../models/scoring_engine.dart';
import '../services/commentary_strings.dart';
import '../services/doubles_rotation.dart';
import '../services/voice_announcer.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_score_text.dart';

/// Doubles scoreboard: reuses [TableTennisScoringEngine] exactly as
/// singles does (it only ever knows about two *sides* scoring points —
/// nothing about doubles' four individual players, or their serve
/// rotation, changes how points/games/the match are scored). What's new
/// here is purely who-serves/who-receives display, via
/// [currentDoublesServingState], and a 4-name layout instead of 2.
///
/// Game/match-won banners and voice announcements refer to sides
/// generically as "Player 1"/"Player 2" (the same wording singles uses,
/// via the same [AppLocalizations]/[CommentaryStrings] — not redesigned
/// for doubles), even though the on-court display below numbers all four
/// individuals 1–4. See PHASE4_VERIFICATION.md for why.
class DoublesScoreboardScreen extends StatefulWidget {
  final int bestOf;
  final Player firstServingTeam;

  /// Overridable for tests; defaults to a real [VoiceAnnouncer], same as
  /// [ScoreboardScreen].
  final VoiceAnnouncer? voiceAnnouncer;

  const DoublesScoreboardScreen({
    super.key,
    required this.bestOf,
    required this.firstServingTeam,
    this.voiceAnnouncer,
  });

  @override
  State<DoublesScoreboardScreen> createState() =>
      _DoublesScoreboardScreenState();
}

class _DoublesScoreboardScreenState extends State<DoublesScoreboardScreen> {
  late TableTennisScoringEngine _engine;
  late VoiceAnnouncer _voice;
  bool _voiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _engine = TableTennisScoringEngine(
      bestOf: widget.bestOf,
      firstServer: widget.firstServingTeam,
    );
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

    _voice.announcePoint(engine: _engine, event: event, server: server);

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

  void _resetMatch() => setState(() => _engine.resetMatch());

  /// The side's team-level display name for banners/dialogs — "Player
  /// 1"/"Player 2" meaning "side 1"/"side 2", the same wording and the
  /// same strings singles uses (see class doc comment).
  String _teamLabel(Player team) {
    final l10n = AppLocalizations.of(context);
    return team == Player.one ? l10n.player1Label : l10n.player2Label;
  }

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
              slot0Label: l10n.player1Label,
              slot1Label: l10n.player2Label,
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
              onTap: () => _scorePoint(Player.one),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.divider),
          Expanded(
            child: _DoublesTeamZone(
              key: const Key('team2Zone'),
              slot0Label: l10n.player3Label,
              slot1Label: l10n.player4Label,
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
              onTap: () => _scorePoint(Player.two),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoublesTeamZone extends StatelessWidget {
  final String slot0Label;
  final String slot1Label;
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
  final VoidCallback onTap;

  const _DoublesTeamZone({
    super.key,
    required this.slot0Label,
    required this.slot1Label,
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
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.accent.withValues(alpha: 0.12),
        splashColor: AppColors.accent.withValues(alpha: 0.18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _DoublesPlayerRow(
                label: slot0Label,
                serving: slot0Serving,
                receiving: slot0Receiving,
                servingTooltip: servingTooltip,
                receivingTooltip: receivingTooltip,
                serverIconKey: slot0ServerIconKey,
                receiverIconKey: slot0ReceiverIconKey,
              ),
              const SizedBox(height: 6),
              _DoublesPlayerRow(
                label: slot1Label,
                serving: slot1Serving,
                receiving: slot1Receiving,
                servingTooltip: servingTooltip,
                receivingTooltip: receivingTooltip,
                serverIconKey: slot1ServerIconKey,
                receiverIconKey: slot1ReceiverIconKey,
              ),
              Expanded(
                child: Center(
                  child: AnimatedScoreText(points: points, scoreKey: pointsKey),
                ),
              ),
              const SizedBox(height: 6),
              Text(gamesLabel, style: AppTypography.gamesLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoublesPlayerRow extends StatelessWidget {
  final String label;
  final bool serving;
  final bool receiving;
  final String servingTooltip;
  final String receivingTooltip;
  final Key serverIconKey;
  final Key receiverIconKey;

  const _DoublesPlayerRow({
    required this.label,
    required this.serving,
    required this.receiving,
    required this.servingTooltip,
    required this.receivingTooltip,
    required this.serverIconKey,
    required this.receiverIconKey,
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
                      key: serverIconKey, size: 18, color: AppColors.accent),
                )
              : receiving
                  ? Tooltip(
                      message: receivingTooltip,
                      child: Icon(Icons.call_received,
                          key: receiverIconKey,
                          size: 18,
                          color: AppColors.mutedText),
                    )
                  : null,
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.compactPlayerLabel),
      ],
    );
  }
}
