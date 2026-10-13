import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/main.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/ui/piko_mascot.dart';

import 'piko_mascot_test.dart' show decoded, painters;
import 'app_test.dart' show makeApp;

void main() {
  testWidgets(
    'assistive navigation allows natural idle, tap reactions and return to idle',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(accessibleNavigation: true),
            child: Scaffold(body: Center(child: PikoMascot())),
          ),
        ),
      );
      await decoded(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(painters(tester).single.pose, PikoPose.idle);
      expect(painters(tester).single.frame, greaterThan(5));
      await tester.tap(find.byType(PikoMascot));
      await tester.pump();
      await decoded(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(painters(tester).single.pose.reaction, isTrue);
      expect(painters(tester).single.frame, greaterThan(5));
      await tester.pump(const Duration(seconds: 2));
      await decoded(tester);
      expect(painters(tester).single.pose, PikoPose.idle);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('hover and held touch paint no rectangle, circle or tooltip', (
    tester,
  ) async {
    final imageKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: imageKey,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: Center(child: PikoMascot(size: 150))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<List<int>> pixels() async => (await tester.runAsync(() async {
      final boundary =
          imageKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        return bytes.buffer
            .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes)
            .toList();
      } finally {
        image.dispose();
      }
    }))!;
    final original = await pixels();
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(PikoMascot)));
    await tester.pump(const Duration(seconds: 1));
    expect(await pixels(), original);
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(PikoMascot)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(await pixels(), original);
    await finger.up();
    await mouse.removePointer();
    await tester.pumpAndSettle();
    expect(find.byType(Tooltip), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('keyboard activation works without ink feedback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: PikoMascot())),
      ),
    );
    await decoded(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await decoded(tester);
    expect(painters(tester).single.pose.reaction, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'idle invitations keep all five UI languages under assistive navigation',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final app = await makeApp((await tester.runAsync(Catalog.load))!);
      await app.setSound(false);
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
      await decoded(tester);
      expect(
        MediaQuery.accessibleNavigationOf(
          tester.element(find.byType(PikoMascot)),
        ),
        isTrue,
      );
      for (final language in ['en', 'fr', 'es', 'pt', 'ar']) {
        await app.setLanguage(language);
        await app.setLearningLanguage(language == 'ar' ? 'en' : 'ar');
        await tester.pump();
        await tester.pump(const Duration(seconds: 25));
        await tester.pump(const Duration(milliseconds: 300));
        final bubble = find.byKey(const ValueKey('piko-invitation'));
        final message = tester.widget<Text>(bubble).data;
        expect(
          message,
          isIn([
            for (final key in [
              'pikoInviteColor',
              'pikoInviteMemory',
              'pikoInvitePuzzle',
              'pikoInviteNumbers',
              'pikoInviteDraw',
            ])
              app.t(key),
          ]),
        );
        await tester.pump(const Duration(seconds: 7));
        expect(
          tester.widget<Text>(bubble).data,
          message,
          reason: 'Assistive navigation gives more time to read',
        );
      }
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      ads.dispose();
      container.dispose();
    },
  );
}
