import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikolumi/activities/canvas_activity.dart';
import 'package:pikolumi/activities/learning.dart';
import 'package:pikolumi/activities/tracing_maze.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/ui/parent_area.dart';

import 'app_test.dart' show MemoryStore, SilentAudio;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Catalog catalog;
  setUpAll(() async {
    catalog = await Catalog.load();
  });
  for (final lang in ['en', 'fr', 'es', 'pt', 'ar']) {
    testWidgets('interactive learning engines complete correctly in $lang', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppController(
        catalog: catalog,
        store: MemoryStore(),
        audio: SilentAudio(),
      );
      await app.initialize();
      await app.setLanguage(lang);
      int completions = 0;
      Map<String, dynamic>? saved;
      Future<EngineContext> mount(
        String section,
        Widget Function(EngineContext) build,
      ) async {
        completions = 0;
        saved = null;
        final activity = catalog.bySection[section]!.first;
        final engine = EngineContext(
          activity: activity,
          app: app,
          complete: () => completions++,
          resume: null,
          save: (state) => saved = state,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: lang == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Scaffold(body: build(engine)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return engine;
      }

      final quiz = await mount('math', (e) => QuizActivity(engine: e));
      final cfg = quiz.config;
      final wrong = (cfg['options'] as List).firstWhere(
        (o) => o['value'] != cfg['correct'],
      )['value'];
      await tester.tap(find.byKey(ValueKey('option-$wrong')));
      await tester.pump(const Duration(seconds: 1));
      expect(completions, 0);
      await tester.tap(find.byKey(ValueKey('option-${cfg['correct']}')));
      await tester.pump();
      expect(completions, 1);
      final spelling = catalog.bySection['words']!.firstWhere(
        (a) => a.engine == 'sequence',
      );
      completions = 0;
      final wordEngine = EngineContext(
        activity: spelling,
        app: app,
        complete: () => completions++,
        resume: null,
        save: (value) => saved = value,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WordActivity(engine: wordEngine)),
        ),
      );
      await tester.pumpAndSettle();
      for (final char in wordEngine.config['word'].toString().characters) {
        await tester.tap(find.byKey(ValueKey('letter-$char')));
        await tester.pump();
      }
      expect(completions, 1);
      expect(
        saved!['index'],
        wordEngine.config['word'].toString().characters.length,
      );
      final sorting = await mount('sorting', (e) => SortingActivity(engine: e));
      for (final item in sorting.config['items']) {
        await tester.tap(find.byKey(ValueKey('sort-item-${item['value']}')));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey('sort-group-${item['target']}')));
        await tester.pump();
      }
      expect(completions, 1);
      final memory = await mount('memory', (e) => MemoryActivity(engine: e));
      final pairs = (memory.config['pairs'] as List).cast<String>();
      final deck = [...pairs, ...pairs]
        ..shuffle(math.Random(memory.config['layout']));
      for (final picture in pairs) {
        final a = deck.indexOf(picture), b = deck.lastIndexOf(picture);
        await tester.tap(find.byKey(ValueKey('memory-$a')));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey('memory-$b')));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(completions, 1);
      expect((saved!['matched'] as List).length, deck.length);
      final jigsaw = await mount('jigsaw', (e) => JigsawActivity(engine: e));
      final n = jigsaw.config['size'] as int;
      for (var i = 0; i < n * n - 1; i++) {
        await tester.tap(find.byKey(ValueKey('jigsaw-$i')));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey('jigsaw-${n * n - 1}')));
        await tester.pump();
      }
      expect(completions, 1);
      expect(saved!['order'], List.generate(n * n, (i) => i));
      final music = await mount('music', (e) => MusicActivity(engine: e));
      final notes = (music.config['notes'] as List).cast<int>();
      await tester.tap(find.byKey(ValueKey('note-${(notes.first + 1) % 8}')));
      await tester.pump();
      expect(completions, 0);
      for (final note in notes) {
        await tester.tap(find.byKey(ValueKey('note-$note')));
        await tester.pump();
      }
      expect(completions, 1);
      final maze = await mount('mazes', (e) => MazeActivity(engine: e));
      final size = maze.config['size'] as int;
      final walls = maze.config['walls'] as List;
      final queue = [0], previous = <int, int>{0: -1}, direction = <int, int>{};
      for (var head = 0; head < queue.length; head++) {
        final pos = queue[head];
        for (var d = 0; d < 4; d++) {
          final to = pos + [-size, 1, size, -1][d];
          if (walls[pos][d] == 0 && !previous.containsKey(to)) {
            previous[to] = pos;
            direction[to] = d;
            queue.add(to);
          }
        }
      }
      final route = <int>[];
      var pos = maze.config['finish'] as int;
      while (pos != 0) {
        route.add(direction[pos]!);
        pos = previous[pos]!;
      }
      for (final d in route.reversed) {
        await tester.tap(find.byKey(ValueKey('maze-$d')));
        await tester.pump();
      }
      expect(completions, 1);
      final trace = await mount('tracing', (e) => TraceActivity(engine: e));
      final area = tester.getRect(find.byKey(const ValueKey('trace-canvas')));
      Offset physical(List<dynamic> p) =>
          area.topLeft +
          Offset(
            (p[0] as num).toDouble() / 220 * area.width,
            (p[1] as num).toDouble() / 220 * area.height,
          );
      for (final raw in trace.config['strokes']) {
        final points = raw as List;
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
      expect(completions, 1, reason: 'directed tracing completes $lang');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  }
  testWidgets('closed letter tracing requires the whole path', (tester) async {
    final app = AppController(
      catalog: catalog,
      store: MemoryStore(),
      audio: SilentAudio(),
    );
    await app.initialize();
    final activity = catalog.bySection['tracing']![14];
    var completed = false;
    final engine = EngineContext(
      activity: activity,
      app: app,
      complete: () => completed = true,
      resume: null,
      save: (_) {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TraceActivity(engine: engine)),
      ),
    );
    final rect = tester.getRect(find.byKey(const ValueKey('trace-canvas')));
    final start = engine.config['strokes'][0][0];
    await tester.tapAt(
      rect.topLeft +
          Offset(start[0] / 220 * rect.width, start[1] / 220 * rect.height),
    );
    await tester.pump();
    expect(completed, isFalse);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
  testWidgets(
    'drawing undo/redo, pinch zoom without stray marks, and rotation retain logical strokes',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppController(
        catalog: catalog,
        store: MemoryStore(),
        audio: SilentAudio(),
      );
      await app.initialize();
      final blank = Activity({
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
            body: CanvasActivity(activity: blank, app: app, onComplete: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final finder = find.byKey(const ValueKey('art-canvas'));
      var rect = tester.getRect(finder);
      await tester.dragFrom(
        rect.center - const Offset(60, 0),
        const Offset(120, 40),
      );
      await tester.pumpAndSettle();
      await app.flush();
      final original = await app.artwork(blank.id);
      expect((original!['strokes'] as List).length, 1);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      await app.flush();
      expect((await app.artwork(blank.id))!['strokes'], isEmpty);
      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      await app.flush();
      expect((await app.artwork(blank.id))!['strokes'], original['strokes']);
      final first = await tester.startGesture(
        rect.center - const Offset(40, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        rect.center + const Offset(40, 0),
        pointer: 2,
      );
      for (var i = 1; i <= 8; i++) {
        await first.moveTo(rect.center - Offset(40 + i * 10, 0));
        await second.moveTo(rect.center + Offset(40 + i * 10, 0));
        await tester.pump();
      }
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      await app.flush();
      expect((await app.artwork(blank.id))!['strokes'], original['strokes']);
      final state = tester.state<CanvasActivityState>(
        find.byType(CanvasActivity),
      );
      expect(state.transform.value.storage[0], greaterThan(1));
      tester.view.physicalSize = const Size(1100, 600);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect((await app.artwork(blank.id))!['strokes'], original['strokes']);
      await app.complete(blank);
      expect(app.completed, 0);
      expect(app.sectionCompleted('drawing'), 0);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
  testWidgets('parent PIN gate rejects wrong input and accepts Arabic digits', (
    tester,
  ) async {
    final app = AppController(
      catalog: catalog,
      store: MemoryStore(),
      audio: SilentAudio(),
    );
    await app.initialize();
    await app.setPin('123456');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => parentGate(context, app),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Keep exploring'));
    await tester.pumpAndSettle();
    expect(find.text(app.t('gateWrong')), findsOneWidget);
    await tester.enterText(find.byType(TextField), '١٢٣٤٥٦');
    await tester.tap(find.text('Keep exploring'));
    await tester.pumpAndSettle();
    expect(find.byType(ParentGate), findsNothing);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}
