import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The test uses the SDK's actual codecs, without initializing a native SDK.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';
import 'package:pikolumi/services/ads.dart';
import 'package:pikolumi/core/controller.dart';
import 'package:pikolumi/core/models.dart';
import 'package:pikolumi/ui/library.dart';

import 'app_test.dart' show MemoryStore, SilentAudio, makeApp;

class ProductionEligibilityAds extends AdsService {
  ProductionEligibilityAds()
    : super(MemoryStore(), SilentAudio()..enabled = false);
  @override
  bool get production => true;
  @override
  bool get productionAllowed => true;
  @override
  String get bannerId => 'ca-app-pub-3940256099942544/2934735716';
  @override
  String get interstitialId => 'ca-app-pub-3940256099942544/4411468910';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final ump = MethodChannel(
    'plugins.flutter.io/google_mobile_ads/ump',
    StandardMethodCodec(UserMessagingCodec()),
  );
  const androidPrivacy = MethodChannel(
    'com.seifelmoulouk.pikolumi/ads_privacy',
  );
  late List<MethodCall> calls;
  late bool eligible, protectionFails, consentRequired, updateFails;
  late bool adsDisposed;
  late bool nativeSdkInitialized;
  late bool publisherDisableResult, publisherDisableThrows;
  AdSize? platformBannerSize;
  Completer<AdSize?>? pendingBannerSize;
  Completer<bool>? publisherDisablePending;
  Completer<FormError?>? formResult;
  late ProductionEligibilityAds ads;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls = [];
    eligible = true;
    protectionFails = false;
    consentRequired = false;
    updateFails = false;
    formResult = null;
    adsDisposed = false;
    nativeSdkInitialized = false;
    publisherDisableResult = true;
    publisherDisableThrows = false;
    publisherDisablePending = null;
    platformBannerSize = null;
    pendingBannerSize = null;
    ads = ProductionEligibilityAds();
    messenger.setMockMethodCallHandler(androidPrivacy, (call) async {
      calls.add(call);
      if (publisherDisableThrows) {
        throw PlatformException(code: 'publisher-id-setting-failed');
      }
      return publisherDisablePending == null
          ? publisherDisableResult
          : await publisherDisablePending!.future;
    });
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      calls.add(call);
      if (call.method == 'MobileAds#updateRequestConfiguration' &&
          protectionFails) {
        throw PlatformException(code: 'protection-unavailable');
      }
      if (call.method == 'MobileAds#initialize') {
        nativeSdkInitialized = true;
        return InitializationStatus({});
      }
      if (call.method == 'MobileAds#setAppMuted' &&
          debugDefaultTargetPlatformOverride == TargetPlatform.android &&
          !nativeSdkInitialized) {
        throw PlatformException(code: 'mute-requires-initialization');
      }
      if (call.method.startsWith('AdSize#get')) {
        if (platformBannerSize != null) {
          return call.method.contains('Large') ? 150 : 60;
        }
        return 60;
      }
      if (call.method == 'getAdSize') {
        return pendingBannerSize == null
            ? platformBannerSize
            : await pendingBannerSize!.future;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(ump, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'ConsentInformation#canRequestAds':
          return eligible;
        case 'ConsentInformation#getConsentStatus':
          return consentRequired ? 1 : 3;
        case 'ConsentInformation#getPrivacyOptionsRequirementStatus':
          return 1;
        case 'ConsentInformation#requestConsentInfoUpdate':
          if (updateFails) throw PlatformException(code: 'offline');
          return null;
        case 'UserMessagingPlatform#showPrivacyOptionsForm':
        case 'UserMessagingPlatform#loadAndShowConsentFormIfRequired':
          return formResult == null ? null : await formResult!.future;
        default:
          return null;
      }
    });
  });

  testWidgets(
    'library banner uses its native height without extra space above navigation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final app = await makeApp((await tester.runAsync(Catalog.load))!);
      final container = ProviderContainer(
        overrides: [appProvider.overrideWith((ref) => app)],
      );
      await ads.initialize();
      platformBannerSize = const AdSize(width: 390, height: 50);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: LibraryHome(ads: ads)),
        ),
      );
      await tester.pumpAndSettle();
      final load = calls.firstWhere((c) => c.method == 'loadBannerAd');
      final banner = instanceManager.adFor(load.arguments['adId'])! as BannerAd;
      banner.listener.onAdLoaded!(banner);
      await tester.pumpAndSettle();
      final ad = tester.getRect(find.byType(AdWidget));
      final nav = tester.getRect(find.byType(NavigationBar));
      expect(ad.height, 50);
      expect(nav.top - ad.bottom, 12);
      expect(nav.height, 114);
      expect(
        calls.any(
          (c) => c.method == 'AdSize#getLargeAnchoredAdaptiveBannerAdSize',
        ),
        isFalse,
      );
      platformBannerSize = const AdSize(width: 1180, height: 90);
      tester.view.physicalSize = const Size(1180, 820);
      await tester.pumpAndSettle();
      final resizedLoad = calls.lastWhere((c) => c.method == 'loadBannerAd');
      final resized =
          instanceManager.adFor(resizedLoad.arguments['adId'])! as BannerAd;
      expect(resized, isNot(same(banner)));
      resized.listener.onAdLoaded!(resized);
      await tester.pumpAndSettle();
      final rotated = tester.getRect(find.byType(AdWidget));
      expect(rotated.size, const Size(1180, 90));
      expect(
        tester.getRect(find.byType(NavigationBar)).top - rotated.bottom,
        12,
      );
      final resizeQuery = calls.lastWhere(
        (c) => c.method.startsWith('AdSize#get'),
      );
      expect(resizeQuery.arguments['orientation'], 'landscape');
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      container.dispose();
      ads.dispose();
      adsDisposed = true;
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'privacy revocation while native banner sizing is pending leaves no slot',
    (tester) async {
      await ads.initialize();
      pendingBannerSize = Completer<AdSize?>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryBanner(ads: ads, label: 'Advertisement'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final load = calls.firstWhere((c) => c.method == 'loadBannerAd');
      final banner = instanceManager.adFor(load.arguments['adId'])! as BannerAd;
      banner.listener.onAdLoaded!(banner);
      await tester.pumpAndSettle();
      expect(calls.any((c) => c.method == 'getAdSize'), isTrue);
      eligible = false;
      await ads.privacyOptions();
      pendingBannerSize!.complete(const AdSize(width: 320, height: 50));
      await tester.pumpAndSettle();
      expect(find.byType(AdWidget), findsNothing);
      expect(find.byKey(const ValueKey('library-banner-slot')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      ads.dispose();
      adsDisposed = true;
      debugDefaultTargetPlatformOverride = null;
    },
  );
  tearDown(() async {
    if (!adsDisposed) ads.dispose();
    for (final call
        in calls
            .where(
              (c) =>
                  c.method == 'loadInterstitialAd' ||
                  c.method == 'loadBannerAd',
            )
            .toList()) {
      await instanceManager.adFor(call.arguments['adId'])?.dispose();
    }
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
    messenger.setMockMethodCallHandler(ump, null);
    messenger.setMockMethodCallHandler(androidPrivacy, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'iOS child protections and mute are applied before SDK initialization',
    () async {
      await ads.initialize();
      expect(ads.ready, isTrue);
      final initialization = calls.indexWhere(
        (c) => c.method == 'MobileAds#initialize',
      );
      final protection = calls.indexWhere(
        (c) => c.method == 'MobileAds#updateRequestConfiguration',
      );
      final mute = calls.indexWhere((c) => c.method == 'MobileAds#setAppMuted');
      expect(protection, lessThan(initialization));
      expect(mute, lessThan(initialization));
      expect(
        calls[protection].arguments['ageRestrictedTreatment'],
        AgeRestrictedTreatment.child.index,
      );
      expect(
        calls[protection].arguments['maxAdContentRating'],
        MaxAdContentRating.g,
      );
      expect(calls[mute].arguments['muted'], isTrue);
      expect(
        calls.indexWhere((c) => c.method == 'MobileAds#setSameAppKeyEnabled'),
        lessThan(initialization),
      );
    },
  );

  test(
    'background startup does not count toward foreground ad limits',
    () async {
      final binding = WidgetsBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      try {
        await ads.initialize();
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await ads.checkpoint();
        expect(ads.budget.foregroundMs, 0);
        expect(ads.audio.active, isFalse);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await ads.checkpoint();
        expect(ads.budget.foregroundMs, greaterThanOrEqualTo(20));
        expect(ads.audio.active, isTrue);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await ads.checkpoint();
        final activeTime = ads.budget.foregroundMs;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await ads.checkpoint();
        expect(ads.budget.foregroundMs, activeTime);
      } finally {
        ads.dispose();
        adsDisposed = true;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test(
    'Android disables publisher ID after initialization and before loading ads',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await ads.initialize();
      expect(ads.ready, isTrue);
      final protection = calls.indexWhere(
        (c) => c.method == 'MobileAds#updateRequestConfiguration',
      );
      final mute = calls.indexWhere((c) => c.method == 'MobileAds#setAppMuted');
      final initialization = calls.indexWhere(
        (c) => c.method == 'MobileAds#initialize',
      );
      final disable = calls.indexWhere(
        (c) => c.method == 'disablePublisherFirstPartyId',
      );
      final load = calls.indexWhere((c) => c.method == 'loadInterstitialAd');
      expect(protection, greaterThanOrEqualTo(0));
      expect(mute, greaterThanOrEqualTo(0));
      expect(disable, greaterThan(initialization));
      expect(load, greaterThan(disable));
      expect(protection, lessThan(initialization));
      expect(mute, greaterThan(initialization));
      expect(mute, lessThan(load));
      expect(
        calls[protection].arguments['ageRestrictedTreatment'],
        AgeRestrictedTreatment.child.index,
      );
      expect(
        calls[protection].arguments['maxAdContentRating'],
        MaxAdContentRating.g,
      );
      expect(calls[mute].arguments['muted'], isTrue);
    },
  );

  test('Android publisher ID persistence failure suppresses ads until retry succeeds', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    publisherDisableResult = false;
    await ads.initialize();
    expect(ads.ready, isFalse);
    expect(ads.needsPrivacyAction, isTrue);
    expect(calls.where((c) => c.method == 'loadInterstitialAd'), isEmpty);
    publisherDisableResult = true;
    await ads.privacyOptions();
    expect(ads.ready, isTrue);
    expect(calls.where((c) => c.method == 'MobileAds#initialize').length, 1);
    expect(
      calls.where((c) => c.method == 'disablePublisherFirstPartyId').length,
      2,
    );
    expect(
      calls.lastIndexWhere((c) => c.method == 'disablePublisherFirstPartyId'),
      lessThan(calls.indexWhere((c) => c.method == 'loadInterstitialAd')),
    );
  });

  test(
    'Android privacy bridge failure cannot fall through to ad loading',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      publisherDisableThrows = true;
      await ads.initialize();
      expect(ads.ready, isFalse);
      expect(ads.needsPrivacyAction, isTrue);
      expect(calls.where((c) => c.method == 'loadInterstitialAd'), isEmpty);
    },
  );

  testWidgets(
    'Android publisher ID timeout leaves the library usable without banners',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      publisherDisablePending = Completer<bool>();
      var initialized = false;
      final initialization = ads.initialize().then((_) => initialized = true);
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Library available'),
                LibraryBanner(ads: ads, label: 'Advertisement'),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 6));
      await initialization;
      expect(initialized, isTrue);
      expect(ads.ready, isFalse);
      expect(find.text('Library available'), findsOneWidget);
      expect(find.byType(AdWidget), findsNothing);
      expect(
        calls.where(
          (c) => c.method == 'loadInterstitialAd' || c.method == 'loadBannerAd',
        ),
        isEmpty,
      );
      publisherDisablePending!.complete(true);
      await tester.pump();
      expect(ads.ready, isFalse);
      await tester.pumpWidget(const SizedBox());
      ads.dispose();
      adsDisposed = true;
      debugDefaultTargetPlatformOverride = null;
    },
  );

  test('privacy eligibility revocation suspends ad requests', () async {
    await ads.initialize();
    eligible = false;
    await ads.privacyOptions();
    expect(ads.ready, isFalse);
    await ads.afterCompletion();
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
  });

  test(
    'retry cannot bypass child protection after initialization fails',
    () async {
      protectionFails = true;
      await ads.initialize();
      expect(ads.ready, isFalse);
      expect(calls.where((c) => c.method == 'MobileAds#initialize'), isEmpty);
      protectionFails = false;
      await ads.privacyOptions();
      expect(ads.ready, isTrue);
      expect(
        calls
            .where((c) => c.method == 'MobileAds#updateRequestConfiguration')
            .length,
        greaterThan(1),
      );
      final initialize = calls.indexWhere(
        (c) => c.method == 'MobileAds#initialize',
      );
      expect(
        calls.lastIndexWhere(
          (c) => c.method == 'MobileAds#updateRequestConfiguration',
        ),
        lessThan(initialize),
      );
    },
  );

  test('concurrent initialization and privacy actions do not duplicate SDK or forms', () async {
    await Future.wait([ads.initialize(), ads.initialize()]);
    expect(calls.where((c) => c.method == 'MobileAds#initialize').length, 1);
    formResult = Completer<FormError?>();
    final first = ads.privacyOptions();
    final second = ads.privacyOptions();
    await Future<void>.delayed(Duration.zero);
    expect(ads.ready, isFalse);
    expect(
      calls
          .where(
            (c) => c.method == 'UserMessagingPlatform#showPrivacyOptionsForm',
          )
          .length,
      1,
    );
    formResult!.complete(null);
    await Future.wait([first, second]);
    expect(ads.ready, isTrue);
    expect(calls.where((c) => c.method == 'MobileAds#initialize').length, 1);
  });

  test(
    'required initial consent is only presented from the parent action',
    () async {
      consentRequired = true;
      await ads.initialize();
      expect(ads.ready, isFalse);
      expect(ads.needsPrivacyAction, isTrue);
      expect(
        calls.where((c) => c.method.startsWith('UserMessagingPlatform#')),
        isEmpty,
      );
      expect(calls.where((c) => c.method == 'MobileAds#initialize'), isEmpty);
      formResult = Completer<FormError?>();
      final flow = ads.privacyOptions();
      await Future<void>.delayed(Duration.zero);
      expect(
        calls
            .where(
              (c) =>
                  c.method ==
                  'UserMessagingPlatform#loadAndShowConsentFormIfRequired',
            )
            .length,
        1,
      );
      consentRequired = false;
      formResult!.complete(null);
      await flow;
      expect(ads.ready, isTrue);
    },
  );

  test(
    'leaving the parent area prevents a delayed consent form from appearing',
    () async {
      consentRequired = true;
      await ads.initialize();
      await ads.privacyOptions(canPresent: () => false);
      expect(
        calls.where((c) => c.method.startsWith('UserMessagingPlatform#')),
        isEmpty,
      );
      expect(ads.ready, isFalse);
    },
  );

  test(
    'offline consent update without eligibility leaves content free of ads',
    () async {
      updateFails = true;
      eligible = false;
      await ads.initialize();
      expect(ads.ready, isFalse);
      expect(ads.needsPrivacyAction, isTrue);
      expect(calls.where((c) => c.method == 'MobileAds#initialize'), isEmpty);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'failed privacy update rejects cached eligibility on $platform',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        updateFails = true;
        eligible = true;
        await ads.initialize();
        expect(ads.ready, isFalse);
        expect(ads.needsPrivacyAction, isTrue);
        expect(calls.where((c) => c.method == 'MobileAds#initialize'), isEmpty);
        expect(calls.where((c) => c.method == 'loadInterstitialAd'), isEmpty);
        await ads.privacyOptions();
        expect(ads.ready, isFalse);
        expect(
          calls.where((c) => c.method.startsWith('UserMessagingPlatform#')),
          isEmpty,
        );
        updateFails = false;
        await ads.privacyOptions();
        expect(ads.ready, isTrue);
        expect(
          calls.where((c) => c.method == 'MobileAds#initialize').length,
          1,
        );
      },
    );

    test('failed refresh suspends existing ads on $platform', () async {
      debugDefaultTargetPlatformOverride = platform;
      await ads.initialize();
      final load = calls.firstWhere((c) => c.method == 'loadInterstitialAd');
      final ad =
          instanceManager.adFor(load.arguments['adId'])! as InterstitialAd;
      ad.adLoadCallback.onAdLoaded(ad);
      final requests = calls
          .where((c) => c.method == 'loadInterstitialAd')
          .length;
      updateFails = true;
      await ads.privacyOptions();
      expect(ads.ready, isFalse);
      expect(ads.hasLoadedInterstitial, isFalse);
      expect(
        calls.where((c) => c.method == 'loadInterstitialAd').length,
        requests,
      );
      expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
      updateFails = false;
      await ads.privacyOptions();
      expect(ads.ready, isTrue);
      expect(
        calls.where((c) => c.method == 'loadInterstitialAd').length,
        requests + 1,
      );
    });
  }

  test(
    'revocation rejects an in-flight interstitial even if it loads later',
    () async {
      await ads.initialize();
      final load = calls.firstWhere((c) => c.method == 'loadInterstitialAd');
      final pending =
          instanceManager.adFor(load.arguments['adId'])! as InterstitialAd;
      eligible = false;
      await ads.privacyOptions();
      pending.adLoadCallback.onAdLoaded(pending);
      await Future<void>.delayed(Duration.zero);
      expect(ads.hasLoadedInterstitial, isFalse);
      expect(
        calls.any(
          (c) =>
              c.method == 'disposeAd' &&
              c.arguments['adId'] == load.arguments['adId'],
        ),
        isTrue,
      );
    },
  );

  test('revocation disposes an already loaded interstitial', () async {
    await ads.initialize();
    final load = calls.firstWhere((c) => c.method == 'loadInterstitialAd');
    final ad = instanceManager.adFor(load.arguments['adId'])! as InterstitialAd;
    ad.adLoadCallback.onAdLoaded(ad);
    expect(ads.hasLoadedInterstitial, isTrue);
    eligible = false;
    await ads.privacyOptions();
    expect(ads.hasLoadedInterstitial, isFalse);
    expect(
      calls.any(
        (c) =>
            c.method == 'disposeAd' &&
            c.arguments['adId'] == load.arguments['adId'],
      ),
      isTrue,
    );
  });

  testWidgets('privacy revocation also disposes pending library banners', (
    tester,
  ) async {
    await ads.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryBanner(ads: ads, label: 'Advertisement'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final load = calls.firstWhere((c) => c.method == 'loadBannerAd');
    final pending = instanceManager.adFor(load.arguments['adId'])! as BannerAd;
    eligible = false;
    await ads.privacyOptions();
    await tester.pumpAndSettle();
    pending.listener.onAdLoaded!(pending);
    await tester.pumpAndSettle();
    expect(find.byType(AdWidget), findsNothing);
    expect(
      calls.any(
        (c) =>
            c.method == 'disposeAd' &&
            c.arguments['adId'] == load.arguments['adId'],
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    ads.dispose();
    adsDisposed = true;
    debugDefaultTargetPlatformOverride = null;
  });
}
