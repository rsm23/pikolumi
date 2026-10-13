import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/activities/learning.dart';
import 'package:pikolumi/activities/tracing_maze.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/services/store_native.dart';
import 'package:pikolumi/main.dart' as production;
import 'package:pikolumi/ui/library.dart';

import '../test/app_test.dart' show SilentAudio;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Arabic forms, vowel choices, connected tracing and native recovery stay silent',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp(
        'pikolumi-ar-qa-',
      );
      final store = NativeRecordStore(
        NativeDatabase(File('${directory.path}/qa.sqlite')),
      );
      final app = AppController(
        catalog: await Catalog.load(),
        store: store,
        audio: SilentAudio(),
      );
      await app.initialize();
      await app.setSound(false);
      final ads = AdsService(store, app.audio);
      runApp(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => app)],
          child: production.PikolumiApp(ads: ads),
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await app.flush();
        ads.dispose();
        await store.close();
        await directory.delete(recursive: true);
      });
      await tester.pumpAndSettle();
      final originalLanguage = app.language;
      final originalLearningLanguage = app.active.learningLanguage;
      await app.setSound(false);
      await ads.synchronizeSound();
      ads.enterActivity();
      await app.setLanguage('en');
      await app.setLearningLanguage('ar');
      await tester.pumpAndSettle();
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
      }
      final navigator = Navigator.of(tester.element(find.byType(LibraryHome)));
      var completions = 0;
      Future<void> mount(Widget child) async {
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Pikolumi')),
                body: SafeArea(child: child),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> close() async {
        navigator.pop();
        await tester.pumpAndSettle();
      }

      try {
        for (final index in [29, 56, 78, 79, 118]) {
          final activity = app.catalog.bySection['letters']![index];
          final engine = EngineContext(
            activity: activity,
            app: app,
            complete: () => completions++,
            resume: null,
            save: (_) {},
          );
          await mount(QuizActivity(engine: engine));
          await binding.takeScreenshot('en-ui-ar-learn-${activity.id}');
          final correct = find.byKey(
            ValueKey('option-${engine.config['correct']}'),
          );
          await tester.ensureVisible(correct);
          await tester.tap(correct);
          await tester.pumpAndSettle();
          expect(completions, 1);
          completions = 0;
          await close();
        }
        for (final index in [55, 57, 65, 79]) {
          final activity = app.catalog.bySection['tracing']![index];
          final resumeId = 'qa-arabic-${activity.id}';
          final engine = EngineContext(
            activity: activity,
            app: app,
            complete: () => completions++,
            resume: null,
            save: (value) => unawaited(app.saveResume(resumeId, value)),
          );
          await mount(TraceActivity(engine: engine));
          await binding.takeScreenshot('en-ui-ar-learn-${activity.id}');
          Future<void> trace(List<dynamic> points) async {
            final area = tester.getRect(
              find.byKey(const ValueKey('trace-canvas')),
            );
            Offset physical(List<dynamic> p) =>
                area.topLeft +
                Offset(
                  (p[0] as num).toDouble() / 220 * area.width,
                  (p[1] as num).toDouble() / 220 * area.height,
                );
            final gesture = await tester.startGesture(physical(points.first));
            for (var i = 0; i < points.length - 1; i++) {
              final from = physical(points[i]), to = physical(points[i + 1]);
              final count = math.max(1, ((to - from).distance / 3).ceil());
              for (var j = 1; j <= count; j++) {
                await gesture.moveTo(Offset.lerp(from, to, j / count)!);
                await tester.pump(const Duration(milliseconds: 1));
              }
            }
            await gesture.up();
            await tester.pump();
          }

          final paths = engine.config['strokes'] as List;
          await trace(paths.first);
          await app.flush();
          final saved = await app.resume(resumeId);
          expect(saved, isNotNull);
          await close();
          await mount(
            TraceActivity(
              engine: EngineContext(
                activity: activity,
                app: app,
                complete: () => completions++,
                resume: saved,
                save: (value) => unawaited(app.saveResume(resumeId, value)),
              ),
            ),
          );
          for (final path in paths.skip(1)) {
            await trace(path);
          }
          expect(completions, 1, reason: activity.id);
          completions = 0;
          await close();
          await app.flush();
          await app.clearResume(resumeId);
        }
        await app.setLanguage('ar');
        await app.setLearningLanguage('es');
        final vocabulary = app.catalog.bySection['words']!.first;
        final wordEngine = EngineContext(
          activity: vocabulary,
          app: app,
          complete: () => completions++,
          resume: null,
          save: (_) {},
        );
        await mount(QuizActivity(engine: wordEngine));
        await binding.takeScreenshot('ar-ui-es-learn-vocabulary');
        expect(find.text('cat'), findsNothing);
        expect(find.text('قطة'), findsNothing);
        expect(find.text('gato'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('option-cat')));
        await tester.pumpAndSettle();
        expect(completions, 1);
        await close();
        expect(tester.takeException(), isNull);
        expect(app.sound, isFalse);
        expect(app.audio.enabled, isFalse);
        binding.reportData = {
          ...?binding.reportData,
          'arabicChoiceActivities': 5,
          'tracesCompleted': 4,
          'nativeResumeRecovery': true,
          'soundEnabled': false,
          'store': 'isolated temporary SQLite; user preferences and artwork untouched',
          'catalogVersion': app.catalog.version,
          'mixedLanguagePairs': [
            'en interface/ar learning',
            'ar interface/es learning',
          ],
          'educatorApproval': false,
          'pronunciationApproval': false,
        };
      } finally {
        await app.setLearningLanguage(originalLearningLanguage);
        await app.setLanguage(originalLanguage);
        ads.leaveActivity();
        await app.flush();
      }
    },
  );
}
