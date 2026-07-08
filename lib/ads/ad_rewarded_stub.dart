// Web ve masaüstü: ödüllü reklam yok — reklamsız "devam" izni verilir.
class AdRewarded {
  AdRewarded._();
  static final AdRewarded instance = AdRewarded._();

  void preload() {}
  bool get isReady => true; // web'de reklamsız devam edilebilir
  Future<bool> showContinue() async => true;
}
