import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/main.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/ui/activity_screen.dart';
import 'package:pikolumi/ui/piko_mascot.dart';
import 'package:pikolumi/ui/library.dart';
import 'package:flutter/services.dart';

import 'dart:convert';

import '../test/app_test.dart' show MemoryStore, SilentAudio;
import 'capture.dart';

Future<String> imageHash(List<int> png) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(png));
  final image = (await codec.getNextFrame()).image;
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return sha256
        .convert(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        )
        .toString();
  } finally {
    image.dispose();
    codec.dispose();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('silent assistive-navigation taps and no hover/press effects', (
    tester,
  ) async {
    final app = AppController(
      catalog: await Catalog.load(),
      store: MemoryStore(),
      audio: SilentAudio(),
    );
    await app.initialize();
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
    await tester.pumpAndSettle();
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    var enabled = true;
    late StateSetter changeMotion;
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute<void>(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
              child: StatefulBuilder(
                builder: (context, setState) {
                  changeMotion = setState;
                  return TickerMode(
                    enabled: enabled,
                    child: ActivityScreen(
                      activity: app.catalog.bySection['letters']!.first,
                      ads: ads,
                    ),
                  );
                },
              ),
            ),
          ),
        );
    await tester.pumpAndSettle();
    final actor = find.byKey(const ValueKey('activity-piko'));
    final touch = find.descendant(
      of: actor,
      matching: find.byKey(const ValueKey('piko-touch')),
    );
    PikoFramePainter? painter() => tester
        .widgetList<CustomPaint>(
          find.descendant(of: actor, matching: find.byType(CustomPaint)),
        )
        .map((w) => w.painter)
        .whereType<PikoFramePainter>()
        .firstOrNull;
    expect(MediaQuery.accessibleNavigationOf(tester.element(actor)), isTrue);
    expect(MediaQuery.disableAnimationsOf(tester.element(actor)), isFalse);
    for (
      var j = 0;
      j < 50 && painter() == null;
      j++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(painter()!.pose, PikoPose.idle);
    final idleFrame = painter()!.frame;
    for (var j = 0; j < 12 && painter()!.frame == idleFrame; j++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(painter()!.frame, isNot(idleFrame));
    changeMotion(() => enabled = false);
    await tester.pumpAndSettle();
    final original = await imageHash(
      await capture(binding, 'quiet-before-tap'),
    );
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(touch));
    await tester.pump(const Duration(milliseconds: 900));
    expect(
      await imageHash(await capture(binding, 'hover-no-effect')),
      original,
    );
    // Device-source events avoid the live test runner's painted crosshair.
    final propagatePointers = binding.shouldPropagateDevicePointerEvents;
    binding.shouldPropagateDevicePointerEvents = true;
    final finger = TestGesture(
      pointer: 100,
      dispatcher: (event) async {
        binding.handlePointerEventForSource(
          event,
          source: TestBindingEventSource.device,
        );
      },
    );
    try {
      await finger.down(tester.getCenter(touch), view: tester.view);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        await imageHash(await capture(binding, 'pressed-no-effect')),
        original,
      );
      changeMotion(() => enabled = true);
      await tester.pump();
      await finger.up();
    } finally {
      binding.shouldPropagateDevicePointerEvents = propagatePointers;
    }
    await mouse.removePointer();
    final gestures = <String>[];
    for (var i = 0; i < 10; i++) {
      if (i != 0) await tester.tap(touch);
      for (
        var j = 0;
        j < 50 && (painter() == null || !painter()!.pose.reaction);
        j++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(painter(), isNotNull);
      final pose = painter()!.pose;
      expect(pose.reaction, isTrue);
      expect(gestures, isNot(contains(pose.name)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(painter()!.frame, greaterThan(5));
      await capture(binding, 'tap-${pose.name}');
      gestures.add(pose.name);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      for (
        var j = 0;
        j < 50 && (painter() == null || painter()!.pose != PikoPose.idle);
        j++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(painter()!.pose, PikoPose.idle);
    }
    expect(
      gestures.toSet(),
      PikoPose.values.where((p) => p.reaction).map((p) => p.name).toSet(),
    );
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute<void>(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
              child: LibraryHome(ads: ads),
            ),
          ),
        );
    await tester.pumpAndSettle();
    final library = find.byKey(const ValueKey('library-piko'));
    for (final language in ['fr', 'ar']) {
      await app.setLanguage(language);
      await app.setLearningLanguage(language == 'ar' ? 'en' : 'ar');
      await tester.pumpAndSettle();
      expect(
        MediaQuery.accessibleNavigationOf(tester.element(library)),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 25));
      await tester.pumpAndSettle();
      final text = tester
          .widget<Text>(find.byKey(const ValueKey('piko-invitation')))
          .data;
      expect(
        text,
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
      await capture(binding, '$language-automatic-idle-chat');
    }
    final provenance = jsonDecode(
      await rootBundle.loadString('assets/content/audio_provenance.json'),
    );
    final clips = provenance['locales']['ar']['clips'] as Map;
    var approved = 0;
    for (final entry in clips.entries) {
      if (entry.value['nativeReview']?['decision'] == 'correct') {
        final bytes = await rootBundle.load('assets/audio/ar/${entry.key}');
        final hash = sha256
            .convert(
              bytes.buffer.asUint8List(
                bytes.offsetInBytes,
                bytes.lengthInBytes,
              ),
            )
            .toString();
        expect(hash, entry.value['nativeReview']['reviewedSha256']);
        approved++;
      }
    }
    expect(approved, 54);
    expect(app.sound, isFalse);
    expect(tester.takeException(), isNull);
    binding.reportData = {
      ...?binding.reportData,
      'gestures': gestures,
      'assistiveNavigationEnabled': true,
      'disableAnimations': false,
      'tenDeliberateAnimationsVerified': true,
      'hoverPixelsUnchanged': true,
      'pressedPixelsUnchanged': true,
      'naturalIdleVerified': true,
      'automaticIdleChatsVerified': ['fr', 'ar'],
      'approvedArabicBytesVerified': approved,
      'userPreferencesChanged': false,
      'adSDKInitialized': false,
      'audio': 'SilentAudio, muted before mounting; in-memory preferences',
    };
    await tester.pumpWidget(const SizedBox());
    await app.flush();
    ads.dispose();
    container.dispose();
  });
}
