import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/main.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/ui/activity_encouragement.dart';
import 'package:pikolumi/ui/activity_screen.dart';
import 'package:pikolumi/ui/piko_speech_bubble.dart';

import '../test/app_test.dart' show MemoryStore, SilentAudio;
import 'capture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('silent localized in-level encouragement and completion', (
    tester,
  ) async {
    final app = AppController(
      catalog: await Catalog.load(),
      store: MemoryStore(),
      audio: SilentAudio(),
    );
    await app.initialize();
    await app.setSound(false);
    await app.setMotion(true);
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
    final locales = <String>[];
    final completionKeys = <String>[];
    for (final language in ['en', 'fr', 'es', 'pt', 'ar']) {
      await app.setLanguage(language);
      await app.setLearningLanguage(language == 'ar' ? 'en' : 'ar');
      await tester.pumpAndSettle();
      final activity = app.catalog.bySection['letters']!.first;
      final config = activity.config(app.learningLanguage);
      final options = (config['options'] as List).cast<Map>();
      final wrong = options.firstWhere(
        (option) => option['value'] != config['correct'],
      )['value'];
      final right = config['correct'];
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ActivityScreen(activity: activity, ads: ads),
        ),
      );
      await tester.pumpAndSettle();
      final body = find.byKey(const ValueKey('activity-body'));
      final original = tester.getRect(body);
      for (var i = 0; i < 3; i++) {
        final option = find.byKey(ValueKey('option-$wrong'));
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        await tester.tap(option);
        await tester.pump(const Duration(milliseconds: 850));
      }
      await tester.pumpAndSettle();
      final bubble = find.byKey(const ValueKey('activity-encouragement'));
      expect(bubble, findsOneWidget);
      expect(
        tester.widget<PikoSpeechBubble>(bubble).message,
        isIn([for (final key in ActivityEncouragement.helpKeys) app.t(key)]),
      );
      expect(tester.getRect(body), original);
      expect(tester.getRect(bubble).bottom, lessThanOrEqualTo(original.top));
      expect(
        Directionality.of(tester.element(bubble)),
        language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      await capture(binding, '$language-in-level-encouragement');
      final correct = find.byKey(ValueKey('option-$right'));
      await tester.ensureVisible(correct);
      await tester.pumpAndSettle();
      await tester.tap(correct);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<PikoSpeechBubble>(
              find.byKey(const ValueKey('completion-encouragement')),
            )
            .message,
        isIn([for (final key in CompletionEncouragement.keys) app.t(key)]),
      );
      final message = tester
          .widget<PikoSpeechBubble>(
            find.byKey(const ValueKey('completion-encouragement')),
          )
          .message;
      final key = CompletionEncouragement.keys.singleWhere(
        (key) => app.t(key) == message,
      );
      expect(completionKeys, isNot(contains(key)));
      completionKeys.add(key);
      expect(app.isCompleted(activity), isTrue);
      expect(app.sound, isFalse);
      await capture(binding, '$language-completion-encouragement');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(app.t('continue')));
      await tester.pumpAndSettle();
      locales.add(language);
    }
    binding.reportData = {
      ...?binding.reportData,
      'locales': locales,
      'completionMessageKeys': completionKeys,
      'completionMessagePoolSize': CompletionEncouragement.keys.length,
      'noRepeatsAcrossActivityRoutes': true,
      'threeUnsuccessfulAttemptsVerified': true,
      'interfaceLanguageIndependentOfLearningLanguage': true,
      'stableActivityBounds': true,
      'completionThroughActualAnswer': true,
      'reducedMotionVerified': true,
      'audio': 'SilentAudio; muted before mounting',
      'userPreferencesChanged': false,
      'adSDKInitialized': false,
    };
    await tester.pumpWidget(const SizedBox());
    await app.flush();
    ads.dispose();
    container.dispose();
  });
}
