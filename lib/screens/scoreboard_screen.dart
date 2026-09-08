import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/player.dart';
import '../models/scoring_engine.dart';
import '../services/commentary_strings.dart';
import '../services/voice_announcer.dart';

class ScoreboardScreen extends StatefulWidget {
  final int bestOf;
  final Player firstServer;

  /// Overridable for tests; defaults to a real [VoiceAnnouncer] backed by
  /// the device's TTS engine and the bundled clip set, in whichever
  /// language the widget tree is currently displaying.
  final VoiceAnnouncer? voiceAnnouncer;

  const ScoreboardScreen({
    super.key,
    required this.bestOf,
    required this.firstServer,
    this.voiceAnnouncer,
  });

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  late TableTennisScoringEngine _engine;
  late VoiceAnnouncer _voice;
  bool _voiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _engine = TableTennisScoringEngine(
      bestOf: widget.bestOf,
      firstServer: widget.firstServer,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reading the effective locale requires an inherited widget lookup,
    // which isn't safe in initState — this runs once, right before the
    // first build, which is early enough since the match's language is
    // fixed for the lifetime of this screen (changing the override sends
    // the user back through setup for their next match).
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

    // Exactly one of these three branches applies per point — a
    // completed game always implies a change of ends, so we don't
    // show two separate banners for the same point.
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

  String _playerLabel(Player player) {
    final l10n = AppLocalizations.of(context);
    return player == Player.one ? l10n.player1Label : l10n.player2Label;
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
            .gameCompleteMessage(_playerLabel(winner))),
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
        content: Text(l10n.matchCompleteMessage(_playerLabel(winner))),
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
    final server = _engine.currentServer;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scoreboardTitle),
        actions: [
          IconButton(
            key: const Key('muteButton'),
            icon: Icon(_voice.isMuted ? Icons.volume_off : Icons.volume_up),
            tooltip: _voice.isMuted ? l10n.unmuteTooltip : l10n.muteTooltip,
            onPressed: _toggleMute,
          ),
          IconButton(
            key: const Key('undoButton'),
            icon: const Icon(Icons.undo),
            tooltip: l10n.undoTooltip,
            onPressed: _engine.canUndo ? _undo : null,
          ),
          IconButton(
            key: const Key('resetButton'),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.resetTooltip,
            onPressed: _resetMatch,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: _PlayerZone(
              key: const Key('player1Zone'),
              label: l10n.player1Label,
              points: _engine.player1Points,
              games: _engine.player1Games,
              gamesLabel: l10n.gamesCountLabel(_engine.player1Games),
              isServer: server == Player.one,
              servingTooltip: l10n.servingTooltip,
              pointsKey: const Key('player1PointsText'),
              serverIconKey: const Key('player1ServerIcon'),
              onTap: () => _scorePoint(Player.one),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _PlayerZone(
              key: const Key('player2Zone'),
              label: l10n.player2Label,
              points: _engine.player2Points,
              games: _engine.player2Games,
              gamesLabel: l10n.gamesCountLabel(_engine.player2Games),
              isServer: server == Player.two,
              servingTooltip: l10n.servingTooltip,
              pointsKey: const Key('player2PointsText'),
              serverIconKey: const Key('player2ServerIcon'),
              onTap: () => _scorePoint(Player.two),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerZone extends StatelessWidget {
  final String label;
  final int points;
  final int games;
  final String gamesLabel;
  final bool isServer;
  final String servingTooltip;
  final Key pointsKey;
  final Key serverIconKey;
  final VoidCallback onTap;

  const _PlayerZone({
    super.key,
    required this.label,
    required this.points,
    required this.games,
    required this.gamesLabel,
    required this.isServer,
    required this.servingTooltip,
    required this.pointsKey,
    required this.serverIconKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 32,
              child: isServer
                  ? Tooltip(
                      message: servingTooltip,
                      child: Icon(Icons.sports_tennis, key: serverIconKey),
                    )
                  : null,
            ),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '$points',
              key: pointsKey,
              style: const TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(gamesLabel),
          ],
        ),
      ),
    );
  }
}
