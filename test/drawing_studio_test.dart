import 'dart:ui' as ui;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikolumi/activities/canvas_activity.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/ui/brush_stroke.dart';
import 'package:pikolumi/ui/vector_art.dart';
import 'package:pikolumi/ui/activity_screen.dart';
import 'package:pikolumi/services/ads.dart';

import 'app_test.dart' show makeApp;

Future<List<int>> pixels(VectorPainter painter, {int size = 200}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
  painter.drawScene(canvas, Size(size.toDouble(), size.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final result = data.buffer.asUint8List().toList();
  image.dispose();
  picture.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('confirmed reset saves only this artwork and Undo restores it', (
    tester,
  ) async {
    final catalog = (await tester.runAsync(Catalog.load))!;
    final activities = [
      catalog.byId['drawing-0002']!,
      catalog.byId['coloring-0002']!,
      Activity({
        'id': 'drawing-free',
        'section': 'drawing',
        'engine': 'canvas',
        'stage': 0,
        'title': {'en': 'Blank'},
        'instructions': {'en': 'Draw'},
        'audio': 'drawing.mp3',
        'config': {'mode': 'drawing'},
      }),
    ];
    for (final activity in activities) {
      final app = await makeApp(catalog);
      final firstProfile = app.active;
      final original = {
        'artRevision': activity.section == 'coloring' ? 2 : 3,
        'guide': 2,
        'fills': {'body': 4},
        'strokes': [
          {
            'color': 12,
            'width': 15,
            'brush': 'crayon',
            'region': null,
            'points': [
              [100, 100],
              [200, 200],
            ],
          },
        ],
      };
      await app.saveArtwork(activity.id, original);
      await app.saveArtwork('another-drawing', original);
      await app.complete(activity);
      await app.addProfile(2, 1);
      final sibling = app.active;
      await app.saveArtwork(activity.id, original);
      await app.selectProfile(firstProfile);
      var completed = 0;
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CanvasActivity(
                activity: activity,
                app: app,
                onComplete: () => completed++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tapReset() async {
        final button = find.byKey(const ValueKey('canvas-reset'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await open();
      final state = tester.state<CanvasActivityState>(
        find.byType(CanvasActivity),
      );
      final before = jsonEncode(state.drawing);
      await tapReset();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('canvas-reset-cancel')));
      await tester.pumpAndSettle();
      expect(jsonEncode(state.drawing), before);
      expect(state.undo, isEmpty);
      expect(jsonEncode(await app.artwork(activity.id)), jsonEncode(original));
      await tapReset();
      await tester.tap(find.byKey(const ValueKey('canvas-reset-confirm')));
      await tester.pumpAndSettle();
      await app.flush();
      expect(state.drawing['fills'], isEmpty);
      expect(state.drawing['strokes'], isEmpty);
      expect(state.drawing['artRevision'], original['artRevision']);
      expect(state.guide, state.initialGuide);
      expect(state.canReset, isFalse);
      expect(await app.artwork(activity.id), state.drawing);
      expect(completed, 0);
      expect(app.isCompleted(activity), isTrue);
      expect(await app.artwork('another-drawing'), original);
      final undoButton = find.byTooltip(app.t('undo'));
      await tester.ensureVisible(undoButton);
      await tester.pumpAndSettle();
      await tester.tap(undoButton);
      await tester.pumpAndSettle();
      expect(jsonEncode(state.drawing), before);
      await app.flush();
      expect(await app.artwork(activity.id), state.drawing);
      await tapReset();
      await tester.tap(find.byKey(const ValueKey('canvas-reset-confirm')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      await open();
      final reopened = tester.state<CanvasActivityState>(
        find.byType(CanvasActivity),
      );
      expect(reopened.drawing['strokes'], isEmpty);
      expect(reopened.drawing['fills'], isEmpty);
      expect(reopened.guide, reopened.initialGuide);
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      await app.selectProfile(sibling);
      expect(await app.artwork(activity.id), original);
      app.dispose();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'reset confirmation fits all five languages in full-screen on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = (await tester.runAsync(Catalog.load))!;
      for (final locale in ['en', 'fr', 'es', 'pt', 'ar']) {
        final app = await makeApp(catalog);
        await app.setLanguage(locale);
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: locale == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Scaffold(
                body: CanvasActivity(
                  activity: catalog.byId['drawing-0002']!,
                  app: app,
                  onComplete: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final state = tester.state<CanvasActivityState>(
          find.byType(CanvasActivity),
        );
        final canvasSize = tester.getSize(
          find.byKey(const ValueKey('art-canvas')),
        );
        state.start(canvasSize.center(Offset.zero), canvasSize);
        state.strokeActive = false;
        state.setFullScreen(true);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('canvas-reset')));
        await tester.pumpAndSettle();
        expect(find.text(app.t('resetDrawingTitle')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('canvas-reset-confirm')));
        await tester.pumpAndSettle();
        expect(state.drawing['strokes'], isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await app.flush();
        app.dispose();
      }
    },
  );
  testWidgets('pinch keeps a full undo history at the sixty-stroke limit', (
    tester,
  ) async {
    final catalog = (await tester.runAsync(Catalog.load))!;
    final app = await makeApp(catalog);
    final activity = Activity({
      'id': 'drawing-free',
      'section': 'drawing',
      'engine': 'canvas',
      'stage': 0,
      'title': {'en': 'Blank'},
      'instructions': {'en': 'Draw'},
      'audio': 'drawing.mp3',
      'config': {'mode': 'drawing'},
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanvasActivity(activity: activity, app: app, onComplete: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state<CanvasActivityState>(
      find.byType(CanvasActivity),
    );
    final size = tester.getSize(find.byKey(const ValueKey('art-canvas')));
    for (var i = 0; i < 65; i++) {
      state.start(Offset(size.width * .2 + i, size.height * .5), size);
    }
    state.strokeActive = false;
    final history = List.of(state.undo);
    final artwork = jsonEncode(state.drawing);
    expect(history.length, 60);
    state.scaleStart(
      ScaleStartDetails(
        localFocalPoint: size.center(Offset.zero),
        pointerCount: 1,
      ),
      size,
    );
    state.scaleUpdate(
      ScaleUpdateDetails(
        localFocalPoint: size.center(Offset.zero),
        pointerCount: 2,
        scale: 1,
      ),
      size,
    );
    expect(state.undo, history);
    expect(jsonEncode(state.drawing), artwork);
    await tester.pumpWidget(const SizedBox());
    await app.flush();
    app.dispose();
  });
  testWidgets(
    'full-screen canvas and button/pinch zoom preserve artwork across rotation and back',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = (await tester.runAsync(Catalog.load))!;
      final activities = [
        catalog.byId['drawing-0002']!,
        catalog.byId['coloring-0002']!,
        Activity({
          'id': 'drawing-free',
          'section': 'drawing',
          'engine': 'canvas',
          'stage': 0,
          'title': {'en': 'Blank'},
          'instructions': {'en': 'Draw'},
          'audio': 'drawing.mp3',
          'config': {'mode': 'drawing'},
        }),
      ];
      for (final activity in activities) {
        final app = await makeApp(catalog);
        final ads = AdsService(app.store, app.audio);
        final container = ProviderContainer(
          overrides: [appProvider.overrideWith((ref) => app)],
        );
        tester.view.physicalSize = const Size(900, 900);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: ActivityScreen(activity: activity, ads: ads),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final state = tester.state<CanvasActivityState>(
          find.byType(CanvasActivity),
        );
        if (!state.isDrawing) {
          await tester.ensureVisible(find.text(app.t('brush')));
          await tester.pumpAndSettle();
          await tester.tap(find.text(app.t('brush')));
          await tester.pumpAndSettle();
        }
        final canvas = find.byKey(const ValueKey('art-canvas'));
        final originalSize = tester.getSize(canvas);
        final normal = tester.getRect(canvas);
        if (state.isDrawing) {
          await tester.dragFrom(
            normal.center - const Offset(40, 0),
            const Offset(80, 20),
          );
          await tester.pumpAndSettle();
          await tester.dragFrom(normal.center, const Offset(60, -20));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byTooltip(app.t('undo')));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(app.t('undo')));
          await tester.pumpAndSettle();
        }
        final original = jsonEncode(state.drawing);
        final redoBefore = List.of(state.redo);
        await tester.ensureVisible(
          find.byKey(const ValueKey('canvas-fullscreen')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('canvas-fullscreen')));
        await tester.pumpAndSettle();
        expect(state.fullScreen, isTrue);
        expect(
          tester.state<CanvasActivityState>(find.byType(CanvasActivity)),
          same(state),
        );
        expect(find.byType(AppBar), findsNothing);
        expect(tester.getSize(canvas).height, greaterThan(originalSize.height));
        await tester.tap(find.byKey(const ValueKey('canvas-zoom-in')));
        await tester.pump();
        expect(state.zoom, 1.25);
        await tester.tap(find.byKey(const ValueKey('canvas-zoom-out')));
        await tester.pump();
        expect(state.zoom, 1);
        for (var i = 0; i < 15; i++) {
          await tester.tap(find.byKey(const ValueKey('canvas-zoom-in')));
          await tester.pump();
        }
        expect(state.zoom, 4);
        expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('canvas-zoom-in')))
              .onPressed,
          isNull,
        );
        await tester.tap(find.byKey(const ValueKey('canvas-fit')));
        await tester.pump();
        var bounds = tester.getRect(canvas);
        final first = await tester.startGesture(
          bounds.center - const Offset(40, 0),
          pointer: 1,
        );
        final second = await tester.startGesture(
          bounds.center + const Offset(40, 0),
          pointer: 2,
        );
        for (var i = 1; i <= 8; i++) {
          await first.moveTo(bounds.center - Offset(40 + i * 10, 0));
          await second.moveTo(bounds.center + Offset(40 + i * 10, 0));
          await tester.pump();
        }
        await first.up();
        await second.up();
        await tester.pumpAndSettle();
        expect(state.zoom, greaterThan(1));
        expect(jsonEncode(state.drawing), original);
        expect(state.redo, redoBefore);
        final inwardFirst = await tester.startGesture(
          bounds.center - const Offset(40, 0),
          pointer: 3,
        );
        final inwardSecond = await tester.startGesture(
          bounds.center + const Offset(40, 0),
          pointer: 4,
        );
        for (var i = 1; i <= 8; i++) {
          await inwardFirst.moveTo(bounds.center - Offset(40 - i * 4, 0));
          await inwardSecond.moveTo(bounds.center + Offset(40 - i * 4, 0));
          await tester.pump();
        }
        await inwardFirst.up();
        await inwardSecond.up();
        await tester.pumpAndSettle();
        expect(
          state.zoom,
          1,
          reason: 'Pinching inward returns to fit without going below 100%.',
        );
        expect(jsonEncode(state.drawing), original);
        expect(state.redo, redoBefore);
        await tester.tap(find.byKey(const ValueKey('canvas-zoom-in')));
        await tester.pump();
        final zoom = state.zoom;
        tester.view.physicalSize = const Size(1100, 600);
        await tester.pumpAndSettle();
        expect(state.zoom, zoom);
        expect(tester.getSize(canvas), const Size(1100, 600));
        expect(jsonEncode(state.drawing), original);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(state.fullScreen, isFalse);
        expect(state.zoom, zoom);
        expect(find.byType(AppBar), findsOneWidget);
        expect(jsonEncode(state.drawing), original);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await app.flush();
        ads.dispose();
        container.dispose();
      }
    },
  );
  test('all 120 drawing pictures have visible initial guides', () async {
    final catalog = await Catalog.load();
    final activities = catalog.bySection['drawing']!;
    expect(activities.length, 120);
    for (final activity in activities) {
      final scene = sceneFor(catalog.art, activity.config('en')['scene'])!;
      final data = await pixels(
        VectorPainter(
          scene: scene,
          outlineOnly: true,
          guideShapes: 1,
          guideOpacity: .65,
        ),
      );
      var ink = 0;
      for (var i = 0; i < data.length; i += 4) {
        if (data[i] < 245 || data[i + 1] < 245 || data[i + 2] < 245) ink++;
      }
      expect(ink, greaterThan(100), reason: activity.id);
      expect(scene.guideSteps, greaterThan(0));
    }
  });

  test('brushes render distinct marks; legacy strokes and crayon grain stay stable', () async {
    final stroke = {
      'color': 0xff284a83,
      'width': 60,
      'points': [
        [80, 300],
        [520, 300],
      ],
    };
    Future<List<int>> render(Map value) => pixels(
      VectorPainter(
        scene: null,
        drawing: {
          'strokes': [value],
        },
      ),
    );
    final legacy = await render(stroke);
    final outputs = <List<int>>[];
    for (final style in BrushStyle.values) {
      outputs.add(await render({...stroke, 'brush': style.name}));
    }
    expect(outputs.first, legacy);
    for (var i = 0; i < outputs.length; i++) {
      for (var j = i + 1; j < outputs.length; j++) {
        expect(outputs[i], isNot(outputs[j]));
      }
    }
    expect(await render({...stroke, 'brush': 'crayon'}), outputs.last);
    expect(await render({...stroke, 'brush': 'unknown-old-tool'}), legacy);
  });

  testWidgets(
    'brush types, expanded palette and guide steps survive saved artwork recovery',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = (await tester.runAsync(Catalog.load))!;
      final app = await makeApp(catalog);
      final activity = catalog.byId['drawing-0002']!;
      Future<void> mount() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CanvasActivity(
                activity: activity,
                app: app,
                onComplete: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount();
      await tester.tap(find.byTooltip(app.t('nextStep')));
      await tester.pumpAndSettle();
      expect(
        tester.state<CanvasActivityState>(find.byType(CanvasActivity)).guide,
        2,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip(app.t('undo')));
      await tester.pumpAndSettle();
      expect(
        tester.state<CanvasActivityState>(find.byType(CanvasActivity)).guide,
        1,
      );
      await tester.tap(find.byTooltip(app.t('redo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('all-colors')));
      await tester.pumpAndSettle();
      expect(CanvasActivityState.colors.toSet().length, 36);
      final lastColor = find.bySemanticsLabel('${app.t('choose')} 36').last;
      await tester.ensureVisible(lastColor);
      await tester.tap(lastColor);
      await tester.pumpAndSettle();
      for (final style in BrushStyle.values) {
        await tester.tap(find.byKey(const ValueKey('brush-style')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(app.t('brush_${style.name}')).last);
        await tester.pumpAndSettle();
        final bounds = tester.getRect(find.byKey(const ValueKey('art-canvas')));
        await tester.dragFrom(
          bounds.center - const Offset(60, 0),
          const Offset(120, 20),
        );
        await tester.pumpAndSettle();
      }
      await app.flush();
      final saved = await app.artwork(activity.id);
      expect(
        (saved!['strokes'] as List).map((s) => s['brush']).toList(),
        BrushStyle.values.map((s) => s.name).toList(),
      );
      expect(
        (saved['strokes'] as List).every(
          (s) => s['color'] == CanvasActivityState.colors.last,
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      await mount();
      final restored = tester.state<CanvasActivityState>(
        find.byType(CanvasActivity),
      );
      expect(restored.drawing['strokes'], saved['strokes']);
      expect(restored.guide, 2);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
}
