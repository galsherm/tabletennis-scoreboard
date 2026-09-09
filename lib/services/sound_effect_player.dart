import 'package:audioplayers/audioplayers.dart';

/// Fire-and-forget playback for a short, one-shot sound effect (e.g. the
/// coin-flip landing clink) — unlike [ClipPlayer], never waits for the
/// clip to finish playing.
///
/// [ClipPlayer.playClip] deliberately awaits an `onPlayerComplete` event
/// (with a timeout) because [VoiceAnnouncer] needs to know when one
/// bundled clip ends before starting the next one in a phrase. A single
/// ambient sound effect has no such sequencing need, and that
/// completion-await is exactly the part of [ClipPlayer] that would make
/// it risky to call unconditionally from a widget exercised by many
/// existing widget tests (a plugin with no real implementation under
/// `flutter test` could leave that awaited timeout pending). Skipping it
/// here removes that risk entirely: nothing is ever awaited beyond the
/// platform call that starts playback.
abstract class SoundEffectPlayer {
  Future<void> play(String assetPath);
}

/// Real [SoundEffectPlayer] backed by `audioplayers`.
class AudioPlayersSoundEffectPlayer implements SoundEffectPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String assetPath) async {
    await _player.play(AssetSource(assetPath));
  }
}
