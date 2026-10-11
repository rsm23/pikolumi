import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'store_interface.dart';
import 'ad_budget.dart';
import 'audio.dart';

class AdsService extends ChangeNotifier with WidgetsBindingObserver {
  final RecordStore store;
  final AudioService audio;
  AdBudget budget = AdBudget();
  bool ready = false, presenting = false, _resumed = true, _disposed = false;
  int activityDepth = 0;
  void enterActivity() {
    activityDepth++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  void leaveActivity() {
    activityDepth = (activityDepth - 1).clamp(0, 100);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  InterstitialAd? _interstitial;
  bool get hasLoadedInterstitial => _interstitial != null;
  final Stopwatch _foreground = Stopwatch();
  Timer? _checkpoint;
  Future<void> _saved = Future.value();
  AdsService(this.store, this.audio);
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  bool get ios => defaultTargetPlatform == TargetPlatform.iOS;
  bool get production => const bool.fromEnvironment('ADS_PRODUCTION');
  bool get productionAllowed =>
      !ios || const bool.fromEnvironment('IOS_KIDS_ADS_VERIFIED');
  String get bannerId => production
      ? (ios
            ? const String.fromEnvironment('IOS_BANNER_ID')
            : const String.fromEnvironment('ANDROID_BANNER_ID'))
      : (ios
            ? 'ca-app-pub-3940256099942544/2934735716'
            : 'ca-app-pub-3940256099942544/6300978111');
  String get interstitialId => production
      ? (ios
            ? const String.fromEnvironment('IOS_INTERSTITIAL_ID')
            : const String.fromEnvironment('ANDROID_INTERSTITIAL_ID'))
      : (ios
            ? 'ca-app-pub-3940256099942544/4411468910'
            : 'ca-app-pub-3940256099942544/1033173712');
  Future<void> initialize() async {
    final raw = await store.read('ads', 'budget');
    if (raw != null) {
      try {
        budget = AdBudget.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
      } catch (_) {}
    }
    WidgetsBinding.instance.addObserver(this);
    _foreground.start();
    _checkpoint = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(checkpoint()),
    );
    if (!supported ||
        (production && !productionAllowed) ||
        bannerId.isEmpty ||
        interstitialId.isEmpty) {
      return;
    }
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          ageRestrictedTreatment: AgeRestrictedTreatment.child,
          maxAdContentRating: MaxAdContentRating.g,
        ),
      );
      await MobileAds.instance.setSameAppKeyEnabled(false);
      final updated = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(tagForUnderAgeOfConsent: true),
        () => updated.complete(),
        (_) => updated.complete(),
      );
      await updated.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
      ready = !production || await ConsentInformation.instance.canRequestAds();
      if (ready) {
        await MobileAds.instance.initialize();
        await MobileAds.instance.setAppMuted(!audio.enabled);
        _load();
        notifyListeners();
      }
    } catch (_) {
      ready = false;
    }
  }

  void _load() {
    if (!ready || _disposed) return;
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(nonPersonalizedAds: true),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          _interstitial?.dispose();
          _interstitial = ad;
        },
        onAdFailedToLoad: (_) {
          _interstitial = null;
        },
      ),
    );
  }

  Future<void> checkpoint() async {
    budget.addForeground(_foreground.elapsed);
    _foreground.reset();
    final value = jsonEncode(budget.toJson());
    _saved = _saved.then((_) => store.write('ads', 'budget', value));
    await _saved;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    audio.active = _resumed;
    if (!_resumed) {
      unawaited(checkpoint());
      _foreground.stop();
      unawaited(audio.stop());
    } else if (!presenting) {
      _foreground.start();
    }
  }

  Future<void> activityCompleted() async {
    budget.completed();
    await checkpoint();
  }

  Future<void> synchronizeSound() async {
    if (!ready) return;
    try {
      await MobileAds.instance.setAppMuted(!audio.enabled);
    } catch (_) {}
  }

  Future<void> afterCompletion() async {
    await checkpoint();
    if (!ready ||
        presenting ||
        !_resumed ||
        _interstitial == null ||
        !budget.eligible(DateTime.now())) {
      return;
    }
    final ad = _interstitial!;
    _interstitial = null;
    presenting = true;
    _foreground.stop();
    notifyListeners();
    await audio.stop();
    final dismissed = Completer<void>();
    void finish() {
      if (dismissed.isCompleted) return;
      ad.dispose();
      presenting = false;
      if (_resumed) _foreground.start();
      if (!_disposed) {
        notifyListeners();
        _load();
      }
      if (!dismissed.isCompleted) dismissed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        budget.shown(DateTime.now());
        unawaited(checkpoint());
      },
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, _) => finish(),
    );
    try {
      await MobileAds.instance.setAppMuted(!audio.enabled);
      await ad.show();
      await dismissed.future;
    } catch (_) {
      finish();
    }
  }

  Future<void> privacyOptions() async {
    if (!supported || (production && !productionAllowed)) return;
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      if (status == PrivacyOptionsRequirementStatus.required) {
        await ConsentForm.showPrivacyOptionsForm((_) {});
      } else {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      }
      if (!ready && await ConsentInformation.instance.canRequestAds()) {
        await MobileAds.instance.initialize();
        await MobileAds.instance.setAppMuted(!audio.enabled);
        ready = true;
        _load();
        notifyListeners();
      }
    } catch (_) {
      /* Privacy failures never block offline activities. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _checkpoint?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _foreground.stop();
    _interstitial?.dispose();
    super.dispose();
  }
}

// Encoding stays separate so budget tests do not initialize any ad SDK.
