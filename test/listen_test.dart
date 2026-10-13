import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/ui/activity_screen.dart';

import 'app_test.dart' show MemoryStore, SilentAudio;

class RequestedAudio extends SilentAudio {
  final calls = <(String, String)>[];
  @override
  Future<void> play(String language, String file) async {
    if (enabled && active) calls.add((language, file));
  }
}

void main() {
  testWidgets(
    'Listen resumes when sound is enabled and keeps the learning language separate',
    (tester) async {
      final catalog = (await tester.runAsync(Catalog.load))!;
      for (final locale in ['en', 'fr', 'es', 'pt', 'ar']) {
        final store = MemoryStore();
        final audio = RequestedAudio();
        final app = AppController(catalog: catalog, store: store, audio: audio);
        await app.initialize();
        await app.setLanguage(locale);
        await app.setLearningLanguage('ar');
        await app.setSound(false);
        final ads = AdsService(store, audio);
        final container = ProviderContainer(
          overrides: [appProvider.overrideWith((ref) => app)],
        );
        for (final section in ['counting', 'letters', 'words', 'music']) {
          final activity = catalog.bySection[section]!.first;
          await app.setSound(false);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: ActivityScreen(activity: activity, ads: ads),
              ),
            ),
          );
          await tester.pumpAndSettle();
          audio.calls.clear();
          await tester.tap(find.byTooltip(app.t('listen')));
          await tester.pump();
          expect(find.text(app.t('soundOffHelp')), findsOneWidget);
          expect(audio.calls, isEmpty);
          if (activity.config(app.activityLanguage(activity))['spokenOnly'] ==
              true) {
            final inner = find.text(app.t('listen'));
            await tester.ensureVisible(inner);
            await tester.pumpAndSettle();
            await tester.tap(inner);
            await tester.pump();
            expect(find.text(app.t('soundOffHelp')), findsOneWidget);
            expect(audio.calls, isEmpty);
          }
          if (section == 'music') {
            final replay = find.text(app.t('listenAgain'));
            await tester.ensureVisible(replay);
            await tester.pumpAndSettle();
            await tester.tap(replay);
            await tester.pump();
            expect(find.text(app.t('soundOffHelp')), findsOneWidget);
          }
          await app.setSound(true);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(app.t('listen')));
          await tester.pump();
          final language = app.activityLanguage(activity);
          final cue = activity.cue(language);
          expect(audio.calls.last, (
            cue == null ? locale : language,
            cue ?? activity.audio,
          ));
          expect(app.language, locale);
          expect(app.learningLanguage, 'ar');
          await tester.pumpWidget(const SizedBox());
          await app.flush();
        }
        final restored = AppController(
          catalog: catalog,
          store: store,
          audio: RequestedAudio(),
        );
        await restored.initialize();
        expect(restored.sound, isTrue);
        expect(restored.audio.enabled, isTrue);
        restored.dispose();
        ads.dispose();
        container.dispose();
      }
    },
  );
  testWidgets(
    'muted Listen explains the saved mute instead of silently ignoring taps',
    (tester) async {
      final catalog = (await tester.runAsync(Catalog.load))!;
      final audio = RequestedAudio();
      final app = AppController(
        catalog: catalog,
        store: MemoryStore(),
        audio: audio,
      );
      await app.initialize();
      await app.setSound(false);
      final ads = AdsService(app.store, audio);
      final container = ProviderContainer(
        overrides: [appProvider.overrideWith((ref) => app)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ActivityScreen(
              activity: catalog.bySection['letters']!.first,
              ads: ads,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(app.t('listen')));
      await tester.pump();
      expect(
        find.text(
          'Sound is off. Ask a grown-up to turn on Sound & voice in the parent area.',
        ),
        findsOneWidget,
      );
      expect(audio.calls, isEmpty);
      expect(app.sound, isFalse);
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      ads.dispose();
      container.dispose();
    },
  );
}
