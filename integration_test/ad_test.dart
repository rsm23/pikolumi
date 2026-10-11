import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/main.dart' as production;
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/services/ad_budget.dart';
import 'package:pikolumi/ui/library.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'test banner, interstitial close callback and silent restoration',
    (tester) async {
      await production.main();
      await tester.pumpAndSettle();
      final state = tester.state<ConsumerState>(find.byType(LibraryHome));
      final app = state.ref.read(appProvider);
      final ads = tester.widget<LibraryHome>(find.byType(LibraryHome)).ads;
      await app.setSound(false);
      expect(
        ads.production,
        isFalse,
        reason: 'This harness may never show production ads.',
      );
      for (
        var i = 0;
        i < 60 &&
            (!ads.hasLoadedInterstitial ||
                find.byType(AdWidget).evaluate().isEmpty);
        i++
      ) {
        await tester.pump(const Duration(seconds: 1));
      }
      await ads.synchronizeSound();
      expect(ads.ready, isTrue);
      expect(find.byType(AdWidget), findsOneWidget);
      expect(ads.hasLoadedInterstitial, isTrue);
      ads.enterActivity();
      await tester.pump();
      await tester.pump();
      expect(find.byType(AdWidget), findsNothing);
      final original = AdBudget.fromJson(ads.budget.toJson());
      addTearDown(() async {
        ads.budget = original;
        await ads.checkpoint();
        ads.leaveActivity();
      });
      ads.budget = AdBudget(foregroundMs: 300000, completions: 4);
      var returned = false;
      unawaited(ads.afterCompletion().then((_) => returned = true));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      expect(ads.presenting, isTrue);
      // Native ad controls are closed manually through Simulator UI during this QA run.
      await tester.runAsync(() async {
        for (var i = 0; i < 180 && !returned; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      });
      await tester.pump();
      expect(returned, isTrue);
      expect(ads.presenting, isFalse);
      expect(ads.budget.shownAt.length, 1);
      expect(ads.budget.completions, 0);
      expect(ads.budget.eligible(DateTime.now()), isFalse);
      expect(app.sound, isFalse);
      expect(app.audio.enabled, isFalse);
      binding.reportData = {
        'bannerLoaded': true,
        'interstitialShown': true,
        'dismissalCallback': true,
        'frequencyApplied': true,
        'soundRestoredMuted': true,
        'testAdsOnly': true,
      };
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
