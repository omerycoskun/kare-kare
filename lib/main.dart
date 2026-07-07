import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_screen.dart';
import 'ads/ad_init.dart';
import 'ads/ad_interstitial.dart';
import 'sound_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  initAds(); // mobilde AdMob'u başlatır, web/masaüstünde no-op (await'siz)
  AdInterstitial.instance.preload(); // ilk tam ekran reklamı hazırla
  SoundService.instance.init(); // ses ayarını yükle (await'siz)
  runApp(const KareKareApp());
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
