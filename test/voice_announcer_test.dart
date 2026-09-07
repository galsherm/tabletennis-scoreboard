import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/match_commentary.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';
import 'package:tabletennis_scoreboard/services/voice_announcer.dart';

class _FakeTtsEngine implements TtsEngine {
  final bool available;
  final bool throwOnCheck;
  final List<String> spoken = [];
  String? languageSet;

  _FakeTtsEngine({this.available = true, this.throwOnCheck = false});

  @override
  Future<bool> isLanguageAvailable(String language) async {
    if (throwOnCheck) {
      throw Exception('platform cannot answer this query');
    }
    return available;
  }

  @override
  Future<void> setLanguage(String language) async {
    languageSet = language;
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

class _ThrowingSpeakTtsEngine implements TtsEngine {
  @override
  Future<bool> isLanguageAvailable(String language) async => true;

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> speak(String text) async => throw Exception('speak failed');

  @override
  Future<void> stop() async {}
}

class _FakeClipPlayer implements ClipPlayer {
  final List<String> played = [];

  @override
  Future<void> playClip(String assetPath) async {
    played.add(assetPath);
  }

  @override
  Future<void> stop() async {}
}

class _PartiallyFailingClipPlayer implements ClipPlayer {
  final String failOn;
  final List<String> played = [];

  _PartiallyFailingClipPlayer({required this.failOn});

  @override
  Future<void> playClip(String assetPath) async {
    if (assetPath == failOn) throw Exception('missing asset');
    played.add(assetPath);
  }

  @override
  Future<void> stop() async {}
}

void main() {
  group('backend resolution', () {
    test('uses device TTS when the language voice is installed', () async {
      final tts = _FakeTtsEngine(available: true);
      final clips = _FakeClipPlayer();
      final voice = VoiceAnnouncer(ttsEngine: tts, clipPlayer: clips);

      await voice
          .announce(const Announcement('5, 3', ['number_5', 'number_3']));

      expect(voice.backend, VoiceBackend.deviceTts);
      expect(tts.spoken, ['5, 3']);
      expect(tts.languageSet, 'en-US');
      expect(clips.played, isEmpty);
    });

    test('falls back to bundled clips when no device voice is installed',
        () async {
      final tts = _FakeTtsEngine(available: false);
      final clips = _FakeClipPlayer();
      final voice = VoiceAnnouncer(ttsEngine: tts, clipPlayer: clips);

      await voice
          .announce(const Announcement('5, 3', ['number_5', 'number_3']));

      expect(voice.backend, VoiceBackend.bundledClips);
      expect(clips.played, ['audio/en/number_5.wav', 'audio/en/number_3.wav']);
      expect(tts.spoken, isEmpty);
    });

    test('falls back to bundled clips if the availability check throws',
        () async {
      final tts = _FakeTtsEngine(throwOnCheck: true);
      final clips = _FakeClipPlayer();
      final voice = VoiceAnnouncer(ttsEngine: tts, clipPlayer: clips);

      await expectLater(
        voice.announce(const Announcement('Deuce', ['deuce'])),
        completes,
      );

      expect(voice.backend, VoiceBackend.bundledClips);
      expect(clips.played, ['audio/en/deuce.wav']);
    });

    test('resolves the backend once and reuses it for later announcements',
        () async {
      final tts = _FakeTtsEngine(available: true);
      final voice = VoiceAnnouncer(ttsEngine: tts, clipPlayer: _FakeClipPlayer());

      await voice.announce(const Announcement('1, 0', ['number_1', 'number_0']));
      await voice.announce(const Announcement('2, 0', ['number_2', 'number_0']));

      expect(tts.spoken, ['1, 0', '2, 0']);
    });

    test('skips clip keys outside the bundled 0-21 range', () async {
      final clips = _FakeClipPlayer();
      final voice = VoiceAnnouncer(
        ttsEngine: _FakeTtsEngine(available: false),
        clipPlayer: clips,
      );

      await voice
          .announce(const Announcement('25, 23', ['number_25', 'number_23']));

      expect(clips.played, isEmpty);
    });
  });

  group('mute', () {
    test('a muted announcer never touches TTS or the clip player', () async {
      final tts = _FakeTtsEngine(available: true);
      final clips = _FakeClipPlayer();
      final voice = VoiceAnnouncer(
        ttsEngine: tts,
        clipPlayer: clips,
        initiallyMuted: true,
      );

      await voice
          .announce(const Announcement('5, 3', ['number_5', 'number_3']));

      expect(tts.spoken, isEmpty);
      expect(clips.played, isEmpty);
      expect(voice.backend, isNull); // never even resolved
    });

    test('toggleMuted flips state and unmuting resumes announcements',
        () async {
      final tts = _FakeTtsEngine(available: true);
      final voice = VoiceAnnouncer(ttsEngine: tts, clipPlayer: _FakeClipPlayer());

      expect(voice.isMuted, isFalse);
      voice.toggleMuted();
      expect(voice.isMuted, isTrue);

      await voice.announce(const Announcement('1, 0', ['number_1', 'number_0']));
      expect(tts.spoken, isEmpty);

      voice.toggleMuted();
      await voice.announce(const Announcement('1, 0', ['number_1', 'number_0']));
      expect(tts.spoken, ['1, 0']);
    });
  });

  group('graceful failure', () {
    test('a speak() failure does not throw out of announce()', () async {
      final voice = VoiceAnnouncer(
        ttsEngine: _ThrowingSpeakTtsEngine(),
        clipPlayer: _FakeClipPlayer(),
      );

      await expectLater(
        voice.announce(const Announcement('1, 0', ['number_1', 'number_0'])),
        completes,
      );
    });

    test('one bad clip does not stop the rest of the phrase playing',
        () async {
      final clips =
          _PartiallyFailingClipPlayer(failOn: 'audio/en/number_1.wav');
      final voice = VoiceAnnouncer(
        ttsEngine: _FakeTtsEngine(available: false),
        clipPlayer: clips,
      );

      await voice
          .announce(const Announcement('1, 0', ['number_1', 'number_0']));

      expect(clips.played, ['audio/en/number_0.wav']);
    });
  });
}
