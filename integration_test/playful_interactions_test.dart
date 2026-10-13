import 'dart:io';

import 'capture.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/activities/learning.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/main.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/ui/activity_screen.dart';
import 'package:pikolumi/ui/memory_card.dart';
import 'package:pikolumi/ui/piko_mascot.dart';

import '../test/app_test.dart' show MemoryStore, SilentAudio;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('silent Piko reactions, localized bubbles and memory turns', (
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
    final library = find.byKey(const ValueKey('library-piko'));
    PikoFramePainter? painter(Finder actor) {
      final paints = tester.widgetList<CustomPaint>(
        find.descendant(of: actor, matching: find.byType(CustomPaint)),
      );
      return paints
          .map((p) => p.painter)
          .whereType<PikoFramePainter>()
          .firstOrNull;
    }

    Future<PikoFramePainter> reaction(Finder actor) async {
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final value = painter(actor);
        if (value != null && value.pose.reaction) return value;
      }
      fail('Piko tap did not produce a decoded reaction');
    }

    await capture(binding, 'library-piko');
    final gestures = <String>[];
    for (var i = 0; i < 10; i++) {
      final tap = find.descendant(
        of: library,
        matching: find.byKey(const ValueKey('piko-touch')),
      );
      await tester.tap(tap);
      final start = await reaction(library);
      final first = start.frame;
      await tester.pump(const Duration(milliseconds: 400));
      expect(painter(library)!.frame, greaterThan(first));
      final name = start.pose.name;
      expect(gestures, isNot(contains(name)));
      gestures.add(name);
      await capture(binding, 'gesture-$name');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }
    expect(
      gestures.toSet(),
      PikoPose.values.where((p) => p.reaction).map((p) => p.name).toSet(),
    );
    // Language change starts a fresh idle-invitation schedule.
    await app.setLanguage('fr');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 25));
    final automatic = tester
        .widget<Text>(find.byKey(const ValueKey('piko-invitation')))
        .data;
    expect(automatic, isNotEmpty);
    await capture(binding, 'automatic-idle-invitation-fr');
    final locales = <String>[];
    for (final language in ['en', 'fr', 'es', 'pt', 'ar']) {
      await app.setLanguage(language);
      await app.setLearningLanguage(language == 'ar' ? 'en' : 'ar');
      await app.setMotion(true);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: library,
          matching: find.byKey(const ValueKey('piko-touch')),
        ),
      );
      await tester.pumpAndSettle();
      final message = tester
          .widget<Text>(find.byKey(const ValueKey('piko-invitation')))
          .data;
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
      await capture(binding, '$language-localized-invitation');
      await app.setMotion(false);
      await tester.pumpAndSettle();
      final activity = app.catalog.bySection['memory']!.first;
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ActivityScreen(activity: activity, ads: ads),
        ),
      );
      await tester.pumpAndSettle();
      if (language == 'en') {
        final header = find.byKey(const ValueKey('activity-piko'));
        await tester.tap(
          find.descendant(
            of: header,
            matching: find.byKey(const ValueKey('piko-touch')),
          ),
        );
        await reaction(header);
        await tester.pump(const Duration(milliseconds: 450));
        await capture(binding, 'activity-header-reaction');
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      }
      final memory = tester.widget<MemoryActivity>(find.byType(MemoryActivity));
      final cfg = memory.engine.config;
      final pairs = (cfg['pairs'] as List).cast<String>();
      final deck = [...pairs, ...pairs]..shuffle(math.Random(cfg['layout']));
      MemoryCard card(int i) =>
          tester.widget<MemoryCard>(find.byKey(ValueKey('memory-$i')));
      final a = 0, b = deck.indexWhere((p) => p != deck[0]);
      final third = List.generate(
        deck.length,
        (i) => i,
      ).firstWhere((i) => i != a && i != b);
      await tester.tap(find.byKey(ValueKey('memory-$a')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 175));
      final turn = tester.widget<Transform>(
        find
            .descendant(
              of: find.byKey(ValueKey('memory-$a')),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(turn.transform.entry(0, 0).abs(), lessThan(.999));
      await capture(binding, '$language-memory-turn');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('memory-$b')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('memory-$third')));
      await tester.pump();
      expect(card(third).faceUp, isFalse);
      await tester.pump(const Duration(milliseconds: 1800));
      expect(card(a).faceUp, isFalse);
      for (final picture in pairs) {
        final left = deck.indexOf(picture), right = deck.lastIndexOf(picture);
        await tester.tap(find.byKey(ValueKey('memory-$left')));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey('memory-$right')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
      }
      for (
        var i = 0;
        i < 40 && find.byType(AlertDialog).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.pumpAndSettle();
      await capture(binding, '$language-memory-completion');
      expect(app.isCompleted(activity), isTrue);
      expect(app.sound, isFalse);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(app.t('continue')));
      await tester.pumpAndSettle();
      locales.add(language);
    }
    binding.reportData = {
      ...?binding.reportData,
      'locales': locales,
      'gestures': gestures,
      'memoryTurnVerified': true,
      'mismatchTapLockVerified': true,
      'memoryCompletionVerified': true,
      'automaticInvitationVerified': true,
      'interfaceLanguageInvitationsVerified': true,
      'headerTapVerified': true,
      'reducedMotionVerified': true,
      'audio': 'SilentAudio; sound disabled before mounting',
      'userPreferencesChanged': false,
      'adSDKInitialized': false,
    };
    await tester.pumpWidget(const SizedBox());
    await app.flush();
    ads.dispose();
    container.dispose();
  });
}
