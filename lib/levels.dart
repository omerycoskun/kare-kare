import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const int kGridCells = 8;

/// Toplam bölüm sayısı ("Çini Macerası").
const int kLevelCount = 30;

/// Bir bölümün başlangıç düzeni: temizlenecek çini karolar, iki kez kırılması
/// gereken taşlar ve kullanılabilecek parça (hamle) sayısı.
class LevelSpec {
  const LevelSpec({required this.number, required this.moves, required this.cini, required this.stones});

  final int number;
  final int moves;

  /// Hücre indeksleri (r * 8 + c).
  final Set<int> cini;
  final Set<int> stones;

  /// Kalan hamleye göre 1-3 yıldız.
  int starsFor(int movesLeft) {
    final ratio = movesLeft / moves;
    if (ratio >= 0.35) return 3;
    if (ratio >= 0.15) return 2;
    return 1;
  }
}

/// [number]. bölümü deterministik olarak üretir (her cihazda aynı bölüm).
LevelSpec levelSpec(int number) {
  final n = number.clamp(1, kLevelCount);
  final rng = Random(n * 7919 + 13);
  final ciniCount = min(2 + (n - 1) ~/ 2, 12);
  final stoneCount = n < 4 ? 0 : min((n - 2) ~/ 3, 8);

  final rowUse = List.filled(kGridCells, 0);
  final colUse = List.filled(kGridCells, 0);
  final taken = <int>{};

  int pick() {
    while (true) {
      final idx = rng.nextInt(kGridCells * kGridCells);
      final r = idx ~/ kGridCells;
      final c = idx % kGridCells;
      // Başlangıçta hiçbir satır/sütun kendiliğinden dolmaya yaklaşmasın.
      if (taken.contains(idx) || rowUse[r] >= 4 || colUse[c] >= 4) continue;
      taken.add(idx);
      rowUse[r]++;
      colUse[c]++;
      return idx;
    }
  }

  final cini = {for (var i = 0; i < ciniCount; i++) pick()};
  final stones = {for (var i = 0; i < stoneCount; i++) pick()};
  return LevelSpec(number: n, moves: 12 + ciniCount * 2 + stoneCount * 2, cini: cini, stones: stones);
}

/// Bölüm ilerlemesi (kazanılan yıldızlar) — kalıcı.
class LevelProgress {
  LevelProgress._();
  static final LevelProgress instance = LevelProgress._();

  SharedPreferences? _prefs;
  final Map<int, int> _stars = {};

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      for (var i = 1; i <= kLevelCount; i++) {
        _stars[i] = _prefs?.getInt('level_stars_$i') ?? 0;
      }
    } catch (_) {}
  }

  int stars(int level) => _stars[level] ?? 0;

  int get totalStars => _stars.values.fold(0, (a, b) => a + b);

  /// İlk bölüm hep açık; sonrakiler bir öncekini bitirince açılır.
  bool isUnlocked(int level) => level == 1 || stars(level - 1) > 0;

  Future<void> record(int level, int stars) async {
    if (stars <= this.stars(level)) return;
    _stars[level] = stars;
    try {
      await _prefs?.setInt('level_stars_$level', stars);
    } catch (_) {}
  }
}
