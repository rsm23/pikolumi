import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

class AudioService {
  AudioPlayer? _voice, _notes;
  AudioPlayer get voice => _voice ??= AudioPlayer();
  AudioPlayer get notes => _notes ??= AudioPlayer();
  bool active = true;
  bool enabled = true;
  int _generation = 0;
  int _voiceGeneration = 0;
  Completer<void>? _voiceFinished;

  int _cancelVoiceSequence() {
    final waiting = _voiceFinished;
    _voiceFinished = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
    return ++_voiceGeneration;
  }

  Future<void> play(String language, String file) async {
    final generation = _cancelVoiceSequence();
    await _playVoice(language, file, generation);
  }

  Future<void> playSequence(String language, List<String> files) async {
    final generation = _cancelVoiceSequence();
    for (final file in files) {
      if (generation != _voiceGeneration || !enabled || !active) return;
      await _playVoice(language, file, generation, waitForEnd: true);
    }
  }

  Future<void> _playVoice(
    String language,
    String file,
    int generation, {
    bool waitForEnd = false,
  }) async {
    if (!enabled || !active) return;
    StreamSubscription<void>? subscription;
    Completer<void>? finished;
    try {
      await voice.stop();
      if (generation != _voiceGeneration || !enabled || !active) return;
      if (waitForEnd) {
        final completion = Completer<void>();
        finished = completion;
        _voiceFinished = completion;
        void finish() {
          if (!completion.isCompleted) completion.complete();
        }

        subscription = voice.onPlayerComplete.listen(
          (_) => finish(),
          onError: (Object error, StackTrace stack) => finish(),
        );
      }
      await voice.play(AssetSource('audio/$language/$file'));
      if (finished != null) {
        await finished.future.timeout(const Duration(seconds: 20));
      }
    } catch (_) {
      /* Missing narration never stops an activity. */
    } finally {
      await subscription?.cancel();
      if (identical(_voiceFinished, finished)) _voiceFinished = null;
    }
  }

  Future<void> note(int number) async {
    if (!enabled || !active) return;
    try {
      await notes.stop();
      await notes.play(AssetSource('audio/note_$number.mp3'));
    } catch (_) {}
  }

  Future<void> melody(List<int> pattern, int tempo) async {
    final generation = ++_generation;
    for (final number in pattern) {
      if (generation != _generation || !enabled) return;
      await note(number);
      await Future<void>.delayed(Duration(milliseconds: tempo));
    }
  }

  Future<void> stop() async {
    _generation++;
    _cancelVoiceSequence();
    await Future.wait([
      if (_voice != null) _voice!.stop(),
      if (_notes != null) _notes!.stop(),
    ]);
  }

  Future<void> dispose() async {
    await stop();
    await Future.wait([
      if (_voice != null) _voice!.dispose(),
      if (_notes != null) _notes!.dispose(),
    ]);
  }
}
