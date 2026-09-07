import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/screens/scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';
import 'package:tabletennis_scoreboard/services/voice_announcer.dart';

/// Records every string it's asked to speak, standing in for the device
/// voice so these tests never touch a real platform channel.
class _RecordingTtsEngine implements TtsEngine {
  final List<String> spoken = [];

  @override
  Future<bool> isLanguageAvailable(String language) async => true;

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

class _NoopClipPlayer implements ClipPlayer {
  @override
  Future<void> playClip(String assetPath) async {}

  @override
  Future<void> stop() async {}
}

Future<void> _pumpScoreboard(
  WidgetTester tester, {
  required VoiceAnnouncer voice,
  int bestOf = 5,
}) {
  return tester.pumpWidget(MaterialApp(
    home: ScoreboardScreen(
      bestOf: bestOf,
      firstServer: Player.one,
      voiceAnnouncer: voice,
    ),
  ));
}

void main() {
  testWidgets('scoring a point announces the new score by voice',
      (tester) async {
    final tts = _RecordingTtsEngine();
    final voice = VoiceAnnouncer(ttsEngine: tts, clipPlayer: _NoopClipPlayer());
    await _pumpScoreboard(tester, voice: voice);

    await tester.tap(find.byKey(const Key('player1Zone')));
    await tester.pump();
    await tester.pump();

    expect(tts.spoken, ['1, 0']);
  });

  testWidgets('the mute button starts unmuted and shows a volume icon',
      (tester) async {
    final voice = VoiceAnnouncer(
      ttsEngine: _RecordingTtsEngine(),
      clipPlayer: _NoopClipPlayer(),
    );
    await _pumpScoreboard(tester, voice: voice);

    expect(voice.isMuted, isFalse);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.byIcon(Icons.volume_off), findsNothing);
  });

  testWidgets('tapping the mute button silences voice and flips the icon',
      (tester) async {
    final tts = _RecordingTtsEngine();
    final voice = VoiceAnnouncer(ttsEngine: tts, clipPlayer: _NoopClipPlayer());
    await _pumpScoreboard(tester, voice: voice);

    await tester.tap(find.byKey(const Key('muteButton')));
    await tester.pump();

    expect(voice.isMuted, isTrue);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsNothing);

    await tester.tap(find.byKey(const Key('player1Zone')));
    await tester.pump();
    await tester.pump();

    expect(tts.spoken, isEmpty);
  });

  testWidgets('tapping mute twice restores voice announcements',
      (tester) async {
    final tts = _RecordingTtsEngine();
    final voice = VoiceAnnouncer(ttsEngine: tts, clipPlayer: _NoopClipPlayer());
    await _pumpScoreboard(tester, voice: voice);

    await tester.tap(find.byKey(const Key('muteButton')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('muteButton')));
    await tester.pump();

    expect(voice.isMuted, isFalse);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);

    await tester.tap(find.byKey(const Key('player1Zone')));
    await tester.pump();
    await tester.pump();

    expect(tts.spoken, ['1, 0']);
  });

  testWidgets('winning the game announces the game and change of ends',
      (tester) async {
    final tts = _RecordingTtsEngine();
    final voice = VoiceAnnouncer(ttsEngine: tts, clipPlayer: _NoopClipPlayer());
    await _pumpScoreboard(tester, voice: voice);

    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byKey(const Key('player1Zone')));
      await tester.pump();
    }
    await tester.pump();

    expect(tts.spoken.last, 'Game, Player 1. Change ends.');
  });

  testWidgets(
      'a missing device voice does not crash the screen or block scoring',
      (tester) async {
    final voice = VoiceAnnouncer(
      ttsEngine: _AlwaysThrowingTtsEngine(),
      clipPlayer: _NoopClipPlayer(),
    );
    await _pumpScoreboard(tester, voice: voice);

    await tester.tap(find.byKey(const Key('player1Zone')));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Text>(find.byKey(const Key('player1PointsText'))).data,
      '1',
    );
  });
}

class _AlwaysThrowingTtsEngine implements TtsEngine {
  @override
  Future<bool> isLanguageAvailable(String language) async =>
      throw Exception('no voice info available on this device');

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> speak(String text) async =>
      throw Exception('speak is not supported');

  @override
  Future<void> stop() async {}
}
