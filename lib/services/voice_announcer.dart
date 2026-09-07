import 'clip_player.dart';
import 'match_commentary.dart';
import 'tts_engine.dart';

/// Which sound source is currently backing announcements.
enum VoiceBackend {
  /// The device has the requested language voice installed; announcements
  /// are spoken live via [TtsEngine].
  deviceTts,

  /// No matching device voice was found (or checking for one failed);
  /// announcements fall back to the bundled pre-synthesized clip set.
  bundledClips,
}

/// Speaks match announcements, preferring the device's own TTS voice and
/// falling back to a small bundled English clip set when that voice isn't
/// installed.
///
/// Voice is a nice-to-have, never a requirement to keep scoring: every
/// public method here is best-effort and swallows its own errors rather
/// than throwing, so a TTS/audio failure never blocks or crashes the UI
/// (PHASES.md Phase 2).
class VoiceAnnouncer {
  /// The clip keys bundled under `assets/audio/en/` (numbers 0–21 plus
  /// the four key phrases). Any [Announcement.clipKeys] entry outside
  /// this set (e.g. a score above 21 in a long deuce battle) is skipped
  /// rather than played.
  static final Set<String> bundledClipKeys = {
    'game',
    'change_ends',
    'deuce',
    'match_point',
    for (var i = 0; i <= 21; i++) numberClipKey(i),
  };

  final TtsEngine _tts;
  final ClipPlayer _clips;
  final String _language;

  bool _muted;
  VoiceBackend? _backend;
  Future<void>? _resolution;

  VoiceAnnouncer({
    TtsEngine? ttsEngine,
    ClipPlayer? clipPlayer,
    String language = 'en-US',
    bool initiallyMuted = false,
  })  : _tts = ttsEngine ?? FlutterTtsEngine(),
        _clips = clipPlayer ?? AudioPlayersClipPlayer(),
        _language = language,
        _muted = initiallyMuted;

  bool get isMuted => _muted;

  /// Null until the backend has been resolved by the first announcement.
  VoiceBackend? get backend => _backend;

  void setMuted(bool muted) {
    _muted = muted;
    if (muted) {
      // Never let a queued announcement keep talking after mute.
      _tts.stop().catchError((_) {});
      _clips.stop().catchError((_) {});
    }
  }

  void toggleMuted() => setMuted(!_muted);

  /// Speaks (or plays clips for) [announcement]. No-ops silently when
  /// muted, when no voice is available, or if the underlying TTS/audio
  /// plugin throws.
  Future<void> announce(Announcement announcement) async {
    if (_muted) return;
    try {
      await _ensureBackendResolved();
      switch (_backend!) {
        case VoiceBackend.deviceTts:
          await _tts.speak(announcement.speech);
          break;
        case VoiceBackend.bundledClips:
          await _playClips(announcement.clipKeys);
          break;
      }
    } catch (_) {
      // Best-effort: swallow any TTS/audio failure.
    }
  }

  Future<void> _playClips(List<String> clipKeys) async {
    for (final key in clipKeys) {
      if (!bundledClipKeys.contains(key)) continue;
      try {
        await _clips.playClip('audio/en/$key.wav');
      } catch (_) {
        // Skip this clip, but still try the rest of the phrase.
      }
    }
  }

  Future<void> _ensureBackendResolved() {
    return _resolution ??= _resolveBackend();
  }

  Future<void> _resolveBackend() async {
    try {
      if (await _tts.isLanguageAvailable(_language)) {
        await _tts.setLanguage(_language);
        _backend = VoiceBackend.deviceTts;
        return;
      }
    } catch (_) {
      // Treat a plugin that can't answer the question as "not available".
    }
    _backend = VoiceBackend.bundledClips;
  }
}
