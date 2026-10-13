import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/main.dart' as production;
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/ui/library.dart';
import 'package:pikolumi/ui/activity_screen.dart';
import 'package:pikolumi/activities/canvas_activity.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/services/ads.dart';

import '../test/app_test.dart' show MemoryStore, SilentAudio;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'localized native screenshots and interactive performance sample',
    (tester) async {
      final app = AppController(
        catalog: await Catalog.load(),
        store: MemoryStore(),
        audio: SilentAudio(),
      );
      await app.initialize();
      await app.setSound(false);
      final ads = AdsService(app.store, app.audio);
      runApp(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => app)],
          child: production.PikolumiApp(ads: ads),
        ),
      );
      await tester.pumpAndSettle();
      await ads.synchronizeSound();
      // Store screenshot fixtures depict the UI when no banner is available.
      // This suppression exists only in the test harness, never in the shipped app.
      ads.enterActivity();
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
      }
      Future<void> capture(String locale, String scene) async {
        await tester.pumpAndSettle();
        await binding.takeScreenshot('$locale-$scene');
      }

      Future<void> open(String section, int index) async {
        unawaited(
          Navigator.of(tester.element(find.byType(LibraryHome))).push(
            MaterialPageRoute<void>(
              builder: (_) => ActivityScreen(
                activity: app.catalog.bySection[section]![index],
                ads: ads,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      for (final locale in ['en', 'fr', 'es', 'pt', 'ar']) {
        await app.setLanguage(locale);
        await capture(locale, 'library');
        if (const bool.fromEnvironment('CAPTURE_LIBRARY_ONLY')) continue;
        await open('coloring', 35);
        final drawing = tester.state<CanvasActivityState>(
          find.byType(CanvasActivity),
        );
        if (locale == 'en') await capture(locale, 'coloring-outline');
        // Populate artwork only in this screenshot fixture.
        // ignore: invalid_use_of_protected_member
        drawing.setState(() {
          for (final shape in drawing.scene!.shapes) {
            if (shape.fillable) {
              final original = shape.color.toARGB32();
              int distance(int candidate) {
                final red =
                    ((original >> 16) & 255) - ((candidate >> 16) & 255);
                final green =
                    ((original >> 8) & 255) - ((candidate >> 8) & 255);
                final blue = (original & 255) - (candidate & 255);
                return red * red + green * green + blue * blue;
              }

              drawing.drawing['fills'][shape.id] = CanvasActivityState.colors
                  .reduce(
                    (left, right) =>
                        distance(left) <= distance(right) ? left : right,
                  );
            }
          }
        });
        await capture(locale, 'coloring');
        if (locale == 'en' &&
            !const bool.fromEnvironment('CAPTURE_SKIP_PERFORMANCE')) {
          await tester.ensureVisible(find.text(app.t('brush')));
          await tester.tap(find.text(app.t('brush')));
          final rect = tester.getRect(find.byKey(const ValueKey('art-canvas')));
          await binding.watchPerformance(() async {
            final gesture = await tester.startGesture(rect.center);
            for (var i = 0; i < 80; i++) {
              await gesture.moveTo(
                rect.center + Offset((i % 20) * 2.0, (i / 20).floor() * 3.0),
              );
              await tester.pump(const Duration(milliseconds: 16));
            }
            await gesture.up();
            await tester.pumpAndSettle();
          }, reportKey: 'drawingPerformance');
        }
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await open('jigsaw', 60);
        await capture(locale, 'puzzle');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await open('math', 163);
        await capture(locale, 'math');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await app.setLanguage('en');
      await tester.pumpAndSettle();
      if (!const bool.fromEnvironment('CAPTURE_LIBRARY_ONLY') &&
          !const bool.fromEnvironment('CAPTURE_SKIP_PERFORMANCE')) {
        await binding.watchPerformance(() async {
          for (var i = 0; i < 8; i++) {
            await tester.drag(
              find.byType(CustomScrollView).first,
              Offset(0, i < 4 ? -240 : 240),
            );
            await tester.pumpAndSettle();
          }
        }, reportKey: 'libraryScrollPerformance');
      }
      ads.leaveActivity();
      await app.flush();
      expect(tester.takeException(), isNull);
    },
  );
}
