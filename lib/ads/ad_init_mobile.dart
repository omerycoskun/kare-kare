import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Mobil: önce ATT (App Tracking Transparency) iznini iste (iOS zorunlu),
// sonra AdMob SDK'yı başlat.
Future<void> initAds() async {
  await ensureTrackingPermission();
  await MobileAds.instance.initialize();
}

/// iOS ATT (takip izni) penceresini GÜVENİLİR biçimde göster.
///
/// Apple 2.1 reddi: "AppTrackingTransparency kullanılıyor ama izin penceresini
/// bulamadık" (iPadOS 26.x). Sebep: izin penceresi ancak uygulama ön planda ve
/// AKTİF durumdayken açılabilir. Flutter'ın ilk karesi çizildiğinde uygulama
/// hâlâ `inactive` olabiliyor (özellikle iPad'de); o anda yapılan istek sessizce
/// düşüyor ve pencere bir daha hiç görünmüyor. Bu yüzden: önce `resumed`
/// durumunu bekle, kısa bir nefes al, sonra iste ve gerekirse tekrar dene.
Future<void> ensureTrackingPermission() async {
  if (!Platform.isIOS) return;
  var status = await AppTrackingTransparency.trackingAuthorizationStatus;
  if (status != TrackingStatus.notDetermined) return;

  // Uygulama aktif olana kadar bekle (en fazla ~4 sn).
  for (var i = 0; i < 40; i++) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await Future<void>.delayed(const Duration(milliseconds: 500));

  // İlk istek yine de düşerse birkaç kez dene.
  for (var i = 0; i < 3; i++) {
    status = await AppTrackingTransparency.requestTrackingAuthorization();
    if (status != TrackingStatus.notDetermined) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}
