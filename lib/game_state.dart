import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pieces.dart';

const int kGridSize = 8;

class GameState extends ChangeNotifier {
  /// null = boş hücre, Color = dolu hücrenin rengi.
  List<List<Color?>> grid =
      List.generate(kGridSize, (_) => List.filled(kGridSize, null));

  /// Alttaki 3 blok yuvası (yerleştirilen null olur).
  List<Piece?> tray = [];

  int score = 0;
  int bestScore = 0;
  bool gameOver = false;

  /// Son hamlede yerleştirilen hücreler [r, c] (yerleşme animasyonu için).
  List<List<int>> lastPlaced = [];

  /// Son hamlede patlayan hücreler: r*kGridSize+c -> renk (patlama efekti için).
  Map<int, Color> lastCleared = {};

  /// Her hamlede artar; board animasyonu bunu izleyip tetiklenir.
  int animTick = 0;

  final Random _rng = Random();
  SharedPreferences? _prefs;
  final bool _persist;

  // ignore: prefer_initializing_formals
  GameState({bool persist = true}) : _persist = persist {
    _refillTray(); // tray hemen hazır olsun (senkron)
    if (_persist) _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    bestScore = _prefs?.getInt('bestScore') ?? 0;
    notifyListeners();
  }

  void newGame() {
    grid = List.generate(kGridSize, (_) => List.filled(kGridSize, null));
    score = 0;
    gameOver = false;
    lastPlaced = [];
    lastCleared = {};
    _refillTray();
    notifyListeners();
  }

  void _refillTray() {
    tray = List.generate(3, (_) => _randomPiece());
  }

  Piece _randomPiece() {
    final shape = _weightedShape();
    final color = kPieceColors[_rng.nextInt(kPieceColors.length)];
    return Piece(shape, color);
  }

  /// Hücre sayısına göre ağırlıklı şekil seçimi (zorluk + çeşitlilik).
  List<List<int>> _weightedShape() {
    final total =
        kShapes.fold<int>(0, (s, sh) => s + weightForCells(sh.length));
    var pick = _rng.nextInt(total);
    for (final sh in kShapes) {
      pick -= weightForCells(sh.length);
      if (pick < 0) return sh;
    }
    return kShapes.last;
  }

  /// Verilen parça, sol-üst köşesi (row, col) olacak şekilde yerleştirilebilir mi?
  bool canPlace(Piece piece, int row, int col) {
    for (final cell in piece.cells) {
      final r = row + cell[0];
      final c = col + cell[1];
      if (r < 0 || r >= kGridSize || c < 0 || c >= kGridSize) return false;
      if (grid[r][c] != null) return false;
    }
    return true;
  }

  /// Parça grid'in herhangi bir yerine sığar mı? (oyun sonu kontrolü için)
  bool _canPlaceAnywhere(Piece piece) {
    for (int r = 0; r < kGridSize; r++) {
      for (int c = 0; c < kGridSize; c++) {
        if (canPlace(piece, r, c)) return true;
      }
    }
    return false;
  }

  /// Parçayı yuvadan yerleştirir. Başarılıysa true döner.
  bool place(int trayIndex, int row, int col) {
    final piece = tray[trayIndex];
    if (piece == null || gameOver) return false;
    if (!canPlace(piece, row, col)) return false;

    lastPlaced = [];
    lastCleared = {};

    // Hücreleri boya
    for (final cell in piece.cells) {
      final r = row + cell[0];
      final c = col + cell[1];
      grid[r][c] = piece.color;
      lastPlaced.add([r, c]);
    }
    score += piece.cellCount;

    // Yuvadan çıkar
    tray[trayIndex] = null;

    // Dolan satır/sütunları patlat
    _clearLines();

    // Tüm yuvalar boşaldıysa yeni bloklar
    if (tray.every((p) => p == null)) {
      _refillTray();
    }

    // Oyun sonu kontrolü
    _checkGameOver();

    // En yüksek skoru güncelle
    if (score > bestScore) {
      bestScore = score;
      if (_persist) _prefs?.setInt('bestScore', bestScore);
    }

    animTick++;
    notifyListeners();
    return true;
  }

  void _clearLines() {
    final fullRows = <int>[];
    final fullCols = <int>[];

    for (int r = 0; r < kGridSize; r++) {
      if (List.generate(kGridSize, (c) => grid[r][c]).every((x) => x != null)) {
        fullRows.add(r);
      }
    }
    for (int c = 0; c < kGridSize; c++) {
      if (List.generate(kGridSize, (r) => grid[r][c]).every((x) => x != null)) {
        fullCols.add(c);
      }
    }

    final totalLines = fullRows.length + fullCols.length;
    if (totalLines == 0) return;

    // Patlayan hücreleri renkleriyle kaydet (efekt için), sonra temizle
    for (final r in fullRows) {
      for (int c = 0; c < kGridSize; c++) {
        if (grid[r][c] != null) lastCleared[r * kGridSize + c] = grid[r][c]!;
        grid[r][c] = null;
      }
    }
    for (final c in fullCols) {
      for (int r = 0; r < kGridSize; r++) {
        if (grid[r][c] != null) lastCleared[r * kGridSize + c] = grid[r][c]!;
        grid[r][c] = null;
      }
    }

    // Skor: satır başına 10 puan, aynı anda çok satır = kombo çarpanı
    score += 10 * totalLines * totalLines;
  }

  void _checkGameOver() {
    final remaining = tray.whereType<Piece>();
    if (remaining.isEmpty) return; // yeni blok gelecek
    final anyFits = remaining.any(_canPlaceAnywhere);
    if (!anyFits) {
      gameOver = true;
    }
  }
}
