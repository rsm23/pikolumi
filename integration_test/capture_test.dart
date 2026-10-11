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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'localized native screenshots and interactive performance sample',
    (tester) async {
      await production.main();
      await tester.pumpAndSettle();
      final state = tester.state<ConsumerState>(find.byType(LibraryHome));
      final app = state.ref.read(appProvider);
      await app.setSound(false);
      final ads = tester.widget<LibraryHome>(find.byType(LibraryHome)).ads;
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
        final colors = [
          0xFF30B7AF,
          0xFFFFCE54,
          0xFFFF7790,
          0xFF9B88E3,
          0xFF83BE80,
        ];
        // Populate artwork only in this screenshot fixture.
        // ignore: invalid_use_of_protected_member
        drawing.setState(() {
          for (final (i, shape) in drawing.scene!.shapes.indexed) {
            drawing.drawing['fills'][shape.id] = colors[i % colors.length];
          }
        });
        await capture(locale, 'coloring');
        if (locale == 'en') {
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
      if (!const bool.fromEnvironment('CAPTURE_LIBRARY_ONLY')) {
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
