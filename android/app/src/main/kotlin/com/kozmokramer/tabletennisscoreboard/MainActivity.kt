package com.kozmokramer.tabletennisscoreboard

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Phase 4K: a small native audio-focus channel, used instead of
/// `flutter_tts`'s own built-in `focus: true` handling.
///
/// The plugin's own focus request (confirmed by reading its Kotlin source,
/// `FlutterTtsPlugin.kt`) already asks for the *correct* focus type —
/// `AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`, never a type that
/// asks other apps to pause — but it builds that request with no explicit
/// `AudioAttributes` at all, so Android registers it as a bare
/// `USAGE_MEDIA`/`CONTENT_TYPE_UNKNOWN` request (visible in `adb shell
/// dumpsys audio`'s focus-event log). Android's own guidance for exactly
/// this case — a brief spoken announcement layered over other audio, the
/// same category as turn-by-turn navigation prompts — is to declare
/// `USAGE_ASSISTANCE_SONIFICATION`/`CONTENT_TYPE_SPEECH` on the request,
/// which `flutter_tts` has no API surface to configure. This channel
/// builds the request directly so that attribute is set correctly. See
/// PHASE4K_AUDIO_MENU_AND_ICON.md for the on-device verification this was
/// built to support.
class MainActivity : FlutterActivity() {
    private val channelName = "com.example.tabletennis_scoreboard/audio_ducking"
    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestDuckingFocus" -> {
                        result.success(requestDuckingFocus())
                    }
                    "abandonDuckingFocus" -> {
                        abandonDuckingFocus()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestDuckingFocus(): Boolean {
        val manager = audioManager ?: return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            // Pre-O has no AudioFocusRequest/AudioAttributes builder pairing;
            // the deprecated overload's stream-type hint is the closest
            // equivalent and still requests the correct (ducking, not
            // pausing) gain type.
            @Suppress("DEPRECATION")
            val outcome = manager.requestAudioFocus(
                null,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
            )
            return outcome == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            .setAudioAttributes(attributes)
            // Explicit, matching the plugin's own (correct) default: this
            // app is the one asking others to duck, not the one that could
            // itself be asked to duck by something higher-priority, so this
            // flag doesn't change anything observable here — set anyway so
            // the intent (never prefer being paused over ducking) is
            // explicit rather than left to the API's default.
            .setWillPauseWhenDucked(false)
            .setOnAudioFocusChangeListener { }
            .build()
        focusRequest = request
        val outcome = manager.requestAudioFocus(request)
        return outcome == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonDuckingFocus() {
        val manager = audioManager ?: return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            manager.abandonAudioFocus(null)
            return
        }
        focusRequest?.let { manager.abandonAudioFocusRequest(it) }
        focusRequest = null
    }
}
