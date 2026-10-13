import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/activities/trace_geometry.dart';
import 'package:pikolumi/activities/tracing_maze.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/main.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/services/store_native.dart';
import 'package:pikolumi/ui/activity_screen.dart';

import '../test/app_test.dart' show SilentAudio;
import 'capture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'actual iPad hardware rotation preserves proportions and SQLite tracing progress',
    (tester) async {
      final folder = await Directory.systemTemp.createTemp(
        'pikolumi-rotation-qa-',
      );
      final databaseFile = File('${folder.path}/rotation.sqlite');
      final catalog = await Catalog.load();
      late NativeRecordStore store;
      late AppController app;
      late AdsService ads;
      late ProviderContainer container;
      Future<void> mount() async {
        store = NativeRecordStore(
          NativeDatabase.createInBackground(databaseFile),
        );
        app = AppController(
          catalog: catalog,
          store: store,
          audio: SilentAudio(),
        );
        await app.initialize();
        await app.setSound(false);
        await app.setMotion(false);
        await app.setLanguage('en');
        ads = AdsService(store, app.audio);
        container = ProviderContainer(
          overrides: [appProvider.overrideWith((ref) => app)],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: PikolumiApp(ads: ads),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> unmount() async {
        await tester.pumpWidget(const SizedBox());
        await app.flush();
        ads.dispose();
        container.dispose();
        await store.close();
      }

      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await mount();
      final cases = [
        ('en', 14),
        ('fr', 56),
        ('es', 40),
        ('pt', 68),
        ('ar', 64),
        ('en', 119),
      ];
      final portraitRatios = <String, double>{};
      final checkpoints = <String, Map<String, dynamic>>{};
      final measures = <String, Map<String, dynamic>>{};
      final orientationSizes = <String, List<double>>{};
      final completed = <String>[];
      NavigatorState navigator() =>
          tester.state<NavigatorState>(find.byType(Navigator).first);
      TracePainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byKey(const ValueKey('trace-canvas')),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as TracePainter;
      Future<void> open(Activity activity, String language) async {
        await app.setLearningLanguage(language);
        navigator().push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityScreen(activity: activity, ads: ads),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }

      Future<void> close() async {
        navigator().pop();
        await tester.pumpAndSettle();
      }

      Future<void> trace(List<Offset> path) async {
        final area = tester.getRect(find.byKey(const ValueKey('trace-canvas')));
        final viewport = TraceViewport(area.size);
        final gesture = await tester.startGesture(
          area.topLeft + viewport.physical(path.first),
        );
        for (var i = 1; i < path.length; i++) {
          if (i % 3 != 0 && i != path.length - 1) continue;
          await gesture.moveTo(area.topLeft + viewport.physical(path[i]));
          await tester.pump(const Duration(milliseconds: 1));
        }
        await gesture.up();
        await tester.pump();
        await app.flush();
      }

      Future<void> waitForRotation(String marker, bool landscape) async {
        debugPrint('PIKO_ROTATION_READY:$marker');
        final deadline = DateTime.now().add(const Duration(seconds: 120));
        while ((tester.view.physicalSize.width >
                    tester.view.physicalSize.height) !=
                landscape &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        final size = tester.view.physicalSize;
        expect(
          size.width > size.height,
          landscape,
          reason: 'Actual simulated device must rotate at $marker',
        );
        orientationSizes[marker] = [size.width, size.height];
        expect(tester.takeException(), isNull);
      }

      Future<double> captureRatio(String name) async {
        final area = tester.getRect(find.byKey(const ValueKey('trace-canvas')));
        final actual = painter();
        final model =
            tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('trace-model')),
                    )
                    .painter!
                as TracePainter;
        expect(model.strokes, same(actual.strokes));
        expect(area.width, closeTo(area.height, .01));
        expect(area.height, greaterThan(300));
        final bytes = Uint8List.fromList(await capture(binding, name));
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        try {
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final dpr = tester.view.devicePixelRatio;
          final x0 = math.max(0, (area.left * dpr).floor()),
              x1 = math.min(image.width, (area.right * dpr).ceil());
          final y0 = math.max(0, (area.top * dpr).floor()),
              y1 = math.min(image.height, (area.bottom * dpr).ceil());
          var left = x1, right = x0, top = y1, bottom = y0, count = 0;
          for (var y = y0; y < y1; y++) {
            for (var x = x0; x < x1; x++) {
              final offset = (y * image.width + x) * 4;
              final r = pixels.getUint8(offset),
                  g = pixels.getUint8(offset + 1),
                  b = pixels.getUint8(offset + 2);
              final guide =
                  (r - 149).abs() <= 8 &&
                  (g - 134).abs() <= 8 &&
                  (b - 165).abs() <= 8;
              final ink =
                  (r - 50).abs() <= 8 &&
                  (g - 142).abs() <= 8 &&
                  (b - 157).abs() <= 8;
              if (guide || ink) {
                left = math.min(left, x);
                right = math.max(right, x);
                top = math.min(top, y);
                bottom = math.max(bottom, y);
                count++;
              }
            }
          }
          expect(count, greaterThan(300));
          final ratio = (right - left + 1) / (bottom - top + 1);
          measures[name] = {
            'renderedPixelBounds': [left, top, right, bottom],
            'widthToHeight': ratio,
            'canvasLogicalSize': [area.width, area.height],
            'stroke': actual.stroke,
            'at': actual.at,
          };
          return ratio;
        } finally {
          image.dispose();
          codec.dispose();
        }
      }

      Future<void> verifyCase(
        (String, int) item,
        String phase, {
        bool advance = false,
        bool finish = false,
      }) async {
        final language = item.$1;
        final activity = catalog.bySection['tracing']![item.$2];
        final name = '$language-${activity.id}';
        await open(activity, language);
        final prior = checkpoints[name];
        if (prior != null) {
          expect(painter().stroke, prior['stroke']);
          expect(painter().at, prior['at']);
        }
        if (phase == 'portrait') {
          final path = painter().strokes.first;
          await trace(path.take((path.length * .4).floor()).toList());
          expect(painter().stroke, 0);
          expect(painter().at, greaterThan(0));
        } else if (advance) {
          final path = painter().strokes[painter().stroke];
          final at = painter().at;
          await trace(path.sublist(at, (path.length * .7).floor()));
          expect(painter().at, greaterThan(at));
        }
        final ratio = await captureRatio('$phase-$name');
        if (phase == 'portrait') {
          portraitRatios[name] = ratio;
        } else {
          expect(
            (ratio / portraitRatios[name]! - 1).abs(),
            lessThan(.02),
            reason: 'Rendered proportions changed for $name in $phase',
          );
        }
        checkpoints[name] = Map<String, dynamic>.from(
          (await app.resume(activity.id))!,
        );
        if (finish) {
          final p = painter();
          final paths = p.strokes;
          await trace(paths[p.stroke].skip(p.at).toList());
          for (final path in paths.skip(p.stroke + 1)) {
            await trace(path);
          }
          await tester.pumpAndSettle();
          expect(app.isCompleted(activity), isTrue);
          expect(await app.resume(activity.id), isNull);
          await capture(binding, 'completed-$name');
          completed.add(name);
          await tester.tap(find.text(app.t('continue')));
          await tester.pumpAndSettle();
        } else {
          await close();
        }
        expect(tester.takeException(), isNull, reason: name);
      }

      try {
        expect(
          tester.view.physicalSize.height,
          greaterThan(tester.view.physicalSize.width),
        );
        orientationSizes['initialPortrait'] = [
          tester.view.physicalSize.width,
          tester.view.physicalSize.height,
        ];
        for (final item in cases) {
          await verifyCase(item, 'portrait');
        }
        // Keep an in-progress activity mounted during each hardware rotation.
        final active = catalog.bySection['tracing']![56];
        await open(active, 'fr');
        final before = painter();
        await waitForRotation('LEFT_LANDSCAPE', true);
        expect(painter().stroke, before.stroke);
        expect(painter().at, before.at);
        await close();
        for (final item in cases) {
          await verifyCase(item, 'landscape-left', advance: true);
        }
        await open(active, 'fr');
        final advanced = painter();
        await waitForRotation('RIGHT_PORTRAIT', false);
        expect(painter().stroke, advanced.stroke);
        expect(painter().at, advanced.at);
        await close();
        await unmount();
        await mount();
        for (final item in cases) {
          await verifyCase(item, 'portrait-reopened-sqlite');
        }
        await open(active, 'fr');
        final recovered = painter();
        await waitForRotation('RIGHT_LANDSCAPE', true);
        expect(painter().stroke, recovered.stroke);
        expect(painter().at, recovered.at);
        await close();
        for (final item in cases) {
          await verifyCase(item, 'landscape-right', finish: true);
        }
        await waitForRotation('LEFT_PORTRAIT', false);
        for (final item in cases) {
          await app.setLearningLanguage(item.$1);
          expect(
            app.isCompleted(catalog.bySection['tracing']![item.$2]),
            isTrue,
          );
        }
        expect(app.sound, isFalse);
        binding.reportData = {
          ...?binding.reportData,
          'orientationSizes': orientationSizes,
          'renderedMeasurements': measures,
          'preservedCheckpoints': checkpoints,
          'completedInLandscape': completed,
          'actualHardwareQuarterTurns': 4,
          'allFiveLanguages': true,
          'letterProportionMaxRelativeDrift': .02,
          'sqliteClosedAndReopened': true,
          'normalPreferencesChanged': false,
          'audio': 'SilentAudio; sound off before mounting; isolated temporary SQLite database',
          'storeActionsPerformed': false,
        };
      } finally {
        await unmount();
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        await folder.delete(recursive: true);
      }
    },
  );
}
