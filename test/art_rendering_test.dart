import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikolumi/ui/vector_art.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/activities/canvas_activity.dart';
import 'package:pikolumi/activities/learning.dart';

import 'app_test.dart' show makeApp;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('opening a Drawing Studio picture shows a visible subject', (
    tester,
  ) async {
    final catalog = (await tester.runAsync(Catalog.load))!;
    final app = await makeApp(catalog);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanvasActivity(
            activity: catalog.byId['drawing-0002']!,
            app: app,
            onComplete: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(const ValueKey('art-canvas')),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as VectorPainter;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
    painter.drawScene(canvas, const Size(200, 200));
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(200, 200));
    final bytes = (await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    var visiblePixels = 0;
    for (var i = 0; i < bytes.lengthInBytes; i += 4) {
      if (bytes.getUint8(i) < 245 ||
          bytes.getUint8(i + 1) < 245 ||
          bytes.getUint8(i + 2) < 245) {
        visiblePixels++;
      }
    }
    expect(
      visiblePixels,
      greaterThan(100),
      reason: 'A selected drawing must show its guide, not only a white background.',
    );
    image!.dispose();
    picture.dispose();
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
  test('foreground regions hide the outlines of shapes behind them', () async {
    final scene = VectorScene.fromJson({
      'width': 100,
      'height': 100,
      'shapes': [
        {
          'id': 'back',
          'kind': 'ellipse',
          'v': [20, 20, 60, 60],
          'color': '74BEC6',
        },
        {
          'id': 'front',
          'kind': 'rect',
          'v': [70, 0, 30, 100, 0],
          'color': 'F3C65F',
        },
      ],
    });
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    VectorPainter(scene: scene).drawScene(canvas, const Size(100, 100));
    final picture = recorder.endRecording();
    final image = await picture.toImage(100, 100);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final at = (50 * 100 + 80) * 4;
    expect(
      [bytes.getUint8(at), bytes.getUint8(at + 1), bytes.getUint8(at + 2)],
      [0xF3, 0xC6, 0x5F],
      reason: 'A hidden body/ear boundary must not cross a foreground face.',
    );
    image.dispose();
    picture.dispose();
  });
  test('scene caches separate current and saved artwork geometry', () {
    Map<String, dynamic> art(String color) => {
      'same-id': {
        'width': 100,
        'height': 100,
        'shapes': [
          {
            'kind': 'rect',
            'v': [0, 0, 100, 100, 0],
            'color': color,
          },
        ],
      },
    };
    expect(
      sceneFor(art('F3C65F'), 'same-id')!.shapes.first.color,
      const Color(0xFFF3C65F),
    );
    expect(
      sceneFor(art('74BEC6'), 'same-id')!.shapes.first.color,
      const Color(0xFF74BEC6),
    );
  });
  testWidgets(
    'redesigned pages preserve existing artwork geometry and colors',
    (tester) async {
      final catalog = (await tester.runAsync(Catalog.load))!;
      final app = await makeApp(catalog);
      const savedColor = 0xFFF17C6E;
      await app.saveArtwork('coloring-0001', {
        'fills': {'r3': savedColor},
        'strokes': [],
      }, scene: 'scene_0_0');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasActivity(
              activity: catalog.byId['coloring-0001']!,
              app: app,
              onComplete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final previous = tester.state<CanvasActivityState>(
        find.byType(CanvasActivity),
      );
      expect(previous.scene, same(sceneFor(catalog.legacyArt, 'scene_0_0')));
      expect(previous.drawing['fills']['r3'], savedColor);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasActivity(
              activity: catalog.byId['coloring-0002']!,
              app: app,
              onComplete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fresh = tester.state<CanvasActivityState>(
        find.byType(CanvasActivity),
      );
      expect(fresh.scene, same(sceneFor(catalog.art, 'scene_0_1')));
      expect(fresh.drawing['artRevision'], 3);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
  testWidgets(
    'puzzle picture pieces keep their spatial order in an Arabic interface',
    (tester) async {
      final catalog = (await tester.runAsync(Catalog.load))!;
      final app = await makeApp(catalog);
      await app.setLanguage('ar');
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: JigsawActivity(
                engine: EngineContext(
                  activity: catalog.bySection['jigsaw']!.first,
                  app: app,
                  complete: () {},
                  resume: null,
                  save: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('jigsaw-0'))).dx,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('jigsaw-1'))).dx),
      );
      final board = tester.getRect(find.byType(GridView));
      final screen = tester.getRect(find.byType(Scaffold));
      expect(board.center.dx, closeTo(screen.center.dx, 1));
      final reference = tester.getRect(find.byType(ArtThumbnail));
      expect(reference.left, greaterThan(screen.left));
      expect(reference.right, lessThan(screen.right));
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
}
