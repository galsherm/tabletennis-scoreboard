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
    // Best-effort, iOS-only: use the "ambient" session category so an
    // announcement mixes with whatever else is playing (e.g. music)
    // instead of interrupting it. Never let this block construction.
    _tts
        .setIosAudioCategory(IosTextToSpeechAudioCategory.ambient, const [])
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
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}
