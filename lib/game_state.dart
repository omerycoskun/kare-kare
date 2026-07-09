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

  /// Ardışık patlatma serisi (her patlatan hamlede artar, patlamayınca sıfırlanır).
  int combo = 0;

  /// Son hamlede gösterilecek motive edici mesaj (KOMBO x2, SÜPER! vb.), yoksa null.
  String? lastMessage;

  /// Bu oyunda "reklam izle & devam et" hakkı kullanıldı mı (oyun başına 1).
  bool usedContinue = false;

  /// Son hamlede tahta tamamen temizlendi mi (mükemmel temizlik kutlaması).
  bool boardCleared = false;

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
    combo = 0;
    lastMessage = null;
    usedContinue = false;
    boardCleared = false;
    lastPlaced = [];
    lastCleared = {};
    _refillTray();
    notifyListeners();
  }

  /// "Reklam izle & devam et": tahtaya DOKUNMAZ, skoru korur; sadece son eldeki
  /// (sığmayan) parçaları yenileriyle değiştirir → kaldığın yerden devam.
  void continueGame() {
    gameOver = false;
    usedContinue = true;
    combo = 0;
    lastMessage = null;
    lastPlaced = [];
    lastCleared = {};
    _refillPlayableTray();
    animTick++;
    notifyListeners();
  }

  /// Yeni 3 parça üretir; hiçbiri sığmıyorsa ilkini tek hücrelik yapar (boş
  /// hücre olduğu sürece sığar) → "devam et" her zaman oynanabilir olur.
  void _refillPlayableTray() {
    tray = List.generate(3, (_) => _randomPiece());
    if (!tray.whereType<Piece>().any(_canPlaceAnywhere)) {
      tray[0] =
          Piece(kShapes[0], kPieceColors[_rng.nextInt(kPieceColors.length)]);
    }
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

    // Dolan satır/sütunları patlat (kombo serisi + motive edici mesaj)
    boardCleared = false;
    final lines = _clearLines();
    if (lines > 0) {
      combo++;
      // Kombo çarpanı: ardışık patlatmada skor giderek artar
      score += 10 * lines * lines * combo;
      // Tahta tamamen temizlendiyse: büyük bonus + mükemmel temizlik kutlaması
      if (_isBoardEmpty()) {
        boardCleared = true;
        score += 300;
        lastMessage = 'MÜKEMMEL!';
      } else {
        lastMessage = _messageFor(lines, combo);
      }
    } else {
      combo = 0;
      lastMessage = null;
    }

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

  /// Tahta tamamen boş mu?
  bool _isBoardEmpty() {
    for (final row in grid) {
      for (final c in row) {
        if (c != null) return false;
      }
    }
    return true;
  }

  /// Motive edici mesaj: kombo varsa onu, yoksa temizlenen satır sayısına göre.
  String _messageFor(int lines, int combo) {
    if (combo >= 2) return 'KOMBO x$combo!';
    if (lines >= 3) return 'İNANILMAZ!';
    if (lines == 2) return 'SÜPER!';
    return 'GÜZEL!';
  }

  /// Dolan satır/sütunları temizler; temizlenen toplam satır sayısını döndürür.
  int _clearLines() {
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
    if (totalLines == 0) return 0;

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

    return totalLines;
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
