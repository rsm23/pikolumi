import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/main.dart';
import 'package:pikolumi/services/ad_budget.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/services/audio.dart';
import 'package:pikolumi/services/store_native.dart';
import 'package:pikolumi/services/store_interface.dart';
import 'package:pikolumi/ui/activity_screen.dart';
import 'package:pikolumi/ui/vector_art.dart';
import 'package:pikolumi/ui/library.dart';

class MemoryStore implements RecordStore {
  final data = <String, Map<String, String>>{};
  @override
  Future<String?> read(String namespace, String key) async =>
      data[namespace]?[key];
  @override
  Future<Map<String, String>> list(String namespace) async =>
      Map.from(data[namespace] ?? {});
  @override
  Future<void> write(String namespace, String key, String value) async {
    (data[namespace] ??= {})[key] = value;
  }

  @override
  Future<void> remove(String namespace, String key) async {
    data[namespace]?.remove(key);
  }

  @override
  Future<void> close() async {}
}

class SilentAudio extends AudioService {
  @override
  Future<void> playSequence(String language, List<String> files) async {}
  @override
  Future<void> play(String language, String file) async {}
  @override
  Future<void> note(int number) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

Future<AppController> makeApp(Catalog catalog, {RecordStore? store}) async {
  final app = AppController(
    catalog: catalog,
    store: store ?? MemoryStore(),
    audio: SilentAudio(),
  );
  await app.initialize();
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Catalog catalog;
  setUpAll(() async {
    catalog = await Catalog.load();
  });
  test('ad limits survive serialization, require both milestones and cap rolling hour', () {
    final now = DateTime.utc(2026, 10, 11, 12);
    final budget = AdBudget();
    budget.addForeground(const Duration(minutes: 5));
    for (var i = 0; i < 3; i++) {
      budget.completed();
    }
    expect(budget.eligible(now), false);
    budget.completed();
    expect(budget.eligible(now), true);
    budget.shown(now);
    expect(budget.eligible(now), false);
    for (var i = 0; i < 4; i++) {
      budget.completed();
    }
    budget.addForeground(const Duration(minutes: 4, seconds: 59));
    expect(budget.eligible(now.add(const Duration(minutes: 5))), false);
    budget.addForeground(const Duration(seconds: 1));
    expect(budget.eligible(now.add(const Duration(minutes: 5))), true);
    final restored = AdBudget.fromJson(jsonDecode(jsonEncode(budget.toJson())));
    expect(restored.eligible(now.add(const Duration(minutes: 5))), true);
    for (var i = 1; i < 6; i++) {
      restored.shown(now.add(Duration(minutes: 5 * i)));
      restored.addForeground(const Duration(minutes: 5));
      for (var j = 0; j < 4; j++) {
        restored.completed();
      }
    }
    expect(restored.eligible(now.add(const Duration(minutes: 40))), false);
    expect(
      restored.eligible(now.add(const Duration(hours: 1, seconds: 1))),
      true,
    );
  });
  test('SQLite profile isolation and reopening preserve artwork, progress, preferences and resume', () async {
    final directory = await Directory.systemTemp.createTemp('pikolumi-test-');
    final file = File('${directory.path}/state.sqlite');
    final firstStore = NativeRecordStore(NativeDatabase(file));
    final app = await makeApp(catalog, store: firstStore);
    final sibling = app.active;
    await app.complete(catalog.activities.first);
    await app.toggleFavorite(catalog.activities.first.id);
    await app.saveArtwork('coloring-0001', {
      'fills': {'r0': 123},
      'strokes': [],
    }, scene: 'scene_0_0');
    await app.saveResume('mazes-0001', {'position': 1});
    await app.setLanguage('ar');
    await app.setPin('123456');
    await app.addProfile(3, 2);
    expect(app.results, isEmpty);
    expect(app.gallery, isEmpty);
    expect(app.favorites, isEmpty);
    expect(await app.artwork('coloring-0001'), isNull);
    expect(await app.resume('mazes-0001'), isNull);
    await app.saveArtwork('coloring-0001', {
      'fills': {'r0': 999},
      'strokes': [],
    });
    await app.selectProfile(sibling);
    expect((await app.artwork('coloring-0001'))!['fills']['r0'], 123);
    expect(app.completed, 1);
    await firstStore.close();
    app.dispose();
    final reopened = NativeRecordStore(NativeDatabase(file));
    final restored = await makeApp(catalog, store: reopened);
    expect(restored.language, 'ar');
    expect(restored.profiles.length, 2);
    expect(restored.verifyPin('123456'), true);
    expect(restored.verifyPin('000000'), false);
    expect(restored.completed, 1);
    expect(restored.favorites, contains('coloring-0001'));
    expect((await restored.resume('mazes-0001'))!['position'], 1);
    for (var i = 0; i < 5; i++) {
      await restored.recordGateFailure();
    }
    expect(restored.gateLocked, true);
    await restored.clearGateFailures();
    expect(restored.gateLocked, false);
    restored.dispose();
    await reopened.close();
    await directory.delete(recursive: true);
  });
  test(
    'vector region hit testing honors top shapes and every bundled path parses',
    () {
      for (final section in catalog.sections) {
        expect(
          sceneFor(catalog.art, sectionMotifs[section.id])?.shapes,
          isNotEmpty,
          reason: section.id,
        );
      }
      for (final key in catalog.art.keys) {
        final scene = sceneFor(catalog.art, key)!;
        expect(scene.shapes, isNotEmpty);
        for (final shape in scene.shapes) {
          expect(shape.path.getBounds().isFinite, true, reason: key);
        }
      }
      final scene = VectorScene.fromJson({
        'width': 100,
        'height': 100,
        'shapes': [
          {
            'id': 'outer',
            'kind': 'rect',
            'v': [0, 0, 100, 100, 0],
            'color': 'FFFFFF',
          },
          {
            'id': 'inner',
            'kind': 'ellipse',
            'v': [25, 25, 50, 50],
            'color': 'FF0000',
          },
        ],
      });
      expect(scene.regionAt(const Offset(50, 50)), 'inner');
      expect(scene.regionAt(const Offset(5, 5)), 'outer');
      expect(scene.regionAt(const Offset(110, 110)), isNull);
    },
  );
  testWidgets(
    'two-tap library, completion and interrupted artwork restoration',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = await makeApp(catalog);
      final ads = AdsService(app.store, app.audio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => app)],
          child: PikolumiApp(ads: ads),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coloring').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(catalog.activities.first.title('en')).first);
      await tester.pumpAndSettle();
      expect(find.byType(ActivityScreen), findsOneWidget);
      expect(ads.activityDepth, 1);
      final canvas = find
          .byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is VectorPainter,
          )
          .last;
      final box = tester.getRect(canvas);
      await tester.tapAt(box.topLeft + Offset(box.width * .1, box.height * .1));
      await tester.pump(const Duration(milliseconds: 300));
      await app.flush();
      final saved = await app.artwork('coloring-0001');
      expect(saved, isNotNull);
      expect((saved!['fills'] as Map).isNotEmpty, true);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(ads.activityDepth, 0);
      await tester.tap(find.text(catalog.activities.first.title('en')).first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Undo'), findsOneWidget);
      await tester.tap(find.text('Finished!'));
      await tester.pumpAndSettle();
      expect(app.completed, 1);
      expect(find.text('Wonderful work!'), findsOneWidget);
      await tester.tap(find.text('Keep exploring'));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityScreen), findsNothing);
      expect(ads.budget.completions, 1);
      await tester.pumpWidget(const SizedBox());
      ads.dispose();
      await app.store.close();
    },
  );
  for (final locale in ['en', 'fr', 'es', 'pt', 'ar']) {
    testWidgets(
      'all sixteen sections render in $locale on phone and landscape tablet',
      (tester) async {
        final app = await makeApp(catalog);
        await app.setLanguage(locale);
        final ads = AdsService(app.store, app.audio);
        for (final size in [const Size(375, 812), const Size(1024, 768)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          for (final section in catalog.sections) {
            final activities = catalog.bySection[section.id]!;
            final chosen = size.width < 400
                ? activities.first
                : activities.last;
            await tester.pumpWidget(
              ProviderScope(
                overrides: [appProvider.overrideWith((ref) => app)],
                child: MaterialApp(
                  locale: Locale(locale),
                  supportedLocales: const [
                    Locale('en'),
                    Locale('fr'),
                    Locale('es'),
                    Locale('pt'),
                    Locale('ar'),
                  ],
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  home: ActivityScreen(
                    key: ValueKey('${size.width}-${chosen.id}'),
                    activity: chosen,
                    ads: ads,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$locale ${section.id} $size',
            );
          }
        }
        await tester.pumpWidget(const SizedBox());
        ads.dispose();
        await app.store.close();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  }
}
