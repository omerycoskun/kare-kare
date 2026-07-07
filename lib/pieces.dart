import 'package:flutter/material.dart';

/// Bir blok parçası: dolu hücrelerin (satır, sütun) koordinatları + rengi.
class Piece {
  final List<List<int>> cells; // normalize edilmiş, min satır/sütun = 0
  final Color color;

  const Piece(this.cells, this.color);

  int get rows =>
      cells.map((c) => c[0]).reduce((a, b) => a > b ? a : b) + 1;
  int get cols =>
      cells.map((c) => c[1]).reduce((a, b) => a > b ? a : b) + 1;
  int get cellCount => cells.length;
}

/// Modern, canlı renk paleti.
const List<Color> kPieceColors = [
  Color(0xFFFF5A5F), // kırmızı-mercan
  Color(0xFFFFB400), // amber
  Color(0xFF2EC4B6), // turkuaz
  Color(0xFF4D96FF), // mavi
  Color(0xFF9B5DE5), // mor
  Color(0xFFF15BB5), // pembe
  Color(0xFF52B788), // yeşil
  Color(0xFFFF8C42), // turuncu
];

/// Şekli normalize eder (min satır ve sütunu 0'a çeker).
List<List<int>> _normalize(List<List<int>> cells) {
  final minR = cells.map((c) => c[0]).reduce((a, b) => a < b ? a : b);
  final minC = cells.map((c) => c[1]).reduce((a, b) => a < b ? a : b);
  return cells.map((c) => [c[0] - minR, c[1] - minC]).toList();
}

/// Oyunda kullanılabilecek tüm blok şekilleri (Block Blast tarzı).
final List<List<List<int>>> kShapes = [
  // tekli
  _normalize([[0, 0]]),
  // ikili
  _normalize([[0, 0], [0, 1]]),
  _normalize([[0, 0], [1, 0]]),
  // üçlü çizgi
  _normalize([[0, 0], [0, 1], [0, 2]]),
  _normalize([[0, 0], [1, 0], [2, 0]]),
  // dörtlü çizgi
  _normalize([[0, 0], [0, 1], [0, 2], [0, 3]]),
  _normalize([[0, 0], [1, 0], [2, 0], [3, 0]]),
  // beşli çizgi
  _normalize([[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]]),
  _normalize([[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]]),
  // 2x2 kare
  _normalize([[0, 0], [0, 1], [1, 0], [1, 1]]),
  // 3x3 kare
  _normalize([
    [0, 0], [0, 1], [0, 2],
    [1, 0], [1, 1], [1, 2],
    [2, 0], [2, 1], [2, 2],
  ]),
  // L köşe (3 hücre) - 4 dönüş
  _normalize([[0, 0], [1, 0], [1, 1]]),
  _normalize([[0, 0], [0, 1], [1, 0]]),
  _normalize([[0, 0], [0, 1], [1, 1]]),
  _normalize([[0, 1], [1, 0], [1, 1]]),
  // L tetromino - 4 dönüş
  _normalize([[0, 0], [1, 0], [2, 0], [2, 1]]),
  _normalize([[0, 0], [0, 1], [0, 2], [1, 0]]),
  _normalize([[0, 0], [0, 1], [1, 1], [2, 1]]),
  _normalize([[0, 2], [1, 0], [1, 1], [1, 2]]),
  // J tetromino - 4 dönüş
  _normalize([[0, 1], [1, 1], [2, 0], [2, 1]]),
  _normalize([[0, 0], [1, 0], [1, 1], [1, 2]]),
  _normalize([[0, 0], [0, 1], [1, 0], [2, 0]]),
  _normalize([[0, 0], [0, 1], [0, 2], [1, 2]]),
  // T tetromino - 4 dönüş
  _normalize([[0, 0], [0, 1], [0, 2], [1, 1]]),
  _normalize([[0, 1], [1, 0], [1, 1], [2, 1]]),
  _normalize([[0, 1], [1, 0], [1, 1], [1, 2]]),
  _normalize([[0, 0], [1, 0], [1, 1], [2, 0]]),
  // S / Z
  _normalize([[0, 1], [0, 2], [1, 0], [1, 1]]),
  _normalize([[0, 0], [1, 0], [1, 1], [2, 1]]),
  _normalize([[0, 0], [0, 1], [1, 1], [1, 2]]),
  _normalize([[0, 1], [1, 0], [1, 1], [2, 0]]),
  // --- büyük/zor parçalar (çeşitlilik + zorluk) ---
  // 2x3 ve 3x2 dikdörtgen
  _normalize([[0, 0], [0, 1], [1, 0], [1, 1], [2, 0], [2, 1]]),
  _normalize([[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2]]),
  // artı (+)
  _normalize([[0, 1], [1, 0], [1, 1], [1, 2], [2, 1]]),
  // U şekli - 2 yön
  _normalize([[0, 0], [0, 2], [1, 0], [1, 1], [1, 2]]),
  _normalize([[0, 0], [0, 1], [1, 1], [2, 0], [2, 1]]),
  // büyük L köşe (5 hücre, 3x3'ün kenarları) - 4 dönüş
  _normalize([[0, 0], [1, 0], [2, 0], [2, 1], [2, 2]]),
  _normalize([[0, 0], [0, 1], [0, 2], [1, 0], [2, 0]]),
  _normalize([[0, 0], [0, 1], [0, 2], [1, 2], [2, 2]]),
  _normalize([[0, 2], [1, 2], [2, 0], [2, 1], [2, 2]]),
];

/// Parçanın seçilme ağırlığı (hücre sayısına göre). Orta ve büyük parçalar
/// daha sık gelir → oyun daha zor ve çeşitli. Tekli/ikili yine de gelir ki
/// sıkışık tahtada boşluk doldurmak mümkün olsun.
int weightForCells(int n) {
  if (n <= 1) return 4;
  if (n == 2) return 3;
  if (n == 3) return 3;
  if (n == 4) return 2;
  if (n == 5) return 2;
  return 1; // 6+ hücre: nadir ama zorlayıcı
}
