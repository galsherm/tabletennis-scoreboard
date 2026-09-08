import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/player.dart';
import '../models/player_names.dart';
import '../models/scoring_engine.dart';
import '../services/commentary_strings.dart';
import '../services/voice_announcer.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_score_text.dart';
import '../widgets/match_complete_dialog.dart';

class ScoreboardScreen extends StatefulWidget {
  final int bestOf;
  final Player firstServer;

  /// Overridable for tests; defaults to a real [VoiceAnnouncer] backed by
  /// the device's TTS engine and the bundled clip set, in whichever
  /// language the widget tree is currently displaying.
  final VoiceAnnouncer? voiceAnnouncer;

  /// Custom player names, set on the setup screen before this match
  /// started — the *only* place names can be edited (Phase 4H). Once
  /// this screen is showing, names render as plain, uneditable text.
  final PlayerNames? initialNames;

  const ScoreboardScreen({
    super.key,
    required this.bestOf,
    required this.firstServer,
    this.voiceAnnouncer,
    this.initialNames,
  });

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  late TableTennisScoringEngine _engine;
  late VoiceAnnouncer _voice;
  bool _voiceInitialized = false;

  /// Custom names for this match (Phase 4F), fixed for the lifetime of
  /// this screen — set once from [widget.initialNames] on the setup
  /// screen and never mutated here (Phase 4H locks editing to setup
  /// only), including across a "New match" reset: since there's no way
  /// to re-edit a name from this screen, clearing it on reset would
  /// permanently lose it until the user backs all the way out to setup.
  late final PlayerNames _names;

  @override
  void initState() {
    super.initState();
    _engine = TableTennisScoringEngine(
      bestOf: widget.bestOf,
      firstServer: widget.firstServer,
    );
    _names = widget.initialNames ?? PlayerNames();
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

    // nameFor: a custom name (Phase 4F), once set, is what voice should
    // say too — a game/match win renamed "Alex" shouldn't still announce
    // "Player 1". Falls back to _voice.strings.playerLabel (the voice
    // layer's OWN language default), not the widget tree's UI-locale
    // label — those can legitimately differ (e.g. a screen configured
    // with an explicit VoiceAnnouncer in one language inside a UI
    // showing another, as several tests do), and voice should stay
    // internally consistent with itself when no custom name overrides
    // it. See PHASE4F_THEME_AND_NAMES.md.
    _voice.announcePoint(
      engine: _engine,
      event: event,
      server: server,
      nameFor: _voiceNameFor,
    );

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

  /// Resets the match itself. Custom names are *not* cleared — see the
  /// [_names] doc comment (Phase 4H changed this from Phase 4F's
  /// behavior, where "New match" used to reset names too).
  void _resetMatch() => setState(() => _engine.resetMatch());

  String _defaultPlayerLabel(Player player) {
    final l10n = AppLocalizations.of(context);
    return player == Player.one ? l10n.player1Label : l10n.player2Label;
  }

  String _playerLabel(Player player) {
    final slot = player == Player.one ? 1 : 2;
    return _names.resolve(slot, _defaultPlayerLabel(player));
  }

  /// Like [_playerLabel], but falls back to the voice layer's own
  /// language default ([VoiceAnnouncer.strings]) instead of the UI's
  /// [AppLocalizations] when no custom name is set — see the call site
  /// in [_scorePoint] for why those can differ.
  String _voiceNameFor(Player player) {
    final slot = player == Player.one ? 1 : 2;
    return _names.resolve(slot, _voice.strings.playerLabel(player));
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
      builder: (_) => MatchCompleteDialog(
        key: const Key('matchCompleteDialog'),
        titleText: l10n.matchCompleteDialogTitle,
        messageText: l10n.matchCompleteMessage(_playerLabel(winner)),
        buttonText: l10n.newMatchButton,
        onNewMatch: () {
          Navigator.of(context).pop();
          _resetMatch();
        },
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
            child: _PlayerZone(
              key: const Key('player1Zone'),
              label: _playerLabel(Player.one),
              points: _engine.player1Points,
              gamesLabel: l10n.gamesCountLabel(_engine.player1Games),
              isServer: server == Player.one,
              servingTooltip: l10n.servingTooltip,
              pointsKey: const Key('player1PointsText'),
              serverIconKey: const Key('player1ServerIcon'),
              nameTextKey: const Key('player1NameText'),
              onTap: () => _scorePoint(Player.one),
            ),
          ),
          VerticalDivider(width: 1, color: context.palette.divider),
          Expanded(
            child: _PlayerZone(
              key: const Key('player2Zone'),
              label: _playerLabel(Player.two),
              points: _engine.player2Points,
              gamesLabel: l10n.gamesCountLabel(_engine.player2Games),
              isServer: server == Player.two,
              servingTooltip: l10n.servingTooltip,
              pointsKey: const Key('player2PointsText'),
              serverIconKey: const Key('player2ServerIcon'),
              nameTextKey: const Key('player2NameText'),
              onTap: () => _scorePoint(Player.two),
            ),
          ),
        ],
      ),
    );
  }
}

/// A large, tap-anywhere half of the scoreboard. Layout defers entirely
/// to the score digit at its center — the player label above and the
/// games count below are deliberately small and muted (see
/// [AppTypography]) so the eye lands on the number first.
class _PlayerZone extends StatelessWidget {
  final String label;
  final int points;
  final String gamesLabel;
  final bool isServer;
  final String servingTooltip;
  final Key pointsKey;
  final Key serverIconKey;
  final Key nameTextKey;
  final VoidCallback onTap;

  const _PlayerZone({
    super.key,
    required this.label,
    required this.points,
    required this.gamesLabel,
    required this.isServer,
    required this.servingTooltip,
    required this.pointsKey,
    required this.serverIconKey,
    required this.nameTextKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        // A visible highlight while held, on top of the ripple — courtside
        // taps are quick and imprecise, so the press feedback needs to be
        // obvious, not subtle.
        highlightColor: context.palette.accent.withValues(alpha: 0.12),
        splashColor: context.palette.accent.withValues(alpha: 0.18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 30,
                child: isServer
                    ? Tooltip(
                        message: servingTooltip,
                        child: Icon(
                          Icons.sports_tennis,
                          key: serverIconKey,
                          color: context.palette.accent,
                          size: 26,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              // Plain, uneditable text — names can only be set on the
              // setup screen (Phase 4H); the in-match screen stays
              // focused purely on score, with no edit affordance at all.
              Text(
                label,
                key: nameTextKey,
                style: AppTypography.playerLabel(context),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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
