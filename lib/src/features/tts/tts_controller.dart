import 'package:flutter_tts/flutter_tts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'tts_state.dart';

part 'tts_controller.g.dart';

/// Riverpod notifier that wraps [FlutterTts].
///
/// Not keepAlive — disposed when the shorts feed leaves the tree, which
/// automatically stops any ongoing speech.
@riverpod
class TtsController extends _$TtsController {
  FlutterTts? _tts;

  @override
  TtsState build() {
    ref.onDispose(_cleanup);
    return TtsState.idle;
  }

  Future<FlutterTts> _engine() async {
    if (_tts != null) return _tts!;

    final tts = FlutterTts();
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.5);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);

    tts.setStartHandler(() => state = TtsState.speaking);
    tts.setCompletionHandler(() => state = TtsState.idle);
    tts.setPauseHandler(() => state = TtsState.paused);
    tts.setContinueHandler(() => state = TtsState.speaking);
    tts.setErrorHandler((_) => state = TtsState.error);

    _tts = tts;
    return tts;
  }

  /// Speak [text]. Stops any current speech first.
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    try {
      final tts = await _engine();
      await tts.stop();
      await tts.speak(text);
    } catch (_) {
      state = TtsState.error;
    }
  }

  /// Pause ongoing speech.
  Future<void> pause() async {
    try {
      await _tts?.pause();
    } catch (_) {
      state = TtsState.error;
    }
  }

  /// Stop and reset to idle.
  Future<void> stop() async {
    try {
      await _tts?.stop();
      state = TtsState.idle;
    } catch (_) {
      state = TtsState.idle;
    }
  }

  /// Toggle between speaking and stopped.
  Future<void> toggle(String text) async {
    if (state == TtsState.speaking) {
      await stop();
    } else {
      await speak(text);
    }
  }

  void _cleanup() {
    _tts?.stop();
    _tts = null;
  }
}
