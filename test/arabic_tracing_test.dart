import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikolumi/activities/learning.dart';
import 'package:pikolumi/activities/trace_geometry.dart';
import 'package:pikolumi/activities/tracing_maze.dart';
import 'package:pikolumi/core/models.dart';

import 'app_test.dart' show makeApp;

void main() {
  test('non-square boards preserve letter proportions in paint and touch', () {
    final viewport = TraceViewport(const Size(400, 200));
    expect(viewport.scale, 200 / 220);
    expect(viewport.origin, const Offset(100, 0));
    for (final point in [
      Offset.zero,
      const Offset(110, 110),
      const Offset(220, 220),
    ]) {
      expect(
        (viewport.logical(viewport.physical(point)) - point).distance,
        lessThan(.0001),
      );
    }
    expect(
      (viewport.physical(const Offset(100, 100)) -
              viewport.physical(const Offset(110, 100)))
          .distance,
      (viewport.physical(const Offset(100, 100)) -
              viewport.physical(const Offset(100, 110)))
          .distance,
    );
  });

  testWidgets(
    'all 80 Arabic guides can be completed with real ordered gestures',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = (await tester.runAsync(Catalog.load))!;
      final app = await makeApp(catalog);
      await app.setSound(false);
      await app.setLearningLanguage('ar');
      final activities = catalog.bySection['tracing']!.take(80);
      for (final activity in activities) {
        var completed = 0;
        Map<String, dynamic>? saved;
        final engine = EngineContext(
          activity: activity,
          app: app,
          complete: () => completed++,
          resume: null,
          save: (value) => saved = value,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TraceActivity(key: ValueKey(activity.id), engine: engine),
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
        for (final raw in engine.config['strokes'] as List) {
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
        expect(completed, 1, reason: activity.id);
        expect(saved?['traceRevision'], 3, reason: activity.id);
        expect(tester.takeException(), isNull, reason: activity.id);
      }
      await tester.pumpWidget(const SizedBox());
      await app.flush();
    },
  );

  testWidgets(
    'old Arabic checkpoints migrate and revised checkpoints restore exactly',
    (tester) async {
      final catalog = (await tester.runAsync(Catalog.load))!;
      for (final activity in catalog.bySection['tracing']!.take(80)) {
        final cfg = activity.config('ar');
        final strokes = tracePoints(cfg['strokes'] as List);
        final old = tracePoints(cfg['legacyStrokes'] as List);
        final first = TraceCheckpoint.restore(cfg, strokes, {
          'stroke': 0,
          'at': 0,
        });
        expect(first.stroke, 0);
        expect(first.at, 0);
        final raw = {'stroke': old.length ~/ 2, 'at': 1};
        final migrated = TraceCheckpoint.restore(cfg, strokes, raw);
        expect(migrated.previous?['stroke'], raw['stroke']);
        expect(migrated.previous?['at'], 1);
        expect(migrated.stroke, inInclusiveRange(0, strokes.length - 1));
        expect(
          migrated.at,
          inInclusiveRange(0, strokes[migrated.stroke].length - 1),
        );
        final restored = TraceCheckpoint.restore(cfg, strokes, {
          'stroke': migrated.stroke,
          'at': migrated.at,
          'traceRevision': 3,
          'traceMigration': migrated.previous,
        });
        expect(restored.stroke, migrated.stroke);
        expect(restored.at, migrated.at);
        final versionTwoRaw =
            (cfg['previousTraceRevisions'] as Map)['2'] as List;
        final versionTwo = tracePoints(versionTwoRaw);
        final checkpointTwo = TraceCheckpoint.restore(cfg, strokes, {
          'stroke': 0,
          'at': 7,
          'traceRevision': 2,
        });
        expect(checkpointTwo.stroke, inInclusiveRange(0, strokes.length - 1));
        expect(
          checkpointTwo.at,
          inInclusiveRange(0, strokes[checkpointTwo.stroke].length - 1),
        );
        final unchanged =
            versionTwo.length == strokes.length &&
            List.generate(
              strokes.length,
              (i) =>
                  versionTwo[i].length == strokes[i].length &&
                  List.generate(
                    strokes[i].length,
                    (j) => versionTwo[i][j] == strokes[i][j],
                  ).every((equal) => equal),
            ).every((equal) => equal);
        if (unchanged) {
          expect(checkpointTwo.stroke, 0);
          expect(checkpointTwo.at, 7);
        } else {
          expect(checkpointTwo.previous?['fromRevision'], 2);
        }
      }
    },
  );
}
