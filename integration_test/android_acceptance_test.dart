import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/activities/trace_geometry.dart';
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
  testWidgets('all-section curriculum and isolated native SQLite', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'pikolumi-acceptance-',
    );
    final databaseFile = File('${directory.path}/isolated.sqlite');
    final store = NativeRecordStore(NativeDatabase(databaseFile));
    final catalog = await Catalog.load();
    final app = AppController(
      catalog: catalog,
      store: store,
      audio: SilentAudio(),
    );
    await app.initialize();
    await app.setSound(false);
    await app.setMotion(true);
    final ads = AdsService(store, app.audio);
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
    addTearDown(() async {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      container.dispose();
      ads.dispose();
      await store.close();
      await directory.delete(recursive: true);
    });
    final completed = <Map<String, dynamic>>[];
    const startCase = int.fromEnvironment('PIKOLUMI_QA_START_CASE');
    var caseIndex = 0;
    final samples = <String, Activity>{};
    for (final activities in catalog.bySection.values) {
      for (final band in activities.map((a) => a.stage).toSet()) {
        final sample = activities.firstWhere((a) => a.stage == band);
        samples[sample.id] = sample;
      }
      for (final engine in activities.map((a) => a.engine).toSet()) {
        final sample = activities.firstWhere((a) => a.engine == engine);
        samples[sample.id] = sample;
      }
    }
    expect(startCase, inInclusiveRange(0, samples.length * 5 - 1));
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 30));
    }

    Future<void> open(Activity activity) async {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ActivityScreen(activity: activity, ads: ads),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ActivityScreen), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Open ${activity.id}');
    }

    for (final language in ['en', 'fr', 'es', 'pt', 'ar']) {
      await app.setLanguage(language);
      await app.setLearningLanguage(language);
      await tester.pumpAndSettle();
      final captured = <String>{};
      for (final activity in samples.values) {
        if (caseIndex++ < startCase) continue;
        final cfg = activity.config(app.activityLanguage(activity));
        await open(activity);
        if ((language == 'en' || language == 'ar') &&
            captured.add(activity.section)) {
          await capture(
            binding,
            '$language-${activity.section}-band-${activity.stage}',
          );
        }
        switch (activity.engine) {
          case 'quiz':
            final options = (cfg['options'] as List).cast<Map>();
            final wrong = options.firstWhere(
              (o) => o['value'] != cfg['correct'],
            );
            await tap(find.byKey(ValueKey('option-${wrong['value']}')));
            await tester.pump(const Duration(milliseconds: 850));
            expect(find.byType(AlertDialog), findsNothing);
            await tap(find.byKey(ValueKey('option-${cfg['correct']}')));
          case 'sequence':
            for (final char in cfg['word'].toString().characters) {
              await tap(find.byKey(ValueKey('letter-$char')));
            }
          case 'sort':
            for (final item in cfg['items']) {
              await tap(find.byKey(ValueKey('sort-item-${item['value']}')));
              await tap(find.byKey(ValueKey('sort-group-${item['target']}')));
            }
          case 'memory':
            final pairs = (cfg['pairs'] as List).cast<String>();
            final deck = [...pairs, ...pairs]
              ..shuffle(math.Random(cfg['layout']));
            for (final picture in pairs) {
              await tap(
                find.byKey(ValueKey('memory-${deck.indexOf(picture)}')),
              );
              await tap(
                find.byKey(ValueKey('memory-${deck.lastIndexOf(picture)}')),
              );
              await tester.pump(const Duration(milliseconds: 750));
            }
          case 'jigsaw':
            final n = cfg['size'] as int;
            for (var i = 0; i < n * n - 1; i++) {
              await tap(find.byKey(ValueKey('jigsaw-$i')));
              await tap(find.byKey(ValueKey('jigsaw-${n * n - 1}')));
            }
          case 'music':
            for (final note in cfg['notes']) {
              await tap(find.byKey(ValueKey('note-$note')));
            }
          case 'maze':
            final size = cfg['size'] as int;
            final walls = cfg['walls'] as List;
            final queue = [0],
                previous = <int, int>{0: -1},
                directions = <int, int>{};
            for (var head = 0; head < queue.length; head++) {
              final pos = queue[head];
              for (var d = 0; d < 4; d++) {
                final to = pos + [-size, 1, size, -1][d];
                if (walls[pos][d] == 0 && !previous.containsKey(to)) {
                  previous[to] = pos;
                  directions[to] = d;
                  queue.add(to);
                }
              }
            }
            final route = <int>[];
            var pos = cfg['finish'] as int;
            while (pos != 0) {
              route.add(directions[pos]!);
              pos = previous[pos]!;
            }
            for (final d in route.reversed) {
              await tap(find.byKey(ValueKey('maze-$d')));
            }
          case 'trace':
            final paths = tracePoints(cfg['strokes'] as List);
            for (final path in paths) {
              final rect = tester.getRect(
                find.byKey(const ValueKey('trace-canvas')),
              );
              final viewport = TraceViewport(rect.size);
              final gesture = await tester.startGesture(
                rect.topLeft + viewport.physical(path.first),
              );
              for (var i = 1; i < path.length; i++) {
                if (i % 3 != 0 && i != path.length - 1) continue;
                await gesture.moveTo(rect.topLeft + viewport.physical(path[i]));
                await tester.pump(const Duration(milliseconds: 1));
              }
              await gesture.up();
              await tester.pump();
            }
          case 'canvas':
            await tap(find.text(app.t('brush')).first);
            final rect = tester.getRect(
              find.byKey(const ValueKey('art-canvas')),
            );
            final gesture = await tester.startGesture(rect.center);
            for (var i = 1; i <= 8; i++) {
              await gesture.moveTo(rect.center + Offset(i * 3, i * 2));
              await tester.pump(const Duration(milliseconds: 16));
            }
            await gesture.up();
            await tester.pumpAndSettle();
            await app.flush();
            expect((await app.artwork(activity.id))!['strokes'], isNotEmpty);
            await tap(find.text(app.t('done')));
          default:
            fail('Unknown engine ${activity.engine}');
        }
        await tester.pumpAndSettle();
        expect(
          find.byType(AlertDialog),
          findsOneWidget,
          reason: '${activity.id} / $language',
        );
        expect(app.isCompleted(activity), isTrue);
        expect(
          tester.takeException(),
          isNull,
          reason: '${activity.id} / $language',
        );
        completed.add({
          'id': activity.id,
          'section': activity.section,
          'band': activity.stage,
          'language': language,
          'engine': activity.engine,
        });
        debugPrint('PIKOLUMI_ACCEPTANCE $caseIndex ${activity.id} $language');
        await tap(find.text(app.t('continue')));
        await tester.pumpAndSettle();
        expect(find.byType(ActivityScreen), findsNothing);
      }
    }
    final original = app.active;
    final originalResults = Map<String, dynamic>.from(app.results);
    final originalGallery = Map<String, dynamic>.from(app.gallery);
    await app.addProfile(3, 3);
    expect(app.results, isEmpty);
    expect(app.gallery, isEmpty);
    await app.selectProfile(original);
    expect(app.results, originalResults);
    expect(app.gallery, originalGallery);
    await app.flush();
    final rows = await store.list('settings');
    expect(jsonDecode(rows['app']!)['active'], original.id);
    final reopened = NativeRecordStore(NativeDatabase(databaseFile));
    final restored = AppController(
      catalog: catalog,
      store: reopened,
      audio: SilentAudio(),
    );
    await restored.initialize();
    expect(restored.results, originalResults);
    expect(restored.gallery, originalGallery);
    expect(restored.active.id, original.id);
    expect(restored.sound, isFalse);
    restored.dispose();
    await reopened.close();
    binding.reportData = {
      ...?binding.reportData,
      'completedCases': completed,
      'startCase': startCase,
      'plannedCases': samples.length * 5,
      'activityIds': samples.keys.toList(),
      'allSections': catalog.bySection.keys.toList(),
      'languages': ['en', 'fr', 'es', 'pt', 'ar'],
      'nativeSQLiteReopen': true,
      'siblingIsolation': true,
      'artworkPersisted': true,
      'audioPlayback': false,
      'adsRequestedInCurriculumRun': false,
      'humanEditorialApproval': false,
      'store': 'isolated temporary SQLite; user app databases not accessed',
    };
  }, timeout: const Timeout(Duration(minutes: 45)));
}
