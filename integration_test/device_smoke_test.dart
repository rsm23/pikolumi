import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/main.dart' as production;
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/ui/library.dart';
import 'package:pikolumi/ui/activity_screen.dart';
import 'package:pikolumi/ui/vector_art.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native offline bundle, coloring save/reopen, learning and sibling isolation',
    (tester) async {
      await production.main();
      await tester.pumpAndSettle();
      final state = tester.state<ConsumerState>(find.byType(LibraryHome));
      final app = state.ref.read(appProvider);
      await app.setSound(false);
      final ads = tester.widget<LibraryHome>(find.byType(LibraryHome)).ads;
      await ads.synchronizeSound();
      final original = app.active;
      await app.addProfile(0, 1);
      await app.setLanguage('en');
      await tester.pumpAndSettle();
      // Every essential audio file is physically bundled; no HTTP content provider is involved.
      final audio = jsonDecode(
        await rootBundle.loadString('assets/content/audio_manifest.json'),
      ) as Map;
      for (final language in audio.entries) {
        for (final file in (language.value as Map).keys) {
          expect(
            (await rootBundle.load('assets/audio/${language.key}/$file'))
                .lengthInBytes,
            greaterThan(100),
          );
        }
      }
      for (var i = 0; i < 8; i++) {
        expect(
          (await rootBundle.load('assets/audio/note_$i.mp3')).lengthInBytes,
          greaterThan(100),
        );
      }
      expect(app.catalog.activities.length, 2400);
      final piko = find.byType(LibraryHome);
      await tester.tap(find.text('Coloring').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(app.catalog.activities.first.title('en')).first,
      );
      await tester.pumpAndSettle();
      expect(ads.activityDepth, 1);
      final canvas = find
          .byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is VectorPainter,
          )
          .last;
      final rect = tester.getRect(canvas);
      await tester.tapAt(
        rect.topLeft + Offset(rect.width * .1, rect.height * .1),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await app.flush();
      expect((await app.artwork('coloring-0001'))!['fills'], isNotEmpty);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(app.catalog.activities.first.title('en')).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finished!'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep exploring'));
      await tester.pumpAndSettle();
      expect(app.completed, 1);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      final context = tester.element(piko);
      final counting = app.catalog.bySection['counting']!.first;
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityScreen(activity: counting, ads: ads),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(counting.config('en')['correct']).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep exploring'));
      await tester.pumpAndSettle();
      expect(app.completed, 2);
      await app.addProfile(3, 3);
      expect(app.completed, 0);
      expect(app.gallery, isEmpty);
      await app.selectProfile(original);
      await app.setLanguage('en');
      await tester.pumpAndSettle();
      for (final locale in ['fr', 'es', 'pt', 'ar']) {
        await app.setLanguage(locale);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        unawaited(
          Navigator.of(tester.element(piko)).push(
            MaterialPageRoute<void>(
              builder: (_) => ActivityScreen(
                activity: app.catalog.bySection['math']!.last,
                ads: ads,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      await app.setLanguage('en');
      await app.flush();
      await tester.pumpAndSettle();
      await app.audio.voice.setVolume(0);
      app.audio.enabled = true;
      await app.audio.play('en', 'welcome.mp3');
      await tester.pump(const Duration(seconds: 2));
      expect(await app.audio.voice.getDuration(), isNotNull);
      await app.audio.stop();
      app.audio.enabled = false;
      await ads.checkpoint();
      binding.reportData = {
        'activities': 2400,
        'bundledAudioClips':
            audio.values.fold<int>(
              0,
              (sum, value) => sum + (value as Map).length,
            ) +
            8,
        'profileIsolation': true,
        'nativeArtworkRecovery': true,
        'learningCompletion': true,
        'languageLayouts': ['en', 'fr', 'es', 'pt', 'ar'],
        'productionAds': false,
      };
      expect(tester.takeException(), isNull);
    },
  );
}
