import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/activities/canvas_activity.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/main.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/ui/activity_screen.dart';
import 'package:pikolumi/ui/brush_stroke.dart';

import '../test/app_test.dart' show MemoryStore, SilentAudio;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Drawing Studio navigation, guides, palette and brushes stay silent',
    (tester) async {
      final catalog = await Catalog.load();
      final app = AppController(
        catalog: catalog,
        store: MemoryStore(),
        audio: SilentAudio(),
      );
      await app.initialize();
      await app.setSound(false);
      final ads = AdsService(app.store, app.audio);
      runApp(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => app)],
          child: PikolumiApp(ads: ads),
        ),
      );
      await tester.pumpAndSettle();
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
      }
      final section = catalog.sections.firstWhere((s) => s.id == 'drawing');
      final activity = catalog.byId['drawing-0002']!;
      for (final locale in ['en', 'fr', 'es', 'pt', 'ar']) {
        await app.setLanguage(locale);
        await app.saveArtwork(activity.id, {
          'artRevision': 3,
          'guide': 1,
          'fills': {},
          'strokes': [],
        }, scene: activity.config(locale)['scene']);
        await tester.pumpAndSettle();
        final shortcut = find.text(section.name(locale)).first;
        await tester.ensureVisible(shortcut);
        await tester.pumpAndSettle();
        await tester.tap(shortcut);
        await tester.pumpAndSettle();
        await tester.tap(find.text(activity.title(locale)).at(1));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ActivityScreen>(find.byType(ActivityScreen))
              .activity
              .id,
          activity.id,
        );
        final state = tester.state<CanvasActivityState>(
          find.byType(CanvasActivity),
        );
        expect(state.scene, isNotNull);
        expect(state.scene!.guideSteps, greaterThan(1));
        await binding.takeScreenshot('$locale-drawing-guide');
        final fullButton = find.byKey(const ValueKey('canvas-fullscreen'));
        await tester.ensureVisible(fullButton);
        await tester.pumpAndSettle();
        await tester.tap(fullButton);
        await tester.pumpAndSettle();
        expect(state.fullScreen, isTrue);
        expect(find.byType(AppBar), findsNothing);
        await binding.takeScreenshot('$locale-fullscreen');
        await tester.tap(find.byKey(const ValueKey('canvas-zoom-in')));
        await tester.pumpAndSettle();
        expect(state.zoom, 1.25);
        if (locale == 'en') await binding.takeScreenshot('en-fullscreen-zoom');
        await tester.tap(find.byKey(const ValueKey('canvas-zoom-out')));
        await tester.pumpAndSettle();
        expect(state.zoom, 1);
        final bounds = tester.getRect(find.byKey(const ValueKey('art-canvas')));
        final first = await tester.startGesture(
          bounds.center - const Offset(40, 0),
          pointer: 1,
        );
        final second = await tester.startGesture(
          bounds.center + const Offset(40, 0),
          pointer: 2,
        );
        for (var i = 1; i <= 6; i++) {
          await first.moveTo(bounds.center - Offset(40 + i * 8, 0));
          await second.moveTo(bounds.center + Offset(40 + i * 8, 0));
          await tester.pump();
        }
        await first.up();
        await second.up();
        await tester.pumpAndSettle();
        expect(state.zoom, greaterThan(1));
        expect(state.drawing['strokes'], isEmpty);
        await tester.tap(find.byKey(const ValueKey('canvas-fit')));
        await tester.pumpAndSettle();
        await tester.tap(fullButton);
        await tester.pumpAndSettle();
        expect(state.fullScreen, isFalse);
        expect(find.byType(AppBar), findsOneWidget);
        if (locale == 'en') {
          await tester.ensureVisible(find.byKey(const ValueKey('all-colors')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('all-colors')));
          await tester.pumpAndSettle();
          await binding.takeScreenshot('en-all-colors');
          final swatch = find.bySemanticsLabel('${app.t('choose')} 36').last;
          await tester.ensureVisible(swatch);
          await tester.pumpAndSettle();
          await tester.tap(swatch);
          await tester.pumpAndSettle();
          for (final style in BrushStyle.values) {
            final picker = find.byKey(const ValueKey('brush-style'));
            await tester.ensureVisible(picker);
            await tester.pumpAndSettle();
            await tester.tap(picker);
            await tester.pumpAndSettle();
            if (style == BrushStyle.round) {
              await binding.takeScreenshot('en-brush-menu');
            }
            await tester.tap(find.text(app.t('brush_${style.name}')).last);
            await tester.pumpAndSettle();
            final bounds = tester.getRect(
              find.byKey(const ValueKey('art-canvas')),
            );
            await tester.dragFrom(
              bounds.topLeft +
                  Offset(
                    bounds.width * .15,
                    bounds.height * (.65 + style.index * .07),
                  ),
              Offset(bounds.width * .6, 0),
            );
            await tester.pumpAndSettle();
          }
          await state.save();
          await app.flush();
          expect(
            (state.drawing['strokes'] as List).map((s) => s['brush']).toList(),
            BrushStyle.values.map((s) => s.name).toList(),
          );
          final next = find.byTooltip(app.t('nextStep'));
          await tester.ensureVisible(next);
          await tester.pumpAndSettle();
          await tester.tap(next);
          await tester.pumpAndSettle();
          await state.save();
          expect(state.guide, 2);
          await binding.takeScreenshot('en-four-brush-strokes');
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          await tester.tap(find.text(activity.title(locale)).at(1));
          await tester.pumpAndSettle();
          final reopened = tester.state<CanvasActivityState>(
            find.byType(CanvasActivity),
          );
          expect((reopened.drawing['strokes'] as List).length, 4);
          expect(reopened.guide, 2);
        }
        final resetState = tester.state<CanvasActivityState>(
          find.byType(CanvasActivity),
        );
        if (locale != 'en') {
          final size = tester.getSize(find.byKey(const ValueKey('art-canvas')));
          resetState.start(size.center(Offset.zero), size);
          resetState.strokeActive = false;
          await tester.pumpAndSettle();
        }
        final strokeCount = (resetState.drawing['strokes'] as List).length;
        expect(strokeCount, greaterThan(0));
        Future<void> showReset() async {
          final reset = find.byKey(const ValueKey('canvas-reset'));
          await tester.ensureVisible(reset);
          await tester.pumpAndSettle();
          await tester.tap(reset);
          await tester.pumpAndSettle();
        }

        await showReset();
        await binding.takeScreenshot('$locale-reset-confirmation');
        await tester.tap(find.byKey(const ValueKey('canvas-reset-cancel')));
        await tester.pumpAndSettle();
        expect((resetState.drawing['strokes'] as List).length, strokeCount);
        await showReset();
        await tester.tap(find.byKey(const ValueKey('canvas-reset-confirm')));
        await tester.pumpAndSettle();
        await app.flush();
        expect(resetState.drawing['strokes'], isEmpty);
        expect(resetState.drawing['fills'], isEmpty);
        expect(resetState.guide, resetState.initialGuide);
        expect((await app.artwork(activity.id))!['strokes'], isEmpty);
        await binding.takeScreenshot('$locale-reset-drawing');
        final undo = find.byTooltip(app.t('undo'));
        await tester.ensureVisible(undo);
        await tester.pumpAndSettle();
        await tester.tap(undo);
        await tester.pumpAndSettle();
        expect((resetState.drawing['strokes'] as List).length, strokeCount);
        await showReset();
        await tester.tap(find.byKey(const ValueKey('canvas-reset-confirm')));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(activity.title(locale)).at(1));
        await tester.pumpAndSettle();
        final cleared = tester.state<CanvasActivityState>(
          find.byType(CanvasActivity),
        );
        expect(cleared.drawing['strokes'], isEmpty);
        expect(cleared.drawing['fills'], isEmpty);
        expect(cleared.guide, cleared.initialGuide);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      expect(app.sound, isFalse);
      expect(app.audio.enabled, isFalse);
      binding.reportData = {
        ...?binding.reportData,
        'drawingActivity': activity.id,
        'locales': ['en', 'fr', 'es', 'pt', 'ar'],
        'paletteColors': 36,
        'fullscreenToggle': true,
        'zoomButtonsAndPinch': true,
        'pinchCreatesNoStrokes': true,
        'brushStyles': BrushStyle.values.map((s) => s.name).toList(),
        'guideAndStrokeRecovery': true,
        'resetCancelConfirmUndoAndReopen': true,
        'store': 'isolated memory; existing profiles and artwork untouched',
        'audio': 'SilentAudio; disabled before runApp',
        'adSDKInitialized': false,
        'testAdsOnly': true,
      };
      await tester.pumpWidget(const SizedBox());
      ads.dispose();
    },
  );
}
