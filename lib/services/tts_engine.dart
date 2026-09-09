import 'dart:io';

import 'package:flutter/services.dart';
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

/// Requests/abandons Android audio focus directly via `MainActivity.kt`'s
/// native channel, rather than through `flutter_tts`'s own built-in
/// `focus: true` handling.
///
/// Real-device testing (Phase 4K) found `flutter_tts`'s own focus request
/// (read from its Kotlin source) already asks for the right *type*
/// (`AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`, never one that asks others to
/// pause) but builds it with no explicit `AudioAttributes` at all, which
/// `adb shell dumpsys audio` shows registering as a bare `USAGE_MEDIA`/
/// `CONTENT_TYPE_UNKNOWN` request. Android's own guidance for this exact
/// case — a brief spoken announcement over other audio, the same category
/// as turn-by-turn navigation — is `USAGE_ASSISTANCE_SONIFICATION`/
/// `CONTENT_TYPE_SPEECH`, which the plugin has no API to configure. See
/// PHASE4K_AUDIO_MENU_AND_ICON.md.
///
/// A real bug found via real-device stress testing (Phase 4K follow-up):
/// [ScoreboardScreen._scorePoint] calls `announcePoint` without awaiting
/// it, and nothing debounces rapid scoring taps, so a fast real rally can
/// easily start a second announcement while the first is still speaking.
/// `MainActivity.kt`'s native side previously tracked only a single
/// mutable `AudioFocusRequest` reference, overwritten by each new
/// request — so an *older* utterance's completion/cancel callback,
/// firing after a *newer* one had already requested focus, would
/// abandon the newer (still-needed) request instead of its own stale
/// one, releasing focus back to the music mid-announcement. Verified on
/// a real device: five rapid taps produced request→abandon pairs only
/// 11-21ms apart (physically too fast for real speech), confirming
/// overlap was actually happening. Fixed with reference counting here —
/// entirely on the Dart side, no native change needed — so the native
/// focus request is only actually made on the first overlapping hold and
/// only actually abandoned once every overlapping hold has ended.
class _AndroidAudioDucking {
  static const _channel =
      MethodChannel('com.example.tabletennis_scoreboard/audio_ducking');

  static int _holdCount = 0;

  /// Called once per announcement, before it starts speaking.
  static Future<void> requestFocus() async {
    if (!Platform.isAndroid) return;
    _holdCount++;
    if (_holdCount > 1) return; // already held by an overlapping utterance
    await _channel.invokeMethod('requestDuckingFocus').catchError((_) {});
  }

  /// Called once per announcement, when that specific utterance ends
  /// (completes, is cancelled, or errors) — never a hard reset, so it
  /// can't cut off a still-speaking overlapping utterance's hold.
  static Future<void> releaseFocus() async {
    if (!Platform.isAndroid) return;
    if (_holdCount == 0) return; // defensive: never go negative
    _holdCount--;
    if (_holdCount > 0) return; // another overlapping utterance still holds it
    await _channel.invokeMethod('abandonDuckingFocus').catchError((_) {});
  }

  /// Called from [FlutterTtsEngine.stop] (currently only reached via
  /// [VoiceAnnouncer.setMuted]) — an explicit "stop everything now"
  /// request, unlike [releaseFocus]'s one-hold-at-a-time accounting, so
  /// it unconditionally resets the count and abandons focus regardless
  /// of how many holds were outstanding.
  static Future<void> resetFocus() async {
    if (!Platform.isAndroid) return;
    _holdCount = 0;
    await _channel.invokeMethod('abandonDuckingFocus').catchError((_) {});
  }
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
    // Android audio focus is released the moment this utterance finishes,
    // is cancelled, or errors — matching exactly the three paths
    // `flutter_tts`'s own Kotlin plugin releases its (unused, since we
    // pass `focus: false`) internal focus request from. Without covering
    // all three, a cancelled or failed announcement would leave this app
    // holding focus indefinitely, keeping other apps ducked/paused.
    _tts.setCompletionHandler(() => _AndroidAudioDucking.releaseFocus());
    _tts.setCancelHandler(() => _AndroidAudioDucking.releaseFocus());
    _tts.setErrorHandler((_) => _AndroidAudioDucking.releaseFocus());
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
    // Android audio focus is requested through `_AndroidAudioDucking`
    // (native `MainActivity.kt` code — see its doc comment and
    // PHASE4K_AUDIO_MENU_AND_ICON.md) rather than `flutter_tts`'s own
    // `focus: true`, so it's requested with the right `AudioAttributes`
    // and `focus: false` here avoids the plugin making a second,
    // differently-configured request of its own alongside it.
    await _AndroidAudioDucking.requestFocus();
    await _tts.speak(text, focus: false);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    await _AndroidAudioDucking.resetFocus();
  }
}
