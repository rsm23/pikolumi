import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pikolumi/activities/tracing_maze.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/services/audio.dart';
import 'package:pikolumi/ui/activity_screen.dart';

import '../test/app_test.dart' show MemoryStore;

class TracePlayback {
  final String language;
  final List<String> files;
  final started = <String>[];
  final completed = <String>[];
  late final Future<void> done;
  TracePlayback(this.language, this.files);
}

class NativeTraceAudio extends AudioService {
  TracePlayback? lastPlayback;

  String get sourcePath {
    final source = voice.source;
    return source is AssetSource ? source.path : '';
  }

  @override
  Future<void> playSequence(String language, List<String> files) {
    final playback = TracePlayback(language, List.of(files));
    lastPlayback = playback;
    return playback.done = _observe(playback);
  }

  Future<void> _observe(TracePlayback playback) async {
    final states = voice.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) playback.started.add(sourcePath);
    });
    final completions = voice.onPlayerComplete.listen((_) {
      // ReleaseMode.release clears source before notifying later listeners.
      playback.completed.add(playback.started.last);
    });
    try {
      await super.playSequence(playback.language, playback.files);
    } finally {
      await states.cancel();
      await completions.cancel();
    }
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'all tracing languages decode and finish native playback silently',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Silent tracing audio check')),
        ),
      );
      final catalog = await Catalog.load();
      final audio = NativeTraceAudio();
      await audio.voice.setVolume(0);
      final app = AppController(
        catalog: catalog,
        store: MemoryStore(),
        audio: audio,
      );
      await app.initialize();
      final ads = AdsService(app.store, audio);
      final container = ProviderContainer(
        overrides: [appProvider.overrideWith((ref) => app)],
      );
      addTearDown(() async {
        await audio.stop();
        ads.dispose();
        container.dispose();
      });
      const languages = ['en', 'fr', 'es', 'pt', 'ar'];
      final decoded = <String, Map<String, int>>{};
      for (final language in languages) {
        final decoder = AudioService();
        await decoder.voice.setVolume(0);
        final files = {
          for (final activity in catalog.bySection['tracing']!)
            ...activity.traceCues(language),
        };
        final durations = <String, int>{};
        try {
          for (final file in files) {
            await decoder.voice.stop();
            try {
              await decoder.voice.setSourceAsset('audio/$language/$file');
            } catch (error) {
              throw StateError(
                'Native preparation failed for $language/$file: $error',
              );
            }
            final duration =
                (await decoder.voice.getDuration())?.inMilliseconds;
            expect(
              duration,
              greaterThan(0),
              reason: '$language/$file native decode',
            );
            expect(decoder.voice.volume, 0);
            durations[file] = duration!;
          }
        } finally {
          await decoder.dispose();
        }
        decoded[language] = durations;
        debugPrint('TRACE_AUDIO_DECODED $language ${durations.length} clips');
      }
      await audio.stop();
      final results = <Map<String, Object>>[];
      for (var i = 0; i < languages.length; i++) {
        final learning = languages[i];
        final ui = languages[(i + 1) % languages.length];
        await app.setLanguage(ui);
        await app.setLearningLanguage(learning);
        for (final index in [0, 28, 56]) {
          final activity = catalog.bySection['tracing']![index];
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: child!,
                ),
                home: ActivityScreen(activity: activity, ads: ads),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.byType(TraceActivity), findsOneWidget);
          final entry = audio.lastPlayback!;
          await entry.done.timeout(const Duration(seconds: 30));
          final expected = activity
              .traceCues(learning)
              .map((file) => 'audio/$learning/$file')
              .toList();
          expect(
            entry.started,
            expected,
            reason: '$learning ${activity.id} entry start',
          );
          expect(
            entry.completed,
            expected,
            reason: '$learning ${activity.id} entry end',
          );
          tester
              .widget<TraceActivity>(find.byType(TraceActivity))
              .engine
              .complete();
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.byType(AlertDialog), findsOneWidget);
          final end = audio.lastPlayback!;
          expect(end, isNot(same(entry)));
          await end.done.timeout(const Duration(seconds: 30));
          expect(
            end.started,
            expected,
            reason: '$learning ${activity.id} completion start',
          );
          expect(
            end.completed,
            expected,
            reason: '$learning ${activity.id} completion end',
          );
          expect(audio.voice.volume, 0);
          expect(audio.voice.state, PlayerState.completed);
          results.add({
            'activity': activity.id,
            'interface': ui,
            'learning': learning,
            'files': entry.files,
            'nativeStartsAtEntry': entry.started.length,
            'nativeCompletionsAtEntry': entry.completed.length,
            'nativeStartsAtCompletion': end.started.length,
            'nativeCompletionsAtCompletion': end.completed.length,
          });
          debugPrint('TRACE_AUDIO_CASE ${jsonEncode(results.last)}');
          await tester.pumpWidget(const SizedBox());
          await app.flush();
        }
      }
      final report = {
        'passed': true,
        'checkedAtUTC': DateTime.now().toUtc().toIso8601String(),
        'platform': Platform.operatingSystem,
        'languages': languages,
        'decodedTracingClips': decoded,
        'entryAndCompletionCases': results,
        'nativePlayerVolume': 0,
        'systemVolumeChanged': false,
        'persistentStore': 'isolated memory; no user database opened',
        'adSDKInitialized': false,
        'scope': 'Native codec checks for every tracing narration asset; real start/completion events for 15 representative models at entry and completion. Gestures and all 25 language pairs are covered separately by widget tests.',
      };
      binding.reportData = report;
      final directory = await getTemporaryDirectory();
      await File('${directory.path}/tracing-audio-qa.json')
          .writeAsString(jsonEncode(report));
      debugPrint(
        'TRACE_AUDIO_NATIVE_PASS ${results.length} cases in ${languages.length} languages',
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
