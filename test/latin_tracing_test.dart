import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikolumi/activities/learning.dart';
import 'package:pikolumi/activities/trace_geometry.dart';
import 'package:pikolumi/activities/tracing_maze.dart';
import 'package:pikolumi/core/models.dart';

import 'app_test.dart' show makeApp;

void main() {
  testWidgets(
    'landscape retains a usable canvas and the current pen position',
    (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = (await tester.runAsync(Catalog.load))!;
      final app = await makeApp(catalog);
      await app.setSound(false);
      await app.setLearningLanguage('fr');
      final activity = catalog.bySection['tracing']![26];
      final engine = EngineContext(
        activity: activity,
        app: app,
        complete: () {},
        resume: {'stroke': 0, 'at': 12, 'traceRevision': 2},
        save: (_) {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 200,
              child: TraceActivity(engine: engine),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final canvas = tester.getRect(find.byKey(const ValueKey('trace-canvas')));
      expect(canvas.height, greaterThanOrEqualTo(160));
      expect(canvas.width, canvas.height);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byKey(const ValueKey('trace-canvas')),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as TracePainter;
      expect(painter.at, 12);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await app.flush();
    },
  );
  testWidgets(
    'all 320 Latin guides and 40 numbers match and accept ordered gestures',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final catalog = (await tester.runAsync(Catalog.load))!;
      final app = await makeApp(catalog);
      await app.setSound(false);
      await app.setLanguage('ar');
      final activities = catalog.bySection['tracing']!;
      for (final lang in ['en', 'fr', 'es', 'pt']) {
        await app.setLearningLanguage(lang);
        for (final activity in activities.take(lang == 'en' ? 120 : 80)) {
          var completed = 0;
          Map<String, dynamic>? saved;
          final engine = EngineContext(
            activity: activity,
            app: app,
            complete: () => completed++,
            resume: null,
            save: (value) => saved = value,
          );
          final cfg = engine.config;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TraceActivity(
                  key: ValueKey('$lang-${activity.id}'),
                  engine: engine,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final board = tester.getRect(
            find.byKey(const ValueKey('trace-canvas')),
          );
          final viewport = TraceViewport(board.size);
          final model =
              tester
                      .widget<CustomPaint>(
                        find.byKey(const ValueKey('trace-model')),
                      )
                      .painter!
                  as TracePainter;
          final actual =
              tester
                      .widget<CustomPaint>(
                        find.descendant(
                          of: find.byKey(const ValueKey('trace-canvas')),
                          matching: find.byType(CustomPaint),
                        ),
                      )
                      .painter!
                  as TracePainter;
          expect(model.strokes, same(actual.strokes));
          expect(model.preview, isTrue);
          expect(find.bySemanticsLabel(cfg['glyph']), findsOneWidget);
          for (final raw in cfg['strokes'] as List) {
            final path = (raw as List)
                .map(
                  (p) =>
                      board.topLeft +
                      viewport.physical(
                        Offset(
                          (p[0] as num).toDouble(),
                          (p[1] as num).toDouble(),
                        ),
                      ),
                )
                .toList();
            final gesture = await tester.startGesture(path.first);
            for (final point in path.skip(1)) {
              await gesture.moveTo(point);
              await tester.pump(const Duration(milliseconds: 1));
            }
            await gesture.up();
            await tester.pump();
          }
          expect(completed, 1, reason: '$lang ${activity.id}');
          expect(saved?['traceRevision'], 2);
          expect(
            tester.takeException(),
            isNull,
            reason: '$lang ${activity.id}',
          );
          final old = tracePoints(cfg['legacyStrokes'] as List);
          final migrated = TraceCheckpoint.restore(cfg, actual.strokes, {
            'stroke': old.length ~/ 2,
            'at': 1,
          });
          expect(migrated.previous?['fromRevision'], 1);
          final restored = TraceCheckpoint.restore(cfg, actual.strokes, {
            'stroke': migrated.stroke,
            'at': migrated.at,
            'traceRevision': 2,
          });
          expect(restored.stroke, migrated.stroke);
          expect(restored.at, migrated.at);
        }
      }
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      semantics.dispose();
    },
  );
}
