import 'package:flutter/material.dart';
import 'game_state.dart';
import 'piece_widget.dart';
import 'board_widget.dart';
import 'ads/ad_banner.dart';
import 'ads/ad_interstitial.dart';
import 'sound_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameState game = GameState();
  int _prevTick = 0;
  bool _prevOver = false;

  @override
  void initState() {
    super.initState();
    game.addListener(_onGameChange);
  }

  @override
  void dispose() {
    game.removeListener(_onGameChange);
    super.dispose();
  }

  /// Oyun olaylarına göre ses çal (game_state saf tutuldu, ses UI'da).
  void _onGameChange() {
    if (game.animTick != _prevTick) {
      _prevTick = game.animTick;
      SoundService.instance.place();
      if (game.lastCleared.isNotEmpty) SoundService.instance.clear();
    }
    if (game.gameOver && !_prevOver) {
      SoundService.instance.gameOver();
      AdInterstitial.instance.notifyGameOver(); // her 3. oyun sonunda reklam
    }
    _prevOver = game.gameOver;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1035), Color(0xFF0E0A1F)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Tahta boyutunu hem genişliğe hem kullanılabilir yüksekliğe göre
              // sınırla; böylece küçük ekranlarda taşmaz.
              // Toplam ≈ başlık(150) + tahta*1.2 (alt algılama payı) +
              //          tray(tahta*0.425) + banner(~62) + kenar(40)
              final byHeight = (constraints.maxHeight - 252) / 1.625;
              final boardSize =
                  [width - 32, byHeight, 480.0].reduce((a, b) => a < b ? a : b)
                      .clamp(0.0, 480.0);
              final cellSize = boardSize / kGridSize;

              return AnimatedBuilder(
                animation: game,
                builder: (context, _) {
                  return Stack(
                    children: [
                      Column(
                        children: [
                          _header(),
                          const Spacer(),
                          Center(
                            child: BoardWidget(
                              game: game,
                              boardSize: boardSize,
                              cellSize: cellSize,
                            ),
                          ),
                          const Spacer(),
                          _tray(cellSize),
                          const SizedBox(height: 12),
                          const AdBanner(),
                        ],
                      ),
                      if (game.gameOver) _gameOverOverlay(),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kare Kare',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      await SoundService.instance.toggle();
                      setState(() {});
                    },
                    icon: Icon(
                      SoundService.instance.soundOn
                          ? Icons.volume_up
                          : Icons.volume_off,
                      color: Colors.white70,
                    ),
                    tooltip: 'Ses',
                  ),
                  IconButton(
                    onPressed: game.newGame,
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    tooltip: 'Yeniden başlat',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _scoreBox('SKOR', game.score, const Color(0xFF4D96FF)),
              _scoreBox('EN İYİ', game.bestScore, const Color(0xFFFFB400)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreBox(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tray(double cellSize) {
    final trayCell = cellSize * 0.62;
    return SizedBox(
      height: cellSize * 3.4,
      child: Row(
        children: [
          for (int i = 0; i < game.tray.length; i++)
            Expanded(child: Center(child: _traySlot(i, cellSize, trayCell))),
        ],
      ),
    );
  }

  Widget _traySlot(int index, double cellSize, double trayCell) {
    final piece = game.tray[index];
    if (piece == null) return const SizedBox.shrink();

    return Draggable<int>(
      data: index,
      dragAnchorStrategy: (draggable, context, position) {
        // İşaretçi parçanın alt-orta noktasının yarım hücre altında kalsın
        // → parça parmağın üstünde yüzer, feedback'in sol-üst köşesi
        //   details.offset olarak gelir (grid hücresi buradan hesaplanır).
        //   Küçük pay + tahtanın alt algılama uzantısı sayesinde en alt
        //   satır da rahat yerleştirilir.
        return Offset(
            piece.cols * cellSize / 2, piece.rows * cellSize + cellSize * 0.5);
      },
      feedback: PieceView(piece: piece, cellSize: cellSize),
      childWhenDragging:
          Opacity(opacity: 0.2, child: PieceView(piece: piece, cellSize: trayCell)),
      child: PieceView(piece: piece, cellSize: trayCell),
    );
  }

  Widget _gameOverOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A1B4D), Color(0xFF1B1035)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Oyun Bitti',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Skor: ${game.score}',
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
                Text(
                  'En iyi: ${game.bestScore}',
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: game.newGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4D96FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Tekrar Oyna'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
