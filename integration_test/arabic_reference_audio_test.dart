import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/services/audio.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('authorized Arabic reference decodes natively without playback', (
    tester,
  ) async {
    final audio = AudioService()
      ..enabled = false
      ..active = false;
    addTearDown(audio.dispose);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Silent audio check'))),
    );
    const expectedSha =
        '62c636f483a3fe0f9a091a15cb8ed67f19c9774f6aa203117a8101ea25df90be';
    final clip = await rootBundle.load('assets/audio/ar/syllable_37.mp3');
    final actualSha = sha256.convert(clip.buffer.asUint8List()).toString();
    expect(actualSha, expectedSha);
    await audio.voice.setVolume(0);
    await audio.voice.setSourceAsset('audio/ar/syllable_37.mp3');
    final duration = await audio.voice.getDuration();
    expect(duration?.inMilliseconds, greaterThan(0));
    expect(audio.voice.state, isNot(PlayerState.playing));
    expect(audio.enabled, isFalse);
    expect(audio.active, isFalse);
    await audio.stop();
    binding.reportData = {
      'platform': Platform.operatingSystem,
      'arabicReferenceClipSha256': actualSha,
      'nativeDurationMs': duration!.inMilliseconds,
      'playback': false,
      'playerVolume': 0,
      'adsRequested': false,
      'appPersistenceOpened': false,
      'scope': 'Native codec preparation on Simulator; not pronunciation or physical-device acceptance.',
    };
  });
}
