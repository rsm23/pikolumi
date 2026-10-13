import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/services/ads.dart';

import '../test/app_test.dart' show MemoryStore, SilentAudio;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('iOS native SDK accepts the app child protections silently', (
    tester,
  ) async {
    expect(Platform.isIOS, isTrue);
    final audio = SilentAudio()..enabled = false;
    final ads = AdsService(MemoryStore(), audio);
    addTearDown(ads.dispose);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Silent privacy check'))),
    );
    expect(ads.production, isFalse);
    expect(ads.productionAllowed, isFalse);
    expect(ads.bannerId, 'ca-app-pub-3940256099942544/2934735716');
    expect(ads.interstitialId, 'ca-app-pub-3940256099942544/4411468910');
    await ads.initialize();
    if (!ads.ready) await ads.privacyOptions(canPresent: () => false);
    expect(ads.ready, isTrue);
    final version = await MobileAds.instance.getVersionString();
    expect(version, contains('13.11.0'));
    final configuration = await MobileAds.instance.getRequestConfiguration();
    expect(configuration.ageRestrictedTreatment, AgeRestrictedTreatment.child);
    expect(configuration.maxAdContentRating, MaxAdContentRating.g);
    expect(audio.enabled, isFalse);
    expect(ads.presenting, isFalse);
    binding.reportData = {
      'nativeSDKVersion': version,
      'nativeChildTreatment': true,
      'nativeMaximumRatingG': true,
      'appPrivacySetupReturnedSuccessfully': true,
      'publisherIdPersistedStateIndependentlyMeasured': false,
      'testAdUnitsOnly': true,
      'productionKidsGateRemainsFalse': true,
      'nativeAdPresented': false,
      'audioPlayback': false,
      'store': 'isolated memory; app profiles and artwork untouched',
      'runtimeTrafficInspected': false,
      'appleKidsAdExceptionVerified': false,
    };
  });
}
