import 'dart:async';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Mobil: "İzle & Devam Et" için ödüllü reklam.
// Şimdilik Google TEST kimlikleri (yayından önce gerçek birimle değiştir).
class AdRewarded {
  AdRewarded._();
  static final AdRewarded instance = AdRewarded._();

  RewardedAd? _ad;
  bool _loading = false;

  static String get _unitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917' // Android test rewarded
      : 'ca-app-pub-3940256099942544/1712485313'; // iOS test rewarded

  void preload() => _load();

  void _load() {
    if (_loading || _ad != null) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (_) {
          _ad = null;
          _loading = false;
        },
      ),
    );
  }

  bool get isReady => _ad != null;

  /// Ödüllü reklamı gösterir; kullanıcı ödülü kazanırsa true döner.
  Future<bool> showContinue() async {
    final ad = _ad;
    if (ad == null) {
      _load();
      return false;
    }
    _ad = null;
    var earned = false;
    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _load();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _load();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (ad, reward) => earned = true);
    return completer.future;
  }
}
