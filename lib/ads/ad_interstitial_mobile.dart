import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Mobil: her 3. oyun sonunda tam ekran (interstitial) reklam.
// Şimdilik Google TEST kimlikleri (yayından önce gerçek birimle değiştir).
class AdInterstitial {
  AdInterstitial._();
  static final AdInterstitial instance = AdInterstitial._();

  InterstitialAd? _ad;
  int _gameOverCount = 0;
  bool _loading = false;

  static String get _unitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712' // Android test interstitial
      : 'ca-app-pub-3940256099942544/4411468910'; // iOS test interstitial

  void preload() => _load();

  void _load() {
    if (_loading || _ad != null) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _loading = false;
        },
      ),
    );
  }

  /// Her oyun sonunda çağrılır; 3'ün katıysa reklam gösterir.
  void notifyGameOver() {
    _gameOverCount++;
    if (_gameOverCount % 3 != 0) {
      _load(); // bir sonrakine hazır olsun
      return;
    }
    final ad = _ad;
    if (ad == null) {
      _load();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        _load();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        _load();
      },
    );
    ad.show();
    _ad = null;
  }
}
