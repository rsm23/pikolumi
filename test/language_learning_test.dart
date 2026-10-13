import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikolumi/activities/learning.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/services/store_native.dart';
import 'package:pikolumi/ui/activity_screen.dart';
import 'package:pikolumi/ui/parent_area.dart';

import 'app_test.dart' show MemoryStore, SilentAudio;

class RecordingAudio extends SilentAudio {
  final calls = <(String, String)>[];
  @override
  Future<void> play(String language, String file) async {
    calls.add((language, file));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Catalog catalog;
  setUpAll(() async => catalog = await Catalog.load());

  test('learning language, progress and resume survive SQLite reopening and sibling changes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pikolumi-languages-',
    );
    final file = File('${directory.path}/state.sqlite');
    final store = NativeRecordStore(NativeDatabase(file));
    final app = AppController(
      catalog: catalog,
      store: store,
      audio: SilentAudio(),
    );
    await app.initialize();
    final firstExplorer = app.active;
    final letters = catalog.bySection['letters']!.first;
    await app.setLearningLanguage('ar');
    await app.setLanguage('fr');
    await app.complete(letters);
    await app.saveResume(letters.id, {'selected': 'ا'});
    await app.setLearningLanguage('es');
    expect(app.isCompleted(letters), isFalse);
    expect(await app.resume(letters.id), isNull);
    expect(app.earnedCompletions, 1);
    await app.saveResume(letters.id, {'selected': 'A'});
    await app.addProfile(2, 1);
    await app.setLearningLanguage('pt');
    expect(app.isCompleted(letters), isFalse);
    await app.selectProfile(firstExplorer);
    expect(app.learningLanguage, 'es');
    await app.clearResume(letters.id);
    await app.setLearningLanguage('ar');
    expect((await app.resume(letters.id))!['selected'], 'ا');
    await app.setLanguage('en');
    expect(app.learningLanguage, 'ar');
    expect(app.isCompleted(letters), isTrue);
    app.dispose();
    await store.close();
    final reopened = NativeRecordStore(NativeDatabase(file));
    final restored = AppController(
      catalog: catalog,
      store: reopened,
      audio: SilentAudio(),
    );
    await restored.initialize();
    expect(restored.language, 'en');
    expect(restored.learningLanguage, 'ar');
    expect(restored.isCompleted(letters), isTrue);
    expect((await restored.resume(letters.id))!['selected'], 'ا');
    expect(restored.profiles.last.learningLanguage, 'pt');
    restored.dispose();
    await reopened.close();
    await directory.delete(recursive: true);
  });

  test('legacy language lesson saves migrate once without losing other activity saves', () async {
    final store = MemoryStore();
    await store.write(
      'settings',
      'app',
      jsonEncode({
        'language': 'fr',
        'active': 'explorer-1',
        'profiles': [
          {'id': 'explorer-1', 'avatar': 0, 'stage': 0},
        ],
      }),
    );
    await store.write(
      'results:explorer-1',
      'letters-0001',
      '{"completed":true,"attempts":3}',
    );
    await store.write(
      'resume:explorer-1',
      'tracing-0001',
      '{"stroke":1,"at":7}',
    );
    await store.write('resume:explorer-1', 'mazes-0001', '{"position":5}');
    final app = AppController(
      catalog: catalog,
      store: store,
      audio: SilentAudio(),
    );
    await app.initialize();
    expect(app.isCompleted(catalog.byId['letters-0001']!), isTrue);
    expect((await app.resume('tracing-0001'))!['at'], 7);
    expect((await app.resume('mazes-0001'))!['position'], 5);
    await app.setLearningLanguage('ar');
    expect(await app.resume('tracing-0001'), isNull);
    expect(app.completed, 0);
    await app.setLearningLanguage('fr');
    expect(app.results['letters-0001@fr']['attempts'], 3);
    final reopened = AppController(
      catalog: catalog,
      store: store,
      audio: SilentAudio(),
    );
    await reopened.initialize();
    expect((await reopened.resume('tracing-0001'))!['at'], 7);
    expect((await store.list('results:explorer-1')).length, 1);
    app.dispose();
    reopened.dispose();
  });

  testWidgets(
    'all 25 interface/learning pairs use target vocabulary and spelling with interface controls',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const words = {
        'en': 'cat',
        'fr': 'chat',
        'es': 'gato',
        'pt': 'gato',
        'ar': 'قطة',
      };
      final app = AppController(
        catalog: catalog,
        store: MemoryStore(),
        audio: SilentAudio(),
      );
      await app.initialize();
      await app.setSound(false);
      for (final ui in words.keys) {
        await app.setLanguage(ui);
        for (final target in words.keys) {
          await app.setLearningLanguage(target);
          var completions = 0;
          EngineContext engine(Activity activity) => EngineContext(
            activity: activity,
            app: app,
            complete: () => completions++,
            resume: null,
            save: (_) {},
          );
          Future<void> mount(Widget child) async {
            await tester.pumpWidget(
              MaterialApp(
                locale: Locale(ui),
                supportedLocales: words.keys.map(Locale.new).toList(),
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: Scaffold(body: child),
              ),
            );
            await tester.pumpAndSettle();
          }

          await mount(
            QuizActivity(engine: engine(catalog.bySection['words']!.first)),
          );
          expect(
            find.text(words[target]!),
            findsOneWidget,
            reason: '$ui interface / $target learning',
          );
          expect(find.text(app.t('hint')), findsOneWidget);
          final option = tester.widget<Text>(find.text(words[target]!));
          expect(
            option.style!.fontFamily,
            target == 'ar' ? 'NotoSansArabic' : 'Nunito',
          );
          final spelling = catalog.bySection['words']!.firstWhere(
            (a) => a.engine == 'sequence',
          );
          await mount(
            WordActivity(
              key: ValueKey('$ui-$target'),
              engine: engine(spelling),
            ),
          );
          for (final char in words[target]!.characters) {
            final key = find.byKey(ValueKey('letter-$char'));
            await tester.ensureVisible(key);
            await tester.tap(key);
            await tester.pump();
          }
          expect(completions, 1);
          final progress = tester.widget<Text>(
            find.byKey(const ValueKey('word-progress')),
          );
          expect(progress.data, words[target]);
          expect(
            progress.textDirection,
            target == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );

  testWidgets(
    'English questions teach Arabic and French guidance replays an Arabic cue',
    (tester) async {
      final store = MemoryStore(), audio = RecordingAudio();
      final app = AppController(catalog: catalog, store: store, audio: audio);
      await app.initialize();
      await app.setLearningLanguage('ar');
      final forms = catalog.bySection['letters']![29];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizActivity(
              engine: EngineContext(
                activity: forms,
                app: app,
                complete: () {},
                resume: null,
                save: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Which letter do these forms show?'), findsOneWidget);
      expect(find.byKey(const ValueKey('option-ب')), findsOneWidget);
      await app.setLanguage('fr');
      final ads = AdsService(store, audio);
      final named = catalog.bySection['letters']!.first;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => app)],
          child: MaterialApp(
            home: ActivityScreen(activity: named, ads: ads),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Écoute le nom de la lettre et choisis-la.'),
        findsOneWidget,
      );
      expect(audio.calls, contains(('fr', 'letters.mp3')));
      await tester.tap(find.byIcon(Icons.volume_up_outlined));
      await tester.pump();
      expect(audio.calls.last, ('ar', 'letter_0.mp3'));
      await tester.pumpWidget(const SizedBox());
      ads.dispose();
    },
  );

  testWidgets(
    'parent learning-language choice leaves interface language intact',
    (tester) async {
      final store = MemoryStore(), audio = SilentAudio();
      final app = AppController(catalog: catalog, store: store, audio: audio);
      await app.initialize();
      await app.setLanguage('fr');
      final ads = AdsService(store, audio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => app)],
          child: MaterialApp(home: ParentArea(ads: ads)),
        ),
      );
      await tester.pumpAndSettle();
      final choice = find.byKey(const ValueKey('learning-language-ar'));
      await tester.scrollUntilVisible(
        choice,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(app.language, 'fr');
      expect(app.learningLanguage, 'ar');
      expect(tester.widget<ChoiceChip>(choice).selected, isTrue);
      await tester.pumpWidget(const SizedBox());
      ads.dispose();
    },
  );
}
