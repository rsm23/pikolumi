import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/activities/canvas_activity.dart';
import 'package:pikolumi/activities/learning.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/main.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/ui/activity_screen.dart';
import 'package:pikolumi/ui/piko_mascot.dart';

import '../test/app_test.dart' show MemoryStore, SilentAudio;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    '3D mascot animates silently and celebrates actual activity completion',
    (tester) async {
      final app = AppController(
        catalog: await Catalog.load(),
        store: MemoryStore(),
        audio: SilentAudio(),
      );
      await app.initialize();
      await app.setSound(false);
      final ads = AdsService(app.store, app.audio);
      final container = ProviderContainer(
        overrides: [appProvider.overrideWith((ref) => app)],
      );
      final timings = <FrameTiming>[];
      void record(List<FrameTiming> values) => timings.addAll(values);
      SchedulerBinding.instance.addTimingsCallback(record);
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
      await binding.takeScreenshot('library-3d-piko');
      final locales = <String>[];
      for (final locale in ['en', 'fr', 'es', 'pt', 'ar']) {
        await app.setLanguage(locale);
        await app.setLearningLanguage(locale == 'ar' ? 'en' : 'ar');
        await tester.pumpAndSettle();
        final activity = app.catalog.bySection['counting']!.first;
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityScreen(activity: activity, ads: ads),
          ),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          final paint = find.descendant(
            of: find.byKey(const ValueKey('activity-piko')),
            matching: find.byType(CustomPaint),
          );
          if (paint.evaluate().isNotEmpty &&
              tester.widget<CustomPaint>(paint).painter is PikoFramePainter) {
            break;
          }
        }
        final header = find.byKey(const ValueKey('activity-piko'));
        PikoFramePainter painter() =>
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: header,
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as PikoFramePainter;
        final first = painter().frame;
        await tester.pump(const Duration(milliseconds: 400));
        expect(painter().frame, greaterThan(first));
        expect(tester.getSize(header), const Size(56, 56));
        expect(find.byTooltip(app.t('listen')), findsOneWidget);
        await tester.pumpAndSettle();
        await binding.takeScreenshot('$locale-activity-3d-piko');
        final quiz = tester.widget<QuizActivity>(find.byType(QuizActivity));
        final correct = quiz.engine.config['correct'] as String;
        // Use the real answer button so persistence and the shell callback both run.
        final correctButton = find.byKey(ValueKey('option-$correct'));
        await tester.ensureVisible(correctButton);
        await tester.tap(correctButton);
        for (
          var i = 0;
          i < 40 && find.byType(AlertDialog).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.byType(AlertDialog), findsOneWidget);
        final celebration = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(PikoMascot),
        );
        expect(tester.widget<PikoMascot>(celebration).pose, PikoPose.celebrate);
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (find
              .descendant(of: celebration, matching: find.byType(CustomPaint))
              .evaluate()
              .isNotEmpty) {
            break;
          }
        }
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();
        await binding.takeScreenshot('$locale-completion-3d-piko');
        expect(app.isCompleted(activity), isTrue);
        expect(app.sound, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        await tester.tap(find.text(app.t('continue')));
        await tester.pumpAndSettle();
        locales.add(locale);
      }
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      final drawing = app.catalog.bySection['drawing']!.first;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ActivityScreen(activity: drawing, ads: ads),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .state<CanvasActivityState>(find.byType(CanvasActivity))
          .setFullScreen(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity-piko')), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      tester
          .state<CanvasActivityState>(find.byType(CanvasActivity))
          .setFullScreen(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity-piko')), findsOneWidget);
      await app.setMotion(true);
      await tester.pumpAndSettle();
      final headerPaint = find.descendant(
        of: find.byKey(const ValueKey('activity-piko')),
        matching: find.byType(CustomPaint),
      );
      expect(headerPaint, findsNothing);
      await binding.takeScreenshot('reduced-motion-static-piko');
      SchedulerBinding.instance.removeTimingsCallback(record);
      final raster =
          timings.map((t) => t.rasterDuration.inMicroseconds / 1000).toList()
            ..sort();
      final build =
          timings.map((t) => t.buildDuration.inMicroseconds / 1000).toList()
            ..sort();
      binding.reportData = {
        ...?binding.reportData,
        'locales': locales,
        'animations': ['idle', 'celebrate'],
        'renderer': 'Blender-rendered 3D, shared WebP atlases, 30 fps poses',
        'animatedFrameAdvanceVerified': true,
        'completionAndProgressVerified': true,
        'canvasFullScreenPreserved': true,
        'reducedMotionVerified': true,
        'adSDKInitialized': false,
        'audio': 'SilentAudio; muted isolated MemoryStore',
        'userPreferencesChanged': false,
        'frameTimings': {
          'samples': raster.length,
          'rasterP95Ms': raster.isEmpty
              ? null
              : raster[(raster.length * .95).floor().clamp(
                  0,
                  raster.length - 1,
                )],
          'buildP95Ms': build.isEmpty
              ? null
              : build[(build.length * .95).floor().clamp(0, build.length - 1)],
        },
      };
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      ads.dispose();
      container.dispose();
    },
  );
}
