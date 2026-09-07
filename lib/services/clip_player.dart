import 'package:audioplayers/audioplayers.dart';

/// Plays a single bundled audio clip by its asset path, relative to
/// `assets/` (e.g. `"audio/en/game.wav"`).
///
/// Wrapped behind an interface, like [TtsEngine], so [VoiceAnnouncer] can
/// be tested without touching real audio plugins.
abstract class ClipPlayer {
  Future<void> playClip(String assetPath);

  Future<void> stop();
}

/// Real [ClipPlayer] backed by `audioplayers`.
class AudioPlayersClipPlayer implements ClipPlayer {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayersClipPlayer() {
    // Best-effort: a bundled clip is a brief courtside announcement, not
    // primary media, so ask to duck (not fully interrupt) other audio
    // (e.g. music) rather than take exclusive audio focus. Never let this
    // block construction on a platform that doesn't support it.
    AudioPlayer.global
        .setAudioContext(AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ))
        .catchError((_) {});
  }

  @override
  Future<void> playClip(String assetPath) async {
    await _player.play(AssetSource(assetPath));
    // Bundled clips are all a couple of seconds at most; if the
    // completion event never arrives on some platform, don't let voice
    // announcements stall the rest of the app waiting for it.
    await _player.onPlayerComplete.first.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }
}
