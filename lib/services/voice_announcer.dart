import '../models/player.dart';
import '../models/point_event.dart';
import '../models/scoring_engine.dart';
import 'clip_player.dart';
import 'commentary_strings.dart';
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
/// falling back to a bundled clip set when that voice isn't installed.
///
/// Which language is spoken — English, German, or French as of Phase 3 —
/// is entirely determined by the [CommentaryStrings] passed in at
/// construction: it supplies both the device-TTS locale tag to request and
/// the bundled-clip subfolder to fall back to.
///
/// Voice is a nice-to-have, never a requirement to keep scoring: every
/// public method here is best-effort and swallows its own errors rather
/// than throwing, so a TTS/audio failure never blocks or crashes the UI
/// (PHASES.md Phase 2).
class VoiceAnnouncer {
  /// The clip keys bundled under `assets/audio/<language>/` (numbers 0–21
  /// plus the four key phrases). Any [Announcement.clipKeys] entry outside
  /// this set (e.g. a score above 21 in a long deuce battle) is skipped
  /// rather than played. Language-agnostic: the same key names are reused
  /// under each language's subfolder.
  static final Set<String> bundledClipKeys = {
    'game',
    'change_ends',
    'deuce',
    'match_point',
    for (var i = 0; i <= 21; i++) numberClipKey(i),
  };

  final TtsEngine _tts;
  final ClipPlayer _clips;

  /// Phrase templates, TTS locale, and clip folder for the language this
  /// announcer speaks.
  final CommentaryStrings strings;

  bool _muted;
  VoiceBackend? _backend;
  Future<void>? _resolution;

  VoiceAnnouncer({
    TtsEngine? ttsEngine,
    ClipPlayer? clipPlayer,
    this.strings = CommentaryStrings.en,
    bool initiallyMuted = false,
  })  : _tts = ttsEngine ?? FlutterTtsEngine(),
        _clips = clipPlayer ?? AudioPlayersClipPlayer(),
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

  /// Convenience wrapper: decides what to say for the point just scored
  /// (via [announcementForPoint], using [strings] for the current
  /// language) and speaks it. See [announcementForPoint] for the meaning
  /// of [server], [isDoubles], and [nameFor].
  Future<void> announcePoint({
    required TableTennisScoringEngine engine,
    required PointEvent event,
    required Player server,
    bool isDoubles = false,
    String Function(Player)? nameFor,
  }) {
    return announce(announcementForPoint(
      engine: engine,
      event: event,
      server: server,
      strings: strings,
      isDoubles: isDoubles,
      nameFor: nameFor,
    ));
  }

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
        await _clips.playClip('audio/${strings.clipFolder}/$key.wav');
      } catch (_) {
        // Skip this clip, but still try the rest of the phrase. This is
        // also how a language with no bundled clips yet (see PHASES.md
        // Phase 3 — German/French clips are architecture-only for now,
        // no recorded audio ships) degrades: every clip attempt fails to
        // find its asset and is silently skipped, so playback is a
        // silent no-op rather than a crash.
      }
    }
  }

  Future<void> _ensureBackendResolved() {
    return _resolution ??= _resolveBackend();
  }

  Future<void> _resolveBackend() async {
    try {
      if (await _tts.isLanguageAvailable(strings.ttsLocale)) {
        await _tts.setLanguage(strings.ttsLocale);
        _backend = VoiceBackend.deviceTts;
        return;
      }
    } catch (_) {
      // Treat a plugin that can't answer the question as "not available".
    }
    _backend = VoiceBackend.bundledClips;
  }
}
