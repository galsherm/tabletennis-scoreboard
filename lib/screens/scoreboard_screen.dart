import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/scoring_engine.dart';
import '../services/match_commentary.dart';
import '../services/voice_announcer.dart';

class ScoreboardScreen extends StatefulWidget {
  final int bestOf;
  final Player firstServer;

  /// Overridable for tests; defaults to a real [VoiceAnnouncer] backed by
  /// the device's TTS engine and the bundled clip set.
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

  @override
  void initState() {
    super.initState();
    _engine = TableTennisScoringEngine(
      bestOf: widget.bestOf,
      firstServer: widget.firstServer,
    );
    _voice = widget.voiceAnnouncer ?? VoiceAnnouncer();
  }

  void _scorePoint(Player scorer) {
    if (!_engine.canScore) return;
    final event = _engine.addPoint(scorer);
    final server = _engine.currentServer; // who serves next, not who just served
    setState(() {});

    _voice.announce(announcementForPoint(
      engine: _engine,
      event: event,
      server: server,
    ));

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

  void _showChangeEndsBanner() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: Key('changeEndsSnackBar'),
        content: Text('Change ends'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showGameCompleteBanner(Player winner) {
    final label = winner == Player.one ? 'Player 1' : 'Player 2';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('gameCompleteSnackBar'),
        content: Text('$label wins the game — change ends'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMatchCompleteDialog(Player winner) {
    final label = winner == Player.one ? 'Player 1' : 'Player 2';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        key: const Key('matchCompleteDialog'),
        title: const Text('Match complete'),
        content: Text('$label wins the match!'),
        actions: [
          TextButton(
            key: const Key('newMatchButton'),
            onPressed: () {
              Navigator.of(context).pop();
              _resetMatch();
            },
            child: const Text('New match'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final server = _engine.currentServer;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Table Tennis'),
        actions: [
          IconButton(
            key: const Key('muteButton'),
            icon: Icon(_voice.isMuted ? Icons.volume_off : Icons.volume_up),
            tooltip: _voice.isMuted ? 'Unmute voice' : 'Mute voice',
            onPressed: _toggleMute,
          ),
          IconButton(
            key: const Key('undoButton'),
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _engine.canUndo ? _undo : null,
          ),
          IconButton(
            key: const Key('resetButton'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset match',
            onPressed: _resetMatch,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: _PlayerZone(
              key: const Key('player1Zone'),
              label: 'Player 1',
              points: _engine.player1Points,
              games: _engine.player1Games,
              isServer: server == Player.one,
              pointsKey: const Key('player1PointsText'),
              serverIconKey: const Key('player1ServerIcon'),
              onTap: () => _scorePoint(Player.one),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _PlayerZone(
              key: const Key('player2Zone'),
              label: 'Player 2',
              points: _engine.player2Points,
              games: _engine.player2Games,
              isServer: server == Player.two,
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
  final bool isServer;
  final Key pointsKey;
  final Key serverIconKey;
  final VoidCallback onTap;

  const _PlayerZone({
    super.key,
    required this.label,
    required this.points,
    required this.games,
    required this.isServer,
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
                  ? Icon(Icons.sports_tennis, key: serverIconKey)
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
            Text('Games: $games'),
          ],
        ),
      ),
    );
  }
}
