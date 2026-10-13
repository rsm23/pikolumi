import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/services/audio.dart';
import 'package:pikolumi/ui/activity_screen.dart';

import '../test/app_test.dart' show MemoryStore;

class NativeAudioProbe extends AudioService {
  Future<void>? requestedPlayback;
  Map<String, Object?>? decodedPlayback;
  @override
  Future<void> play(String language, String file) =>
      requestedPlayback = _decode(language, file);

  Future<void> _decode(String language, String file) async {
    await super.play(language, file);
    final source = voice.source;
    decodedPlayback = {
      'source': source is AssetSource ? source.path : null,
      'durationMs': (await voice.getDuration())?.inMilliseconds,
      'state': voice.state.name,
      'enabled': enabled,
      'active': active,
    };
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real native Listen decoding remains silent and obeys mute', (
    tester,
  ) async {
    final audio = NativeAudioProbe();
    await audio.voice.setVolume(0);
    await audio.notes.setVolume(0);
    final app = AppController(
      catalog: await Catalog.load(),
      store: MemoryStore(),
      audio: audio,
    );
    await app.initialize();
    final ads = AdsService(app.store, audio);
    final container = ProviderContainer(
      overrides: [appProvider.overrideWith((ref) => app)],
    );
    final decoded = <Map<String, Object>>[];
    final locales = ['en', 'fr', 'es', 'pt', 'ar'];
    var surfaceConverted = false;
    for (var i = 0; i < locales.length; i++) {
      final locale = locales[i];
      await app.setLanguage(locale);
      await app.setLearningLanguage(locales[(i + 1) % locales.length]);
      for (final section in ['counting', 'letters', 'words']) {
        final activity = app.catalog.bySection[section]!.first;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: ActivityScreen(activity: activity, ads: ads),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (Platform.isAndroid && !surfaceConverted) {
          await binding.convertFlutterSurfaceToImage();
          surfaceConverted = true;
        }
        await audio.stop();
        audio.requestedPlayback = null;
        audio.decodedPlayback = null;
        await tester.tap(find.byTooltip(app.t('listen')));
        expect(audio.requestedPlayback, isNotNull);
        await audio.requestedPlayback;
        await tester.pumpAndSettle();
        final language = app.activityLanguage(activity);
        final cue = activity.cue(language);
        final file = cue ?? activity.audio;
        final spokenLanguage = cue == null ? app.language : language;
        final playback = audio.decodedPlayback!;
        expect(
          playback['source'],
          'audio/$spokenLanguage/$file',
          reason: '$locale/$section: $playback',
        );
        expect(playback['durationMs'], greaterThan(0));
        expect(playback['state'], anyOf('playing', 'completed'));
        expect(audio.voice.volume, 0);
        decoded.add({
          'section': section,
          'interface': locale,
          'spokenLanguage': spokenLanguage,
          'file': file,
          'durationMs': playback['durationMs'] as int,
        });
        await audio.stop();
        await app.setSound(false);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(app.t('listen')));
        await tester.pumpAndSettle();
        expect(find.text(app.t('soundOffHelp')), findsOneWidget);
        expect(audio.voice.state, isNot(PlayerState.playing));
        if (section == 'letters' && (locale == 'en' || locale == 'ar')) {
          await binding.takeScreenshot('$locale-muted-listen-feedback');
        }
        await tester.pumpWidget(const SizedBox());
        await app.flush();
        await app.setSound(true);
      }
    }
    binding.reportData = {
      ...?binding.reportData,
      'decodedListenRequests': decoded,
      'requests': decoded.length,
      'playerVolume': 0,
      'systemVolumeChanged': false,
      'mixedInterfaceAndLearningLanguages': true,
      'mutedFeedbackVerified': true,
      'userPreferencesChanged': false,
      'store': 'isolated memory',
      'adSDKInitialized': false,
    };
    ads.dispose();
    container.dispose();
  });
}
