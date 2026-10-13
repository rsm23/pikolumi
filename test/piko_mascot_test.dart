import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikolumi/activities/learning.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/main.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/ui/activity_screen.dart';
import 'package:pikolumi/ui/piko_mascot.dart';

import 'app_test.dart' show makeApp;

Future<void> decoded(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    if (painters(tester).isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  fail('Bundled mascot textures did not decode');
}

List<PikoFramePainter> painters(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<PikoFramePainter>()
    .toList();

void main() {
  testWidgets(
    'bundled 3D frames share textures, move, rest and pause offstage/background',
    (tester) async {
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return TickerMode(
                enabled: enabled,
                child: const Row(children: [PikoMascot(), PikoMascot()]),
              );
            },
          ),
        ),
      );
      await decoded(tester);
      await tester.pump();
      expect(painters(tester), hasLength(2));
      expect(
        identical(painters(tester)[0].images, painters(tester)[1].images),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(painters(tester).first.frame, inInclusiveRange(14, 16));
      update(() => enabled = false);
      await tester.pump();
      final paused = painters(tester).first.frame;
      await tester.pump(const Duration(seconds: 5));
      expect(painters(tester).first.frame, paused);
      update(() => enabled = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(painters(tester).first.frame, greaterThan(paused));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final background = painters(tester).first.frame;
      await tester.pump(const Duration(seconds: 5));
      expect(painters(tester).first.frame, background);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(painters(tester).first.frame, 89);
      await tester.pump(const Duration(seconds: 3));
      expect(painters(tester).first.frame, 89);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(painters(tester).first.frame, lessThan(20));
      final manifest = jsonDecode(
        await tester.runAsync(
              () => rootBundle.loadString('assets/art/piko_3d/manifest.json'),
            ) ??
            '{}',
      );
      expect(manifest['maxResidentTextureBytes'], lessThan(24 * 1024 * 1024));
      for (final clip in ['idle', 'celebrate']) {
        expect(manifest['clips'][clip]['frames'], 90);
        expect(manifest['clips'][clip]['fps'], 30);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion stays static; assistive navigation preserves celebrations',
    (tester) async {
      var reduced = false, accessible = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQueryData(
                  disableAnimations: reduced,
                  accessibleNavigation: accessible,
                ),
                child: const PikoMascot(pose: PikoPose.celebrate),
              );
            },
          ),
        ),
      );
      await decoded(tester);
      await tester.pumpAndSettle();
      expect(painters(tester).single.frame, 89);
      await tester.pump(const Duration(seconds: 10));
      expect(
        painters(tester).single.frame,
        89,
        reason: 'Celebration must play once',
      );
      update(() => reduced = true);
      await tester.pumpAndSettle();
      expect(painters(tester), isEmpty);
      expect(find.byType(Image), findsOneWidget);
      update(() {
        reduced = false;
        accessible = true;
      });
      await tester.pump();
      await decoded(tester);
      await tester.pumpAndSettle();
      expect(painters(tester).single.pose, PikoPose.celebrate);
      expect(painters(tester).single.frame, 89);
      update(() => accessible = false);
      await tester.pump();
      await decoded(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(painters(tester).single.frame, 89);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Arabic small-screen completion celebrates and preserves progress',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = (await tester.runAsync(Catalog.load))!;
      final app = await makeApp(catalog);
      await app.setLanguage('ar');
      await app.setSound(false);
      final ads = AdsService(app.store, app.audio);
      final container = ProviderContainer(
        overrides: [appProvider.overrideWith((ref) => app)],
      );
      final activity = catalog.bySection['counting']!.first;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: ActivityScreen(activity: activity, ads: ads),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity-piko')), findsOneWidget);
      expect(find.byTooltip(app.t('listen')), findsOneWidget);
      tester.widget<QuizActivity>(find.byType(QuizActivity)).engine.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<PikoMascot>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(PikoMascot),
              ),
            )
            .pose,
        PikoPose.celebrate,
      );
      expect(
        tester
            .widget<PikoMascot>(find.byKey(const ValueKey('activity-piko')))
            .pose,
        PikoPose.celebrate,
      );
      expect(
        await app.store.read('results:${app.active.id}', activity.id),
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(640, 320);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      ads.dispose();
      container.dispose();
    },
  );

  testWidgets('app honors the operating system reduced-motion setting', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final catalog = (await tester.runAsync(Catalog.load))!;
    final app = await makeApp(catalog);
    final ads = AdsService(app.store, app.audio);
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
    final mascotContext = tester.element(find.byType(PikoMascot));
    expect(MediaQuery.disableAnimationsOf(mascotContext), isTrue);
    expect(painters(tester), isEmpty);
    expect(app.reducedMotion, isFalse);
    await tester.pumpWidget(const SizedBox());
    await app.flush();
    ads.dispose();
    container.dispose();
  });
}
