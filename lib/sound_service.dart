import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Basit ses efekti yöneticisi (yerleştirme / patlama / oyun sonu).
/// audioplayers web + mobil + masaüstünde çalışır.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  bool soundOn = true;
  SharedPreferences? _prefs;

  // Üst üste binebilsin diye her efekt için ayrı oynatıcı.
  final AudioPlayer _place = AudioPlayer(playerId: 'place');
  final AudioPlayer _clear = AudioPlayer(playerId: 'clear');
  final AudioPlayer _over = AudioPlayer(playerId: 'over');

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      soundOn = _prefs?.getBool('soundOn') ?? true;
      for (final p in [_place, _clear, _over]) {
        await p.setReleaseMode(ReleaseMode.stop);
      }
    } catch (_) {
      // ses altyapısı yoksa sessizce geç
    }
  }

  Future<void> toggle() async {
    soundOn = !soundOn;
    try {
      await _prefs?.setBool('soundOn', soundOn);
    } catch (_) {}
  }

  void _play(AudioPlayer p, String asset) {
    if (!soundOn) return;
    try {
      p.stop();
      p.play(AssetSource(asset), volume: 0.9);
    } catch (_) {}
  }

  void place() => _play(_place, 'audio/place.wav');
  void clear() => _play(_clear, 'audio/clear.wav');
  void gameOver() => _play(_over, 'audio/gameover.wav');
}
