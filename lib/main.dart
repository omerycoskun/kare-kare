import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_screen.dart';
import 'ads/ad_init.dart';
import 'ads/ad_interstitial.dart';
import 'ads/ad_rewarded.dart';
import 'sound_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SoundService.instance.init(); // ses ayarını yükle (await'siz)
  runApp(const KareKareApp());
  // iOS ATT izin penceresi uygulama AKTİF olduğunda açılabilir. Bu yüzden
  // ilk kare çizildikten sonra: önce izni iste, sonra reklamları başlat/önyükle.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await initAds(); // ATT izni + AdMob init
    AdInterstitial.instance.preload(); // ilk tam ekran reklamı hazırla
    AdRewarded.instance.preload(); // "izle & devam et" ödüllü reklamı hazırla
  });
}

class KareKareApp extends StatelessWidget {
  const KareKareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kare Kare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9B5DE5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}
