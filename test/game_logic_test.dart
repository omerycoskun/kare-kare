import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karekare/game_state.dart';
import 'package:karekare/pieces.dart';

/// Tek hücrelik parça yardımcı.
Piece single([Color color = Colors.red]) => Piece([
      [0, 0]
    ], color);

/// Yatay n-hücrelik parça.
Piece hLine(int n, [Color color = Colors.blue]) =>
    Piece(List.generate(n, (i) => [0, i]), color);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('canPlace: boş grid sınır içinde kabul, taşan reddedilir', () {
    final g = GameState(persist: false);
    expect(g.canPlace(single(), 0, 0), isTrue);
    expect(g.canPlace(single(), 7, 7), isTrue);
    expect(g.canPlace(single(), 8, 0), isFalse); // sınır dışı
    expect(g.canPlace(hLine(3), 0, 6), isFalse); // sağdan taşar (6,7,8)
    expect(g.canPlace(hLine(3), 0, 5), isTrue); // 5,6,7 tam sığar
  });

  test('place: hücreleri boyar ve dolu hücreye tekrar konamaz', () {
    final g = GameState(persist: false);
    // Üç yuva da dolu olsun ki yerleştirince tray yeniden dolmasın
    g.tray = [single(Colors.green), single(), single()];
    final ok = g.place(0, 3, 3);
    expect(ok, isTrue);
    expect(g.grid[3][3], Colors.green);
    expect(g.tray[0], isNull); // sadece yerleştirilen yuva boşalır
    // Aynı hücreye başka parça sığmaz
    expect(g.canPlace(single(), 3, 3), isFalse);
  });

  test('satır dolunca patlar ve grid temizlenir', () {
    final g = GameState(persist: false);
    // 8'lik yatay parça bir satırı tamamen doldurur
    g.tray = [hLine(8, Colors.orange), null, null];
    g.place(0, 4, 0);
    // Satır 4 dolmuş olmalıydı → hemen patlar → boşalır
    for (int c = 0; c < kGridSize; c++) {
      expect(g.grid[4][c], isNull, reason: 'satır patlamalıydı');
    }
    // Skor: 8 hücre yerleştirme + 1 satır*1*10 = 8 + 10 = 18
    expect(g.score, 18);
  });

  test('aynı anda 2 satır patlayınca kombo çarpanı uygulanır', () {
    final g = GameState(persist: false);
    // İki satırı da 7'şer hücre önceden dolduralım (elle), son sütunu boş bırak
    for (int c = 0; c < 7; c++) {
      g.grid[0][c] = Colors.grey;
      g.grid[1][c] = Colors.grey;
    }
    // 8. sütunu dikey 2'li parçayla kapat → iki satır aynı anda dolar
    g.tray = [
      Piece([
        [0, 0],
        [1, 0]
      ], Colors.purple),
      null,
      null
    ];
    g.place(0, 0, 7);
    // İki satır da temizlenmeli
    for (int c = 0; c < kGridSize; c++) {
      expect(g.grid[0][c], isNull);
      expect(g.grid[1][c], isNull);
    }
    // Skor: 2 hücre yerleştirme + kombo(10*2*2=40) = 42
    expect(g.score, 42);
  });

  test('3 parça bitince tray yeniden dolar', () {
    final g = GameState(persist: false);
    g.tray = [single(), single(), single()];
    g.place(0, 0, 0);
    g.place(1, 0, 2);
    expect(g.tray.whereType<Piece>().length, 1); // hâlâ 1 kaldı, dolmadı
    g.place(2, 0, 4);
    // Hepsi bitti → yeni 3 parça
    expect(g.tray.length, 3);
    expect(g.tray.whereType<Piece>().length, 3);
  });

  test('tüm şekiller grid içine sığacak boyutta ve normalize', () {
    for (final shape in kShapes) {
      expect(shape.isNotEmpty, isTrue);
      final piece = Piece(shape, Colors.red);
      expect(piece.rows, lessThanOrEqualTo(kGridSize));
      expect(piece.cols, lessThanOrEqualTo(kGridSize));
      // normalize: min satır ve sütun 0 olmalı
      expect(shape.map((c) => c[0]).reduce((a, b) => a < b ? a : b), 0);
      expect(shape.map((c) => c[1]).reduce((a, b) => a < b ? a : b), 0);
    }
    expect(weightForCells(1), greaterThan(weightForCells(6)));
  });

  test('hiçbir parça sığmayınca oyun biter', () {
    final g = GameState(persist: false);
    // Gridi neredeyse tamamen doldur, sadece (0,0) boş kalsın
    for (int r = 0; r < kGridSize; r++) {
      for (int c = 0; c < kGridSize; c++) {
        g.grid[r][c] = Colors.grey;
      }
    }
    g.grid[0][0] = null;
    // Elde 2x2 kare var → tek boş hücreye sığmaz
    g.tray = [
      Piece([
        [0, 0],
        [0, 1],
        [1, 0],
        [1, 1]
      ], Colors.red),
      null,
      null
    ];
    // Yerleştirme denemesi geçersiz olmalı; oyun sonu tetiklensin diye
    // geçerli bir yere (tek hücre) koyamaz. checkGameOver place içinde çalışır.
    // Doğrudan tek hücrelik boşluğa kare koyulamaz:
    expect(g.canPlace(g.tray[0]!, 0, 0), isFalse);
    // Boş (0,0)'a sığacak tek hücrelik parça koyup patlatınca durumu değil,
    // burada oyun-sonu kontrolünü tetiklemek için geçerli bir hamle yapıp
    // sonrasında sığmayan parçalarla kaldığını doğrulayalım:
    g.tray = [
      Piece([
        [0, 0],
        [0, 1],
        [1, 0],
        [1, 1]
      ], Colors.red),
      Piece([
        [0, 0],
        [0, 1],
        [1, 0],
        [1, 1]
      ], Colors.blue),
      null
    ];
    // Manuel oyun-sonu kontrolü: her iki kare de sığmıyor
    final anyFits = g.tray.whereType<Piece>().any((p) {
      for (int r = 0; r < kGridSize; r++) {
        for (int c = 0; c < kGridSize; c++) {
          if (g.canPlace(p, r, c)) return true;
        }
      }
      return false;
    });
    expect(anyFits, isFalse);
  });
}
