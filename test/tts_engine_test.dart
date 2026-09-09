import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';

/// Real-device testing (Phase 4J) found that voice announcements weren't
/// actually ducking background audio (e.g. music) at all, despite Phase
/// 2's doc comments claiming best-effort ducking config — see
/// PHASE4J_MENU_AUDIO_AND_NAME_SAVE.md for the `adb shell dumpsys audio`
/// evidence and the fix (Android: pass `focus: true` to `flutter_tts`'s
/// `speak()`; iOS: switch from the `ambient` category, which cannot duck
/// at all, to `playback` with `duckOthers` +
/// `interruptSpokenAudioAndMixWithOthers`).
///
/// Neither half of that fix is actually unit-testable here — not just as
/// a limitation of this test, but structurally: `flutter_tts`'s own
/// Dart source only sends `focus` to the platform channel `if
/// (Platform.isAndroid)`, and only calls `setIosAudioCategory`'s
/// underlying channel method `if (Platform.isIOS)` — both checked
/// against `dart:io`'s `Platform`, which reports the *test host's* OS
/// (this repo's tests run on Windows), never "as" a mobile platform.
/// Intercepting the `flutter_tts` method channel from `flutter_test`
/// therefore can't observe either code path executing at all, on any
/// host. What's left worth asserting here is just the "never throws"
/// contract every service in this app follows.
///
/// The real verification for this fix is the on-device testing recorded
/// in PHASE4J_MENU_AUDIO_AND_NAME_SAVE.md: the Android side was
/// confirmed with `adb shell dumpsys audio` showing this app's process
/// requesting `GAIN_TRANSIENT_MAY_DUCK` and Spotify's own entry
/// switching to `LOSS_TRANSIENT_CAN_DUCK` (ducked, never paused) for
/// the duration of an announcement, then reverting automatically. The
/// iOS side is **not** empirically verified — no iOS device or
/// simulator was available in this environment — and is based on
/// correctly following Apple's own documented AVAudioSession semantics
/// (`duckOthers` requires the `playback`/`playAndRecord` category,
/// which `ambient` cannot provide) rather than an observed result. This
/// gap is flagged explicitly rather than assumed away.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('constructing FlutterTtsEngine never throws, even if the '
      'platform channel is unavailable (the plugin has no real '
      'implementation under flutter test)', () async {
    const channel = MethodChannel('flutter_tts');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    expect(() => FlutterTtsEngine(), returnsNormally);
    await pumpEventQueue();
  });
}
