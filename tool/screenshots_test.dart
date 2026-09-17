// App Store ekran görüntülerini gerçek ekranlardan üretir; parçaları gerçek
// oyun kurallarıyla yerleştiren basit bir otopilot oynar. Çalıştır:
//   flutter test tool/screenshots_test.dart
// Çıktı: build/screenshots/{phone,ipad}_N.png
// ignore_for_file: invalid_use_of_visible_for_testing_member, avoid_dynamic_calls
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karekare/game_screen.dart';
import 'package:karekare/game_state.dart';
import 'package:karekare/home_screen.dart';
import 'package:karekare/levels.dart';
import 'package:karekare/levels_screen.dart';
import 'package:karekare/pieces.dart';
import 'package:karekare/sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fontDir = r'C:\src\flutter\bin\cache\artifacts\material_fonts';

Future<void> _loadFonts() async {
  Future<ByteData> f(String name) async => ByteData.sublistView(File('$_fontDir\\$name').readAsBytesSync());
  for (final family in ['Roboto', 'FlutterTest']) {
    await (FontLoader(family)
          ..addFont(f('roboto-regular.ttf'))
          ..addFont(f('roboto-medium.ttf'))
          ..addFont(f('roboto-bold.ttf'))
          ..addFont(f('roboto-black.ttf')))
        .load();
  }
  await (FontLoader('MaterialIcons')..addFont(f('materialicons-regular.otf'))).load();
}

/// Eklenti kanallarını (reklam, ses) test ortamında sessizce başarılı yanıtla.
void _mockPlugins() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in [
    'plugins.flutter.io/google_mobile_ads',
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers.global/events',
    for (final id in ['place', 'clear', 'over']) 'xyz.luan/audioplayers/events/$id',
  ]) {
    messenger.setMockMessageHandler(channel, (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null));
  }
}

class _Device {
  const _Device(this.name, this.physical, this.dpr);
  final String name;
  final Size physical;
  final double dpr;
}

const _devices = [
  _Device('phone', Size(1242, 2688), 3),
  _Device('ipad', Size(2048, 2732), 2),
];

final _boundary = GlobalKey();

Widget _frame(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F6FB2), brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: RepaintBoundary(key: _boundary, child: child),
    );

Future<void> _capture(WidgetTester tester, _Device d, int index) async {
  await tester.runAsync(() async {
    final ro = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: d.dpr);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/screenshots').createSync(recursive: true);
    File('build/screenshots/${d.name}_$index.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Otopilot hamlesi: satır/sütunları en çok dolduran geçerli yerleşimi seçer.
/// Başarılıysa temizlenen hücre sayısını döner; hamle yoksa -1.
int _autoMove(GameState g, {bool avoidWin = false}) {
  var best = -1.0;
  List<int>? choice;
  for (var t = 0; t < g.tray.length; t++) {
    final piece = g.tray[t];
    if (piece == null) continue;
    for (var r = 0; r < kGridSize; r++) {
      for (var c = 0; c < kGridSize; c++) {
        if (!g.canPlace(piece, r, c)) continue;
        final rows = {for (final cell in piece.cells) r + cell[0]};
        final cols = {for (final cell in piece.cells) c + cell[1]};
        var score = 0.0;
        for (final rr in rows) {
          score += List.generate(kGridSize, (x) => g.grid[rr][x] != null).where((x) => x).length;
        }
        for (final cc in cols) {
          score += List.generate(kGridSize, (x) => g.grid[x][cc] != null).where((x) => x).length;
        }
        score += piece.cellCount * 2 + (r + c) * 0.01;
        if (score > best) {
          best = score;
          choice = [t, r, c];
        }
      }
    }
  }
  if (choice == null) return -1;
  final ciniBefore = g.ciniLeft;
  final snapshot = [for (final row in g.grid) [...row]];
  final specials = Map<int, Special>.of(g.special);
  g.place(choice[0], choice[1], choice[2]);
  if (avoidWin && g.levelWon) {
    // Ekran görüntüsünde bölüm henüz bitmemiş görünsün: son hamleyi geri al.
    g.grid = snapshot;
    g.special = specials;
    g.levelWon = false;
    g.movesLeft++;
    return -1;
  }
  return ciniBefore - g.ciniLeft + g.lastCleared.length;
}

/// Test ortamında yerleşme "pop" animasyonu ilk karede kalabiliyor; görüntüden
/// önce yeni yerleşen hücre işaretini temizle (hücreler tam boyda çizilsin).
void _settle(GameState g) {
  g.lastPlaced = [];
  (g as dynamic).notifyListeners();
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    _mockPlugins();
  });

  for (final d in _devices) {
    testWidgets('screenshots ${d.name}', (tester) async {
      tester.view.physicalSize = d.physical;
      tester.view.devicePixelRatio = d.dpr;
      addTearDown(tester.view.reset);

      const earned = [3, 3, 2, 3, 3, 2, 3, 1, 3, 2, 3];
      SharedPreferences.setMockInitialValues({
        'soundOn': false,
        'bestScore': 2480,
        for (var i = 0; i < earned.length; i++) 'level_stars_${i + 1}': earned[i],
      });
      await LevelProgress.instance.load();
      SoundService.instance.soundOn = false;

      // 1) Bölüm oyunu (taşlı bölüm, oyun ortası)
      final level = levelSpec(12);
      await tester.pumpWidget(_frame(GameScreen(level: level)));
      await tester.pump(const Duration(milliseconds: 50));
      final lvlGame = (tester.state(find.byType(GameScreen)) as dynamic).game as GameState;
      lvlGame.tray = [
        Piece(kShapes[9], kPieceColors[2]),
        Piece(kShapes[5], kPieceColors[0]),
        Piece(kShapes[23], kPieceColors[4]),
      ];
      for (var i = 0; i < 7; i++) {
        if (_autoMove(lvlGame, avoidWin: true) < 0) break;
      }
      _settle(lvlGame);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 600));
      await _capture(tester, d, 1);

      // 2) Bölüm seçimi
      await tester.pumpWidget(_frame(const LevelsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await _capture(tester, d, 2);

      // 3) Ana menü
      await tester.pumpWidget(_frame(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await _capture(tester, d, 3);

      // 4) Serbest oyun: bir patlatma anında (kombo yazısı ekranda).
      await tester.pumpWidget(_frame(const GameScreen()));
      await tester.pump(const Duration(milliseconds: 50));
      final free = (tester.state(find.byType(GameScreen)) as dynamic).game as GameState;
      var captured = false;
      for (var i = 0; i < 400 && !captured; i++) {
        final cleared = _autoMove(free);
        if (cleared < 0) {
          free.newGame();
          continue;
        }
        await tester.pump(const Duration(milliseconds: 16));
        final filled = free.grid.expand((r) => r).where((c) => c != null).length;
        if (cleared > 0 && free.score > 80 && filled >= 12) {
          await tester.pump(const Duration(milliseconds: 380));
          _settle(free);
          await tester.pump(const Duration(milliseconds: 16));
          captured = true;
        } else {
          await tester.pump(const Duration(milliseconds: 900));
        }
      }
      if (!captured) {
        _settle(free);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await _capture(tester, d, 4);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
