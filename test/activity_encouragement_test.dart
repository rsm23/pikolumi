import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikolumi/activities/learning.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/main.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/ui/activity_encouragement.dart';
import 'package:pikolumi/ui/activity_screen.dart';
import 'package:pikolumi/ui/piko_speech_bubble.dart';

import 'app_test.dart' show makeApp;

void main() {
  testWidgets('100 localized messages cycle without repeats at reshuffle', (
    tester,
  ) async {
    final catalog = (await tester.runAsync(Catalog.load))!;
    for (final language in ['en', 'fr', 'es', 'pt', 'ar']) {
      final texts = [
        for (final key in CompletionEncouragement.keys)
          localized(catalog.strings[key], language),
      ];
      expect(texts.every((text) => text.trim().isNotEmpty), isTrue);
      expect(texts.toSet(), hasLength(100));
    }
    final messages = CompletionEncouragement(random: math.Random(42));
    String? previous;
    for (var cycle = 0; cycle < 4; cycle++) {
      final seen = <String>{};
      for (var i = 0; i < 100; i++) {
        final key = messages.nextKey();
        expect(key, isNot(previous));
        expect(seen.add(key), isTrue);
        previous = key;
      }
      expect(seen, CompletionEncouragement.keys.toSet());
    }
  });

  testWidgets('foreground pause, interaction, expiry and cooldown', (
    tester,
  ) async {
    final prompts = ActivityEncouragement()..setActive(true);
    await tester.pump(const Duration(seconds: 44));
    expect(prompts.messageKey, isNull);
    prompts.interact();
    await tester.pump(const Duration(seconds: 44));
    expect(prompts.messageKey, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(prompts.messageKey, isIn(ActivityEncouragement.helpKeys));
    final first = prompts.messageKey;
    await tester.pump(ActivityEncouragement.displayTime);
    expect(prompts.messageKey, isNull);
    for (var i = 0; i < 10; i++) {
      prompts.mistake();
    }
    expect(prompts.messageKey, isNull);
    await tester.pump(const Duration(seconds: 80));
    await tester.pump(ActivityEncouragement.idleDelay);
    expect(prompts.messageKey, isNot(first));
    prompts.dispose();
  });

  testWidgets('progress clears unsuccessful tries; background resets grace', (
    tester,
  ) async {
    final prompts = ActivityEncouragement()..setActive(true);
    prompts.mistake();
    prompts.mistake();
    prompts.progress();
    prompts.mistake();
    expect(prompts.messageKey, isNull);
    prompts.mistake();
    prompts.mistake();
    expect(prompts.messageKey, isNotNull);
    prompts.setActive(false);
    expect(prompts.messageKey, isNull);
    await tester.pump(const Duration(minutes: 10));
    prompts.setActive(true);
    await tester.pump(const Duration(seconds: 44));
    expect(prompts.messageKey, isNull);
    prompts.finish();
    prompts.setActive(true);
    await tester.pump(const Duration(minutes: 10));
    expect(prompts.messageKey, isNull);
    prompts.dispose();
  });

  testWidgets(
    'creative pauses use kind invitations and active drawing stays quiet',
    (tester) async {
      final prompts = ActivityEncouragement(creative: true)..setActive(true);
      for (var i = 0; i < 8; i++) {
        prompts.mistake();
        await tester.pump(const Duration(seconds: 10));
        prompts.interact();
      }
      expect(prompts.messageKey, isNull);
      await tester.pump(ActivityEncouragement.idleDelay);
      expect(prompts.messageKey, isIn(ActivityEncouragement.creativeKeys));
      prompts.dispose();
    },
  );

  for (final language in ['en', 'fr', 'es', 'pt', 'ar']) {
    testWidgets(
      '$language level and completion bubbles use UI language, stable targets and safe rotation',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final catalog = (await tester.runAsync(Catalog.load))!;
        final app = await makeApp(catalog);
        await app.setSound(false);
        await app.setMotion(true);
        await app.setLanguage(language);
        await app.setLearningLanguage(language == 'ar' ? 'en' : 'ar');
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
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        final activity = catalog.bySection['letters']!.first;
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityScreen(activity: activity, ads: ads),
          ),
        );
        await tester.pumpAndSettle();
        final body = find.byKey(const ValueKey('activity-body'));
        final original = tester.getRect(body);
        await tester.pump(const Duration(seconds: 46));
        expect(
          find.byKey(const ValueKey('activity-encouragement')),
          findsOneWidget,
        );
        final bubble = tester.widget<PikoSpeechBubble>(
          find.byKey(const ValueKey('activity-encouragement')),
        );
        expect(
          bubble.message,
          isIn([for (final key in ActivityEncouragement.helpKeys) app.t(key)]),
        );
        expect(tester.getRect(body), original);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('activity-encouragement')))
              .bottom,
          lessThanOrEqualTo(original.top),
        );
        expect(
          Directionality.of(tester.element(body)),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        // A paused Flutter engine does not paint another frame until resumed.
        await tester.pump(const Duration(minutes: 5));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('activity-encouragement')),
          findsNothing,
        );
        tester
            .widget<QuizActivity>(find.byType(QuizActivity))
            .engine
            .complete();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PikoSpeechBubble>(
                find.byKey(const ValueKey('completion-encouragement')),
              )
              .message,
          isIn([for (final key in CompletionEncouragement.keys) app.t(key)]),
        );
        final completionMessage = tester
            .widget<PikoSpeechBubble>(
              find.byKey(const ValueKey('completion-encouragement')),
            )
            .message;
        // A duplicate completion callback must not reroll the visible message.
        tester
            .widget<QuizActivity>(find.byType(QuizActivity))
            .engine
            .complete();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PikoSpeechBubble>(
                find.byKey(const ValueKey('completion-encouragement')),
              )
              .message,
          completionMessage,
        );
        expect(app.isCompleted(activity), isTrue);
        expect(tester.takeException(), isNull);
        tester.view.physicalSize = const Size(640, 320);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PikoSpeechBubble>(
                find.byKey(const ValueKey('completion-encouragement')),
              )
              .message,
          completionMessage,
        );
        expect(find.text(app.t('continue')).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(app.t('continue')));
        await tester.pumpAndSettle();
        expect(find.byType(ActivityScreen), findsNothing);
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityScreen(activity: activity, ads: ads),
          ),
        );
        await tester.pumpAndSettle();
        tester
            .widget<QuizActivity>(find.byType(QuizActivity))
            .engine
            .complete();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PikoSpeechBubble>(
                find.byKey(const ValueKey('completion-encouragement')),
              )
              .message,
          isNot(completionMessage),
        );
        await tester.tap(find.text(app.t('continue')));
        await tester.pumpAndSettle();
        expect(app.sound, isFalse);
        await tester.pumpWidget(const SizedBox());
        await app.flush();
        ads.dispose();
        container.dispose();
      },
    );
  }
}
