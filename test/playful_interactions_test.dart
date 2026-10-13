import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikolumi/activities/learning.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/ui/memory_card.dart';
import 'package:pikolumi/ui/piko_mascot.dart';

import 'app_test.dart' show makeApp;
import 'piko_mascot_test.dart' show decoded, painters;

void main() {
  test(
    'Piko uses all ten reactions before repeating, including bag boundaries',
    () {
      final bag = PikoShuffleBag<PikoPose>(random: math.Random(27));
      final choices = PikoPose.values.where((p) => p.reaction).toList();
      final picked = List.generate(40, (_) => bag.next(choices));
      expect(choices, hasLength(10));
      for (var i = 0; i < 40; i += 10) {
        expect(picked.sublist(i, i + 10).toSet(), choices.toSet());
      }
      for (var i = 1; i < picked.length; i++) {
        expect(picked[i], isNot(picked[i - 1]));
      }
    },
  );

  testWidgets(
    'card reveals midway, keeps its front readable and reverses smoothly',
    (tester) async {
      var faceUp = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Center(
                  child: SizedBox.square(
                    dimension: 140,
                    child: MemoryCard(
                      faceUp: faceUp,
                      matched: false,
                      face: const Text('CAT', key: ValueKey('revealed-face')),
                      onTap: () => setState(() => faceUp = !faceUp),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      double angleCosine() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(MemoryCard),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .entry(0, 0);
      await tester.tap(find.byType(MemoryCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(angleCosine(), inExclusiveRange(0, 1));
      expect(find.byKey(const ValueKey('revealed-face')), findsNothing);
      await tester.pump(const Duration(milliseconds: 180));
      expect(angleCosine(), lessThan(0));
      expect(find.byKey(const ValueKey('revealed-face')), findsOneWidget);
      final inner = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(MemoryCard),
              matching: find.byType(Transform),
            ),
          )
          .elementAt(1);
      expect(
        inner.transform.entry(0, 0),
        closeTo(-1, .001),
        reason: 'Counter-rotation prevents a mirrored front',
      );
      final before = angleCosine();
      update(() => faceUp = false);
      await tester.pump();
      expect(angleCosine(), closeTo(before, .001));
      await tester.pumpAndSettle();
      expect(angleCosine(), closeTo(1, .001));
      expect(find.byKey(const ValueKey('revealed-face')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'memory locks during reveal and conceal, saves matches and restores face up',
    (tester) async {
      final catalog = (await tester.runAsync(Catalog.load))!;
      final app = await makeApp(catalog);
      await app.setSound(false);
      final activity = catalog.bySection['memory']!.first;
      Map<String, dynamic>? saved;
      var completions = 0;
      final engine = EngineContext(
        activity: activity,
        app: app,
        complete: () => completions++,
        resume: null,
        save: (value) => saved = value,
      );
      final pairs = (engine.config['pairs'] as List).cast<String>();
      final deck = [...pairs, ...pairs]
        ..shuffle(math.Random(engine.config['layout']));
      Future<void> mount(Map<String, dynamic>? resume) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MemoryActivity(
                key: UniqueKey(),
                engine: EngineContext(
                  activity: activity,
                  app: app,
                  complete: () => completions++,
                  resume: resume,
                  save: (value) => saved = value,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      MemoryCard card(int i) =>
          tester.widget<MemoryCard>(find.byKey(ValueKey('memory-$i')));
      await mount(null);
      final a = 0, b = deck.indexWhere((p) => p != deck[a]);
      final third = List.generate(
        deck.length,
        (i) => i,
      ).firstWhere((i) => i != a && i != b);
      await tester.tap(find.byKey(ValueKey('memory-$a')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('memory-$b')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('memory-$third')));
      await tester.pump();
      expect(card(third).faceUp, isFalse);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(card(a).faceUp, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(card(a).faceUp, isFalse);
      await tester.tap(find.byKey(ValueKey('memory-$third')));
      await tester.pump();
      expect(
        card(third).faceUp,
        isFalse,
        reason: 'Concealing cards still lock the board',
      );
      await tester.pump(const Duration(milliseconds: 430));
      final partner = deck.lastIndexOf(deck[a]);
      await tester.tap(find.byKey(ValueKey('memory-$a')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('memory-$partner')));
      await tester.pump(const Duration(milliseconds: 700));
      expect(saved!['matched'], containsAll([a, partner]));
      expect(completions, 0);
      await mount(saved);
      expect(card(a).matched && card(a).faceUp, isTrue);
      expect(card(a).onTap, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'tap reactions ignore rapid taps, pause in background and return to idle',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PikoMascot())),
      );
      await decoded(tester);
      await tester.pump();
      await tester.tap(find.byType(PikoMascot));
      await tester.pump();
      await decoded(tester);
      await tester.pump();
      final pose = painters(tester).single.pose;
      expect(pose.reaction, isTrue);
      expect(painters(tester).single.frameCount, 60);
      await tester.tap(find.byType(PikoMascot));
      await tester.pump();
      expect(painters(tester).single.pose, pose);
      await tester.pump(const Duration(milliseconds: 400));
      expect(painters(tester).single.frame, greaterThan(5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final paused = painters(tester).single.frame;
      await tester.pump(const Duration(seconds: 3));
      expect(painters(tester).single.frame, paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await decoded(tester);
      await tester.pump();
      expect(painters(tester).single.pose, PikoPose.idle);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all bundled reaction clips decode and finish at their own frame counts',
    (tester) async {
      for (final pose in PikoPose.values.where((p) => p.reaction)) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PikoMascot(key: ValueKey(pose), pose: pose),
            ),
          ),
        );
        await decoded(tester);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(painters(tester).single.frame, 59);
        expect(painters(tester).single.images, hasLength(1));
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invites use UI language, expire, stop offstage and respect reduced motion',
    (tester) async {
      final catalog = (await tester.runAsync(Catalog.load))!;
      final app = await makeApp(catalog);
      var enabled = true, reduced = false;
      late StateSetter update;
      for (final language in ['en', 'fr', 'es', 'pt', 'ar']) {
        await app.setLanguage(language);
        await app.setLearningLanguage(language == 'ar' ? 'en' : 'ar');
        final messages = [
          for (final k in [
            'pikoInviteColor',
            'pikoInviteMemory',
            'pikoInvitePuzzle',
            'pikoInviteNumbers',
            'pikoInviteDraw',
          ])
            app.t(k),
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                key: ValueKey(language),
                builder: (context, setState) {
                  update = setState;
                  return MediaQuery(
                    data: MediaQueryData(disableAnimations: reduced),
                    child: TickerMode(
                      enabled: enabled,
                      child: PikoMascot(
                        size: 100,
                        invitations: messages,
                        semanticLabel: app.t('pikoPlay'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await decoded(tester);
        await tester.pump();
        await tester.pump(const Duration(seconds: 25));
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('piko-invitation')))
              .data,
          isIn(messages),
        );
        await tester.pump(const Duration(seconds: 6));
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('piko-invitation')))
              .data,
          '',
        );
        update(() => enabled = false);
        await tester.pump();
        await tester.pump(const Duration(seconds: 90));
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('piko-invitation')))
              .data,
          '',
        );
        update(() {
          enabled = true;
          reduced = true;
        });
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 90));
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('piko-invitation')))
              .data,
          '',
        );
        await tester.tap(
          find.descendant(
            of: find.byType(PikoMascot),
            matching: find.byKey(const ValueKey('piko-touch')),
          ),
        );
        await tester.pumpAndSettle();
        expect(painters(tester), isEmpty);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('piko-invitation')))
              .data,
          isIn(messages),
        );
        await tester.pumpWidget(const SizedBox());
        enabled = true;
        reduced = false;
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion switches memory faces without a turn', (
    tester,
  ) async {
    var up = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SizedBox.square(
                dimension: 120,
                child: MemoryCard(
                  faceUp: up,
                  matched: false,
                  face: const Text('FACE'),
                  onTap: () => setState(() => up = !up),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(MemoryCard));
    await tester.pump();
    expect(find.text('FACE'), findsOneWidget);
    final turn = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(MemoryCard),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(turn.transform.entry(0, 0), closeTo(-1, .001));
  });
}
