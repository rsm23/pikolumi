import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'store_interface.dart';
import 'ad_budget.dart';
import 'audio.dart';

class AdsService extends ChangeNotifier with WidgetsBindingObserver {
  static const _androidPrivacy = MethodChannel(
    'com.seifelmoulouk.pikolumi/ads_privacy',
  );
  final RecordStore store;
  final AudioService audio;
  AdBudget budget = AdBudget();
  bool ready = false, presenting = false, _resumed = false, _disposed = false;
  bool consentFormRequired = false, privacyOptionsRequired = false;
  bool _privacyUpdateFailed = false, _sdkInitialized = false;
  Future<void>? _initialization, _privacyFlow;
  int _loadGeneration = 0;
  bool get needsPrivacyAction =>
      _canUseAds &&
      (consentFormRequired || privacyOptionsRequired || _privacyUpdateFailed);
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
  bool get _canUseAds =>
      !_disposed &&
      supported &&
      (!production || productionAllowed) &&
      bannerId.isNotEmpty &&
      interstitialId.isNotEmpty;
  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    final raw = await store.read('ads', 'budget');
    if (raw != null) {
      try {
        budget = AdBudget.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
      } catch (_) {}
    }
    if (_disposed) return;
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    audio.active = _resumed;
    if (_resumed) _foreground.start();
    _checkpoint = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(checkpoint()),
    );
    if (!_canUseAds) return;
    try {
      await _applyChildProtections();
      await _updateConsent();
      await _reconcileEligibility();
    } catch (_) {
      _privacyUpdateFailed = true;
      _suspendAds();
    }
  }

  Future<void> _applyChildProtections() async {
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        ageRestrictedTreatment: AgeRestrictedTreatment.child,
        maxAdContentRating: MaxAdContentRating.g,
      ),
    );
    if (ios) {
      await MobileAds.instance.setSameAppKeyEnabled(false);
      await MobileAds.instance.setAppMuted(!audio.enabled);
    }
  }

  Future<void> _updateConsent() async {
    final updated = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(tagForUnderAgeOfConsent: true),
      () {
        if (!updated.isCompleted) updated.complete(true);
      },
      (_) {
        if (!updated.isCompleted) updated.complete(false);
      },
    );
    _privacyUpdateFailed = !await updated.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => false,
    );
    await _readConsentState();
  }

  Future<void> _readConsentState() async {
    consentFormRequired =
        await ConsentInformation.instance.getConsentStatus() ==
        ConsentStatus.required;
    privacyOptionsRequired =
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  void _suspendAds() {
    ready = false;
    _loadGeneration++;
    _interstitial?.dispose();
    _interstitial = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> _reconcileEligibility() async {
    if (!_canUseAds) return;
    if (_privacyUpdateFailed) {
      _suspendAds();
      return;
    }
    final allowed =
        !production ||
        (!consentFormRequired &&
            await ConsentInformation.instance.canRequestAds());
    if (!allowed) {
      _suspendAds();
      return;
    }
    if (!_sdkInitialized) {
      await MobileAds.instance.initialize();
      _sdkInitialized = true;
    }
    if (!ios) {
      final disabled = await _androidPrivacy
          .invokeMethod<bool>('disablePublisherFirstPartyId')
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (disabled != true) {
        _privacyUpdateFailed = true;
        _suspendAds();
        return;
      }
    }
    await MobileAds.instance.setAppMuted(!audio.enabled);
    if (!_canUseAds) return;
    if (!ready) {
      ready = true;
      _load();
      notifyListeners();
    }
  }

  void _load() {
    if (!ready || _disposed) return;
    final generation = ++_loadGeneration;
    unawaited(
      InterstitialAd.load(
        adUnitId: interstitialId,
        request: const AdRequest(nonPersonalizedAds: true),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (_disposed || !ready || generation != _loadGeneration) {
              ad.dispose();
              return;
            }
            _interstitial?.dispose();
            _interstitial = ad;
          },
          onAdFailedToLoad: (_) {
            if (generation == _loadGeneration) _interstitial = null;
          },
        ),
      ).catchError((Object _) {
        if (generation == _loadGeneration) _interstitial = null;
      }),
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

  Future<void> privacyOptions({bool Function()? canPresent}) async {
    if (!_canUseAds) return;
    if (_privacyFlow != null) return _privacyFlow;
    final flow = _showPrivacyOptions(canPresent ?? () => true);
    _privacyFlow = flow;
    try {
      await flow;
    } finally {
      _privacyFlow = null;
    }
  }

  Future<void> _showPrivacyOptions(bool Function() canPresent) async {
    await initialize();
    if (!_canUseAds) return;
    _suspendAds();
    try {
      await _applyChildProtections();
      await _updateConsent();
      if (_privacyUpdateFailed) {
        _suspendAds();
        return;
      }
      FormError? formError;
      if (!_disposed && canPresent()) {
        if (consentFormRequired) {
          await ConsentForm.loadAndShowConsentFormIfRequired(
            (error) => formError = error,
          );
        } else if (privacyOptionsRequired) {
          await ConsentForm.showPrivacyOptionsForm(
            (error) => formError = error,
          );
        }
      }
      if (formError != null) {
        _privacyUpdateFailed = true;
        _suspendAds();
        return;
      }
      await _readConsentState();
      await _reconcileEligibility();
    } catch (_) {
      _privacyUpdateFailed = true;
      _suspendAds();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _checkpoint?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _foreground.stop();
    _interstitial?.dispose();
    super.dispose();
  }
}
