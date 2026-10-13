import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pikolumi/services/ads.dart';

import '../test/app_test.dart' show MemoryStore, SilentAudio;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android SDK accepts publisher ID disablement before ad loading',
    (tester) async {
      final audio = SilentAudio()..enabled = false;
      final ads = AdsService(MemoryStore(), audio);
      addTearDown(ads.dispose);
      runApp(
        const MaterialApp(home: Scaffold(body: Text('Silent privacy check'))),
      );
      await ads.initialize();
      expect(ads.production, isFalse);
      expect(ads.ready, isTrue);
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
        'audioPlayback': false,
        'store': 'isolated memory; user profiles and artwork untouched',
        'runtimeTrafficInspection': false,
      };
    },
  );
}
