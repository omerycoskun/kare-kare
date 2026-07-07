import 'package:google_mobile_ads/google_mobile_ads.dart';

// Mobil: AdMob SDK'yı başlatır.
Future<void> initAds() async {
  await MobileAds.instance.initialize();
}
