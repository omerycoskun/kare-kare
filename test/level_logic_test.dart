import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karekare/game_state.dart';
import 'package:karekare/levels.dart';
import 'package:karekare/pieces.dart';

Piece hLine(int n, [Color color = Colors.blue]) => Piece(List.generate(n, (i) => [0, i]), color);

/// Satır 0'ın [col] sütunu hariç her yeri dolu olacak şekilde hazırlar.
void fillRowExcept(GameState g, int row, int col) {
  for (int c = 0; c < kGridSize; c++) {
    if (c != col && g.grid[row][c] == null) g.grid[row][c] = Colors.grey;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bölümler deterministik, sınırlar içinde ve başta dolu satır/sütun yok', () {
    for (var n = 1; n <= kLevelCount; n++) {
      final a = levelSpec(n);
      final b = levelSpec(n);
      expect(a.cini, b.cini);
      expect(a.stones, b.stones);
      expect(a.cini.intersection(a.stones), isEmpty);
      expect(a.cini, isNotEmpty);
      expect(a.moves, greaterThan(a.cini.length));
      final all = {...a.cini, ...a.stones};
      for (var i = 0; i < kGridSize; i++) {
        expect(all.where((x) => x ~/ kGridSize == i).length, lessThanOrEqualTo(4));
        expect(all.where((x) => x % kGridSize == i).length, lessThanOrEqualTo(4));
      }
    }
    // Zorluk artar.
    expect(levelSpec(30).cini.length, greaterThan(levelSpec(1).cini.length));
    expect(levelSpec(1).stones, isEmpty);
    expect(levelSpec(10).stones, isNotEmpty);
  });

  test('çini satırı patlayınca temizlenir, son çini bölümü kazandırır', () {
    const spec = LevelSpec(number: 1, moves: 10, cini: {3}, stones: {});
    final g = GameState(persist: false, level: spec);
    expect(g.ciniLeft, 1);
    expect(g.grid[0][3], kCiniColor);

    fillRowExcept(g, 0, 7);
    g.tray = [Piece(const [[0, 0]], Colors.red), null, null];
    g.place(0, 0, 7);

    expect(g.ciniLeft, 0);
    expect(g.grid[0][3], isNull);
    expect(g.levelWon, isTrue);
    expect(g.gameOver, isFalse);
    expect(g.movesLeft, 9);
    expect(g.starsEarned, 3);
  });

  test('taş ilk patlamada çatlar, ikincide kırılır (kesişim bir kez sayılır)', () {
    const spec = LevelSpec(number: 1, moves: 20, cini: {63}, stones: {0});
    final g = GameState(persist: false, level: spec);

    // Satır 0 ve sütun 0 aynı hamlede dolsun: (0,0) kesişimdeki taş yine tek kez çatlamalı.
    fillRowExcept(g, 0, 7);
    for (int r = 1; r < kGridSize; r++) {
      g.grid[r][0] = Colors.grey;
    }
    g.tray = [
      Piece(const [[0, 0]], Colors.red),
      Piece(const [[0, 0]], Colors.red),
      Piece(const [[0, 0]], Colors.red),
    ];
    g.place(0, 0, 7); // satır 0 tamam
    expect(g.special[0], Special.cracked);
    expect(g.grid[0][0], kStoneColor);

    // Satır 0'ı tekrar doldur → taş kırılır.
    fillRowExcept(g, 0, 7);
    g.place(1, 0, 7);
    expect(g.special.containsKey(0), isFalse);
    expect(g.grid[0][0], isNull);
  });

  test('hamle bitince ve çini kalmışsa bölüm kaybedilir; reklamla +5 hamle', () {
    const spec = LevelSpec(number: 1, moves: 1, cini: {27}, stones: {});
    final g = GameState(persist: false, level: spec);
    g.tray = [Piece(const [[0, 0]], Colors.red), null, null];
    g.place(0, 7, 7);
    expect(g.movesLeft, 0);
    expect(g.gameOver, isTrue);
    expect(g.levelWon, isFalse);

    g.continueGame();
    expect(g.gameOver, isFalse);
    expect(g.movesLeft, 5);
  });

  test('bölümde en iyi skor (Serbest rekoru) değişmez; newGame düzeni geri kurar', () {
    final g = GameState(persist: false, level: levelSpec(5));
    final before = g.bestScore;
    g.tray = [hLine(2), null, null];
    final placed = [
      for (int r = 0; r < kGridSize; r++)
        for (int c = 0; c < kGridSize - 1; c++)
          if (g.canPlace(g.tray[0]!, r, c)) [r, c]
    ].first;
    g.place(0, placed[0], placed[1]);
    expect(g.bestScore, before);

    g.newGame();
    expect(g.ciniLeft, levelSpec(5).cini.length);
    expect(g.movesLeft, levelSpec(5).moves);
  });
}
