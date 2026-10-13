import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/services/ads.dart';

import '../test/app_test.dart' show MemoryStore, SilentAudio;

class PrivacyEligibilityAds extends AdsService {
  PrivacyEligibilityAds()
    : super(MemoryStore(), SilentAudio()..enabled = false);
  @override
  bool get production => true;
  @override
  String get bannerId => 'ca-app-pub-3940256099942544/6300978111';
  @override
  String get interstitialId => 'ca-app-pub-3940256099942544/1033173712';
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android SDK accepts publisher ID disablement before ad loading',
    (tester) async {
      final ads = PrivacyEligibilityAds();
      final audio = ads.audio;
      addTearDown(ads.dispose);
      runApp(
        const MaterialApp(home: Scaffold(body: Text('Silent privacy check'))),
      );
      await ads.initialize();
      expect(ads.production, isTrue);
      expect(ads.ready, isTrue);
      expect(await ConsentInformation.instance.canRequestAds(), isTrue);
      final consentStatus = await ConsentInformation.instance
          .getConsentStatus();
      expect(consentStatus, isNot(ConsentStatus.required));
      expect(ads.consentFormRequired, isFalse);
      final version = await MobileAds.instance.getVersionString();
      expect(version, contains('25.5.0'));
      final configuration = await MobileAds.instance.getRequestConfiguration();
      expect(
        configuration.ageRestrictedTreatment,
        AgeRestrictedTreatment.child,
      );
      expect(configuration.maxAdContentRating, MaxAdContentRating.g);
      final persisted = await const MethodChannel(
        'com.seifelmoulouk.pikolumi/ads_privacy',
      ).invokeMethod<bool>('disablePublisherFirstPartyId');
      expect(persisted, isTrue);
      expect(audio.enabled, isFalse);
      binding.reportData = {
        'publisherFirstPartyIdDisablementPersisted': persisted,
        'nativeChildTreatment': true,
        'nativeMaximumRatingG': true,
        'testAdsOnly': true,
        'productionEligibilityPath': true,
        'nativeSDKVersion': version,
        'umpCanRequestAds': true,
        'umpConsentStatus': consentStatus.name,
        'childConsentFormNotRequired': true,
        'audioPlayback': false,
        'store': 'isolated memory; user profiles and artwork untouched',
        'runtimeTrafficInspection': false,
      };
    },
  );
}
