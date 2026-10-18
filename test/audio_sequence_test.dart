import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikolumi/services/audio.dart';

class ControlledPlayer implements AudioPlayer {
  final completed = StreamController<void>.broadcast();
  final played = <String>[];
  @override
  Stream<void> get onPlayerComplete => completed.stream;
  @override
  Future<void> stop() async {}
  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    played.add((source as AssetSource).path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ControlledAudio extends AudioService {
  final player = ControlledPlayer();
  @override
  AudioPlayer get voice => player;
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('each letter finishes before the next letter starts', () async {
    final audio = ControlledAudio();
    final done = audio.playSequence('fr', ['letter_0.mp3', 'letter_1.mp3']);
    await tick();
    expect(audio.player.played, ['audio/fr/letter_0.mp3']);
    audio.player.completed.add(null);
    await tick();
    expect(audio.player.played, [
      'audio/fr/letter_0.mp3',
      'audio/fr/letter_1.mp3',
    ]);
    audio.player.completed.add(null);
    await done;
    await audio.player.completed.close();
  });

  test('leaving an activity cancels pending letters without waiting for a completion event', () async {
    final audio = ControlledAudio();
    final done = audio.playSequence('en', ['letter_0.mp3', 'letter_1.mp3']);
    await tick();
    await audio.stop();
    await done;
    expect(audio.player.played, ['audio/en/letter_0.mp3']);
    await audio.player.completed.close();
  });

  test('a replay cancels the old sequence instead of overlapping it', () async {
    final audio = ControlledAudio();
    final old = audio.playSequence('en', ['letter_0.mp3', 'letter_1.mp3']);
    await tick();
    final replacement = audio.playSequence('ar', ['trace_word_0.mp3']);
    await tick();
    await old;
    expect(audio.player.played, [
      'audio/en/letter_0.mp3',
      'audio/ar/trace_word_0.mp3',
    ]);
    audio.player.completed.add(null);
    await replacement;
    await audio.player.completed.close();
  });

  test('mute and background state prevent sequence playback', () async {
    final audio = ControlledAudio()..enabled = false;
    await audio.playSequence('en', ['letter_0.mp3']);
    audio.enabled = true;
    audio.active = false;
    await audio.playSequence('en', ['letter_0.mp3']);
    expect(audio.player.played, isEmpty);
    await audio.player.completed.close();
  });
}
