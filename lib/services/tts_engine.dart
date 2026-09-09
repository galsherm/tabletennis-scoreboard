import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around the platform text-to-speech engine.
///
/// [VoiceAnnouncer] talks to this interface rather than `FlutterTts`
/// directly so tests can supply a fake — `flutter_tts` calls into a
/// platform channel that isn't available under `flutter test`.
abstract class TtsEngine {
  /// Whether a voice for [language] (e.g. `"en-US"`) is installed on this
  /// device. Must not throw on platforms where the underlying plugin
  /// doesn't support the query — callers treat a thrown error the same as
  /// "not available".
  Future<bool> isLanguageAvailable(String language);

  Future<void> setLanguage(String language);

  Future<void> speak(String text);

  Future<void> stop();
}

/// Real [TtsEngine] backed by `flutter_tts`.
class FlutterTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();

  FlutterTtsEngine() {
    // Best-effort: configure both platforms to duck (lower the volume of)
    // other audio — e.g. music — rather than either silently overlapping
    // it or fully interrupting it. Never let this block construction.
    //
    // iOS: the `ambient` category previously used here mixes with other
    // audio at full volume with no ducking at all — Apple's
    // `duckOthers`/`interruptSpokenAudioAndMixWithOthers` options are
    // only valid under the `playback` (or `playAndRecord`) category, not
    // `ambient`. `interruptSpokenAudioAndMixWithOthers` is Apple's own
    // recommended pairing for "occasional spoken audio" apps (turn-by-
    // turn navigation, exercise apps — the same category this app's
    // announcements fall into): duck non-spoken audio (music), but fully
    // pause-and-resume other *spoken* audio (podcasts, other TTS) rather
    // than overlapping two voices unintelligibly.
    _tts
        .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions
              .interruptSpokenAudioAndMixWithOthers,
        ])
        .catchError((_) {});
  }

  @override
  Future<bool> isLanguageAvailable(String language) async {
    final result = await _tts.isLanguageAvailable(language);
    // Different platform implementations report this as a bool or as an
    // int (1/0), so normalize rather than assume a type.
    if (result is bool) return result;
    if (result is num) return result != 0;
    return false;
  }

  @override
  Future<void> setLanguage(String language) async {
    await _tts.setLanguage(language);
  }

  @override
  Future<void> speak(String text) async {
    // Android: `flutter_tts.speak()` only requests audio focus (which is
    // what actually triggers other apps' ducking behavior) when `focus:
    // true` is passed — it defaults to `false`, i.e. no focus request at
    // all. Verified on a real device that this was the actual bug: with
    // the default, no entry for this app ever appeared in `adb shell
    // dumpsys audio`'s focus stack while a TTS announcement played over
    // Spotify — the announcement just mixed in uncoordinated, and
    // Spotify never ducked. `focus: true` makes the plugin request
    // `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` before speaking and abandon it
    // after, which is what actually signals other apps to lower their
    // volume. See PHASE4J_MENU_AUDIO_AND_NAME_SAVE.md.
    await _tts.speak(text, focus: true);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}
