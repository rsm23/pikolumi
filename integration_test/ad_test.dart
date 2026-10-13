import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/main.dart' as production;
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/services/audio.dart';
import 'package:pikolumi/services/ad_budget.dart';

import '../test/app_test.dart' show MemoryStore;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'test banner, interstitial close callback and silent restoration',
    (tester) async {
      final store = MemoryStore();
      final app = AppController(
        catalog: await Catalog.load(),
        store: store,
        audio: AudioService(),
      );
      await app.initialize();
      await app.setSound(false);
      final ads = AdsService(store, app.audio);
      runApp(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => app)],
          child: production.PikolumiApp(ads: ads),
        ),
      );
      await ads.initialize();
      await tester.pumpAndSettle();
      if (!ads.ready) {
        debugPrint('PIKOLUMI_AD_QA_RETRY_CONSENT');
        await ads.privacyOptions(canPresent: () => false);
        await tester.pumpAndSettle();
      }
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
      addTearDown(() async {
        ads.dispose();
      });
      ads.budget = AdBudget(foregroundMs: 300000, completions: 4);
      var returned = false;
      unawaited(ads.afterCompletion().then((_) => returned = true));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      expect(ads.presenting, isTrue);
      debugPrint(
        'PIKOLUMI_AD_QA_PRESENTING ${DateTime.now().toUtc().toIso8601String()}',
      );
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
      ads.leaveActivity();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(AdWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
      binding.reportData = {
        'bannerLoaded': true,
        'interstitialShown': true,
        'dismissalCallback': true,
        'frequencyApplied': true,
        'soundRestoredMuted': true,
        'libraryBannerRestored': true,
        'testAdsOnly': true,
        'catalogVersion': app.catalog.version,
        'store': 'isolated memory; user progress and ad budget untouched',
      };
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
