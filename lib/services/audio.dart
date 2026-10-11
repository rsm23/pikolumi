import 'package:audioplayers/audioplayers.dart';

class AudioService {
  AudioPlayer? _voice, _notes;
  AudioPlayer get voice => _voice ??= AudioPlayer();
  AudioPlayer get notes => _notes ??= AudioPlayer();
  bool active = true;
  bool enabled = true;
  int _generation = 0;
  Future<void> play(String language, String file) async {
    if (!enabled || !active) return;
    try {
      await voice.stop();
      await voice.play(AssetSource('audio/$language/$file'));
    } catch (_) {
      /* Missing narration never stops an activity. */
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
