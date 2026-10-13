import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/main.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/ui/library.dart';

import '../test/app_test.dart' show MemoryStore, SilentAudio;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('compact native banners fit the library footer and stay silent', (
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
    runApp(
      ProviderScope(
        overrides: [appProvider.overrideWith((ref) => app)],
        child: PikolumiApp(ads: ads),
      ),
    );
    await ads.initialize();
    await tester.pumpAndSettle();
    expect(ads.production, isFalse);
    expect(ads.ready, isTrue);
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    Future<void> waitForBanner() async {
      for (
        var i = 0;
        i < 60 &&
            find
                .byKey(const ValueKey('library-banner-slot'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byKey(const ValueKey('library-banner-slot')), findsOneWidget);
      await tester.pumpAndSettle();
    }

    final measurements = <Map<String, Object>>[];
    for (final locale in ['en', 'fr', 'es', 'pt', 'ar']) {
      await app.setLanguage(locale);
      await tester.pumpAndSettle();
      await waitForBanner();
      final banner =
          tester.widget<AdWidget>(find.byType(AdWidget)).ad as BannerAd;
      final native = (await banner.getPlatformAdSize())!;
      final slot = tester.getRect(
        find.byKey(const ValueKey('library-banner-slot')),
      );
      final footer = tester.getRect(
        find.byKey(const ValueKey('library-banner')),
      );
      final nav = tester.getRect(find.byType(NavigationBar));
      expect(
        slot.size,
        Size(native.width.toDouble(), native.height.toDouble()),
      );
      expect(nav.top - slot.bottom, closeTo(12, .01));
      expect(footer.height - slot.height, lessThan(50));
      measurements.add({
        'locale': locale,
        'width': native.width,
        'height': native.height,
        'navigationGap': nav.top - slot.bottom,
        'footerHeight': footer.height,
      });
      await binding.takeScreenshot('$locale-library-banner');
    }
    ads.enterActivity();
    await tester.pumpAndSettle();
    expect(find.byType(AdWidget), findsNothing);
    expect(find.byKey(const ValueKey('library-banner-slot')), findsNothing);
    ads.leaveActivity();
    await tester.pumpAndSettle();
    await waitForBanner();
    await app.setLanguage('en');
    await tester.pumpAndSettle();
    final shortcut = find.text(app.catalog.sections.first.name('en')).first;
    await tester.ensureVisible(shortcut);
    await tester.pumpAndSettle();
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    await waitForBanner();
    expect(find.byType(SectionLibrary), findsOneWidget);
    final sectionBanner =
        tester.widget<AdWidget>(find.byType(AdWidget)).ad as BannerAd;
    final sectionNative = (await sectionBanner.getPlatformAdSize())!;
    final sectionSlot = tester.getRect(
      find.byKey(const ValueKey('library-banner-slot')),
    );
    expect(
      sectionSlot.size,
      Size(sectionNative.width.toDouble(), sectionNative.height.toDouble()),
    );
    await binding.takeScreenshot('en-section-banner');
    expect(app.sound, isFalse);
    expect(app.audio.enabled, isFalse);
    expect(tester.takeException(), isNull);
    binding.reportData = {
      ...?binding.reportData,
      'measurements': measurements,
      'sectionBannerFitsNativeSize': true,
      'activityHidesBannerAndReservedSpace': true,
      'testAdsOnly': true,
      'audio': 'SilentAudio; muted before runApp and SDK initialization',
      'store': 'isolated memory; existing sound preferences, profiles and artwork untouched',
    };
    await tester.pumpWidget(const SizedBox());
    await app.flush();
    ads.dispose();
  });
}
