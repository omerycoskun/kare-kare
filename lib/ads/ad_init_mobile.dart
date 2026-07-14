import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Mobil: önce ATT (App Tracking Transparency) iznini iste (iOS zorunlu),
// sonra AdMob SDK'yı başlat.
Future<void> initAds() async {
  if (Platform.isIOS) {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      // Sistem izin penceresini gösterir; kullanıcı seçene kadar bekler.
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  }
  await MobileAds.instance.initialize();
}
