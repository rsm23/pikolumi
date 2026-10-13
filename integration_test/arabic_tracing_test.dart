import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/main.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/activities/trace_geometry.dart';
import 'package:pikolumi/activities/tracing_maze.dart';
import 'package:pikolumi/ui/activity_screen.dart';

import '../test/app_test.dart' show MemoryStore, SilentAudio;
import 'capture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'silent Arabic model, tracing, completion and checkpoint recovery',
    (tester) async {
      final app = AppController(
        catalog: await Catalog.load(),
        store: MemoryStore(),
        audio: SilentAudio(),
      );
      await app.initialize();
      await app.setSound(false);
      await app.setMotion(true);
      await app.setLanguage('en');
      await app.setLearningLanguage('ar');
      final ads = AdsService(app.store, app.audio);
      final container = ProviderContainer(
        overrides: [appProvider.overrideWith((ref) => app)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: PikolumiApp(ads: ads),
        ),
      );
      await tester.pumpAndSettle();
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
      }
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      Future<void> open(Activity activity) async {
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityScreen(activity: activity, ads: ads),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }

      TracePainter boardPainter() =>
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byKey(const ValueKey('trace-canvas')),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as TracePainter;
      Future<void> trace(List<Offset> path) async {
        final area = tester.getRect(find.byKey(const ValueKey('trace-canvas')));
        final viewport = TraceViewport(area.size);
        final gesture = await tester.startGesture(
          area.topLeft + viewport.physical(path.first),
        );
        for (final point in path.skip(1)) {
          await gesture.moveTo(area.topLeft + viewport.physical(point));
          await tester.pump(const Duration(milliseconds: 1));
        }
        await gesture.up();
        await tester.pump();
      }

      final captured = <String>[], completed = <String>[];
      for (final index in [4, 5, 6, 15, 16, 25, 32, 33, 64, 74, 75]) {
        final activity = app.catalog.bySection['tracing']![index];
        await open(activity);
        final actual = boardPainter();
        final model =
            tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('trace-model')),
                    )
                    .painter!
                as TracePainter;
        expect(model.strokes, same(actual.strokes));
        expect(model.preview, isTrue);
        await capture(binding, 'en-ui-ar-${activity.id}');
        captured.add(activity.id);
        if (index == 4 || index == 15 || index == 64) {
          final paths = tracePoints(activity.config('ar')['strokes'] as List);
          if (index == 4) {
            await trace(paths.first.take(paths.first.length ~/ 2).toList());
            await app.flush();
            final saved = (await app.resume(activity.id))!;
            final oldPainter = boardPainter();
            expect(saved['traceRevision'], 3);
            navigator.pop();
            await tester.pumpAndSettle();
            await open(activity);
            expect(boardPainter().stroke, oldPainter.stroke);
            expect(boardPainter().at, oldPainter.at);
            await capture(binding, 'resumed-${activity.id}');
            final p = boardPainter();
            await trace(paths[p.stroke].skip(p.at).toList());
            for (final path in paths.skip(p.stroke + 1)) {
              await trace(path);
            }
          } else {
            for (final path in paths) {
              await trace(path);
            }
          }
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(app.isCompleted(activity), isTrue);
          await capture(binding, 'completed-${activity.id}');
          completed.add(activity.id);
          await tester.tap(find.text(app.t('continue')));
          await tester.pumpAndSettle();
        } else {
          navigator.pop();
          await tester.pumpAndSettle();
        }
      }
      final alif = app.catalog.bySection['tracing']!.first;
      await app.saveResume(alif.id, {'stroke': 0, 'at': 7});
      await app.flush();
      final cfg = alif.config('ar');
      final expected = TraceCheckpoint.restore(
        cfg,
        tracePoints(cfg['strokes'] as List),
        {'stroke': 0, 'at': 7},
      );
      await open(alif);
      expect(boardPainter().stroke, expected.stroke);
      expect(boardPainter().at, expected.at);
      await capture(binding, 'legacy-checkpoint-${alif.id}');
      navigator.pop();
      await tester.pumpAndSettle();
      final longAlif = app.catalog.bySection['tracing']![55];
      await open(longAlif);
      for (final path in tracePoints(
        longAlif.config('ar')['strokes'] as List,
      )) {
        await trace(path);
      }
      await tester.pumpAndSettle();
      expect(app.isCompleted(longAlif), isTrue);
      await capture(binding, 'completed-${longAlif.id}');
      completed.add(longAlif.id);
      await tester.tap(find.text(app.t('continue')));
      await tester.pumpAndSettle();
      expect(app.sound, isFalse);
      expect(tester.takeException(), isNull);
      binding.reportData = {
        ...?binding.reportData,
        'capturedArabicGuides': captured,
        'completedArabicGuides': completed,
        'modelMatchesPracticeGeometry': true,
        'newCheckpointRestoredExactly': true,
        'legacyCheckpointMigrated': true,
        'interfaceLanguage': 'en',
        'learningLanguage': 'ar',
        'userPreferencesChanged': false,
        'adSDKInitialized': false,
        'audio': 'SilentAudio, muted before mounting; in-memory preferences',
      };
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      ads.dispose();
      container.dispose();
    },
  );
}
