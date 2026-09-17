import 'dart:math';

import 'package:flutter/material.dart';
import 'game_state.dart';
import 'home_screen.dart';
import 'levels.dart';
import 'piece_widget.dart';
import 'board_widget.dart';
import 'ads/ad_banner.dart';
import 'ads/ad_interstitial.dart';
import 'ads/ad_rewarded.dart';
import 'sound_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.level});

  /// Çini Macerası bölümü; null ise Serbest oyun.
  final LevelSpec? level;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late final GameState game = GameState(level: widget.level);
  bool _prevWon = false;
  int _prevTick = 0;
  bool _prevOver = false;
  bool _watchingAd = false;

  // Kombo / motive edici yazı animasyonu
  late final AnimationController _comboAnim;
  String? _comboText;

  // Tahta tamamen temizlenince abartılı kutlama (konfeti + parlama + yazı)
  late final AnimationController _celebrateAnim;
  final List<_Confetti> _confetti = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _comboAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _celebrateAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    game.addListener(_onGameChange);
  }

  @override
  void dispose() {
    game.removeListener(_onGameChange);
    _comboAnim.dispose();
    _celebrateAnim.dispose();
    super.dispose();
  }

  void _spawnConfetti() {
    _confetti.clear();
    const colors = [
      Color(0xFFFF5A5F), Color(0xFFFFB400), Color(0xFF2EC4B6),
      Color(0xFF4D96FF), Color(0xFF9B5DE5), Color(0xFFF15BB5),
      Color(0xFF52B788), Color(0xFFFF8C42),
    ];
    for (int i = 0; i < 70; i++) {
      _confetti.add(_Confetti(
        angle: _rng.nextDouble() * 2 * pi,
        speed: 140 + _rng.nextDouble() * 340,
        color: colors[_rng.nextInt(colors.length)],
        rot: _rng.nextDouble() * 2 * pi,
        size: 9 + _rng.nextDouble() * 9,
      ));
    }
  }

  /// Oyun olaylarına göre ses + kombo/kutlama (game_state saf, efektler UI'da).
  void _onGameChange() {
    if (game.animTick != _prevTick) {
      _prevTick = game.animTick;
      SoundService.instance.place();
      if (game.lastCleared.isNotEmpty) SoundService.instance.clear();
      if (game.boardCleared) {
        // Tahta tamamen temiz → abartılı kutlama (kombo yazısı yerine)
        _spawnConfetti();
        _celebrateAnim.forward(from: 0);
        SoundService.instance.clear();
      } else if (game.lastMessage != null) {
        _comboText = game.lastMessage;
        _comboAnim.forward(from: 0);
      }
    }
    if (game.levelWon && !_prevWon) SoundService.instance.clear();
    _prevWon = game.levelWon;
    if (game.gameOver && !_prevOver) {
      SoundService.instance.gameOver();
      AdInterstitial.instance.notifyGameOver(); // her 2. oyun sonunda reklam
    }
    _prevOver = game.gameOver;
  }

  bool get _canContinue => !game.usedContinue && AdRewarded.instance.isReady;

  Future<void> _watchAndContinue() async {
    if (_watchingAd) return;
    setState(() => _watchingAd = true);
    final ok = await AdRewarded.instance.showContinue();
    if (!mounted) return;
    setState(() => _watchingAd = false);
    if (ok) game.continueGame();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: CiniBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
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
                      _comboOverlay(),
                      _celebrateOverlay(),
                      if (game.gameOver) _gameOverOverlay(),
                      if (game.levelWon) _winOverlay(),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                    tooltip: 'Geri',
                  ),
                  Text(
                    widget.level == null ? 'Serbest Oyun' : 'Bölüm ${widget.level!.number}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
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
            children: widget.level == null
                ? [
                    _scoreBox('SKOR', game.score, const Color(0xFF4D96FF)),
                    _scoreBox('EN İYİ', game.bestScore, const Color(0xFFFFB400)),
                  ]
                : [
                    _scoreBox('HAMLE', game.movesLeft,
                        game.movesLeft <= 3 ? const Color(0xFFFF5A5F) : const Color(0xFF2EC4B6)),
                    _scoreBox('ÇİNİ', game.ciniLeft, const Color(0xFF7FB8FF)),
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
            Expanded(child: _traySlot(i, cellSize, trayCell)),
        ],
      ),
    );
  }

  /// Her yuva, tüm alanı sürüklenebilir bir "kutu" (dolu renkli zemin sayesinde
  /// boşluklara basınca da algılanır → çok daha hassas). Parça ortada durur.
  Widget _traySlot(int index, double cellSize, double trayCell) {
    final piece = game.tray[index];

    Widget tile(Widget child) => Container(
          constraints: const BoxConstraints.expand(),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(cellSize * 0.3),
          ),
          alignment: Alignment.center,
          child: child,
        );

    if (piece == null) {
      return Padding(
        padding: EdgeInsets.all(cellSize * 0.12),
        child: tile(const SizedBox.shrink()),
      );
    }

    return Padding(
      padding: EdgeInsets.all(cellSize * 0.12),
      child: Draggable<int>(
        data: index,
        dragAnchorStrategy: (draggable, context, position) {
          // Parça parmağın üstünde yüzsün; feedback sol-üst köşesi details.offset
          // olarak gelir (grid hücresi buradan hesaplanır).
          return Offset(
              piece.cols * cellSize / 2, piece.rows * cellSize + cellSize * 0.5);
        },
        feedback: PieceView(piece: piece, cellSize: cellSize),
        childWhenDragging: tile(
          Opacity(opacity: 0.15, child: PieceView(piece: piece, cellSize: trayCell)),
        ),
        child: tile(PieceView(piece: piece, cellSize: trayCell)),
      ),
    );
  }

  /// Patlatma/kombo anında ekranda beliren motive edici yazı.
  Widget _comboOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _comboAnim,
          builder: (context, _) {
            final t = _comboAnim.value;
            if (t <= 0 || t >= 1 || _comboText == null) {
              return const SizedBox.shrink();
            }
            final appear = (t / 0.22).clamp(0.0, 1.0);
            final disappear = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
            final scale = 0.4 + 0.9 * Curves.easeOutBack.transform(appear);
            final opacity = 1 - disappear;
            return Align(
              alignment: const Alignment(0, -0.32),
              child: Transform.translate(
                offset: Offset(0, -40 * disappear),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: Text(
                      _comboText!,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                        shadows: [
                          Shadow(color: Color(0xFFF15BB5), blurRadius: 18),
                          Shadow(color: Color(0xFFFFB400), blurRadius: 30),
                          Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Tahta tamamen temizlenince: abartılı konfeti + parlama + dev "MÜKEMMEL!".
  Widget _celebrateOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _celebrateAnim,
          builder: (context, _) {
            final t = _celebrateAnim.value;
            if (t <= 0 || t >= 1) return const SizedBox.shrink();
            final textIn = (t / 0.35).clamp(0.0, 1.0);
            final textOut = ((t - 0.75) / 0.25).clamp(0.0, 1.0);
            return Stack(
              children: [
                // Ekran parlaması (altın radial), sönerek
                Positioned.fill(
                  child: Opacity(
                    opacity: (1 - t) * 0.45,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [Color(0xFFFFE082), Colors.transparent],
                          radius: 0.9,
                        ),
                      ),
                    ),
                  ),
                ),
                // Konfeti (merkezden patlar, yerçekimiyle düşer)
                for (final c in _confetti)
                  Align(
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: Offset(
                        cos(c.angle) * c.speed * t,
                        sin(c.angle) * c.speed * t + 520 * t * t,
                      ),
                      child: Transform.rotate(
                        angle: c.rot + t * 8,
                        child: Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0),
                          child: Container(
                            width: c.size,
                            height: c.size,
                            decoration: BoxDecoration(
                              color: c.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Dev "MÜKEMMEL!" + alt yazı
                Align(
                  alignment: const Alignment(0, -0.1),
                  child: Opacity(
                    opacity: 1 - textOut,
                    child: Transform.scale(
                      scale: 0.4 + 0.9 * Curves.elasticOut.transform(textIn),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'MÜKEMMEL!',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1,
                              shadows: [
                                Shadow(color: Color(0xFFFFB400), blurRadius: 24),
                                Shadow(color: Color(0xFFF15BB5), blurRadius: 40),
                                Shadow(
                                    color: Colors.black54,
                                    blurRadius: 6,
                                    offset: Offset(0, 3)),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'TAHTA TEMİZ! 🎉  +300',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFFD54F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _gameOverOverlay() {
    final canContinue = _canContinue;
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
                colors: [Color(0xFF1C3566), Color(0xFF12254A)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.level == null
                      ? 'Oyun Bitti'
                      : (game.movesLeft <= 0 ? 'Hamle Bitti' : 'Yer Kalmadı'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.level == null) ...[
                  Text(
                    'Skor: ${game.score}',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  Text(
                    'En iyi: ${game.bestScore}',
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ] else
                  Text(
                    'Kalan çini: ${game.ciniLeft}',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                const SizedBox(height: 24),
                if (canContinue) ...[
                  _overlayButton(
                    label: _watchingAd
                        ? 'Yükleniyor...'
                        : (widget.level != null && game.movesLeft <= 0 ? 'İzle & +5 Hamle' : 'İzle & Devam Et'),
                    icon: Icons.ondemand_video,
                    color: const Color(0xFF52B788),
                    onPressed: _watchingAd ? null : _watchAndContinue,
                  ),
                  const SizedBox(height: 12),
                  _overlayButton(
                    label: widget.level == null ? 'Hayır, Baştan' : 'Tekrar Dene',
                    icon: Icons.refresh,
                    color: const Color(0xFF4D96FF),
                    onPressed: game.newGame,
                  ),
                ] else
                  _overlayButton(
                    label: widget.level == null ? 'Tekrar Oyna' : 'Tekrar Dene',
                    icon: Icons.refresh,
                    color: const Color(0xFF4D96FF),
                    onPressed: game.newGame,
                  ),
                if (widget.level != null) ...[
                  const SizedBox(height: 12),
                  _overlayButton(
                    label: 'Bölümler',
                    icon: Icons.map_rounded,
                    color: const Color(0xFF1F6FB2),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bölüm kazanıldı: yıldızlar + sonraki bölüm.
  Widget _winOverlay() {
    final level = widget.level!;
    final stars = game.starsEarned;
    final hasNext = level.number < kLevelCount;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8FF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1F6FB2), width: 4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bölüm ${level.number} Tamam!',
                  style: const TextStyle(color: Color(0xFF12254A), fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 1; s <= 3; s++)
                      Padding(
                        padding: EdgeInsets.only(bottom: s == 2 ? 14 : 0),
                        child: Icon(
                          Icons.star_rounded,
                          size: s == 2 ? 64 : 50,
                          color: s <= stars ? const Color(0xFFFFB400) : Colors.black12,
                        ),
                      ),
                  ],
                ),
                Text(
                  'Kalan hamle: ${game.movesLeft}  •  Skor: ${game.score}',
                  style: const TextStyle(color: Color(0xFF12254A), fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 22),
                if (hasNext) ...[
                  _overlayButton(
                    label: 'Sonraki Bölüm',
                    icon: Icons.arrow_forward_rounded,
                    color: const Color(0xFF2EC4B6),
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => GameScreen(level: levelSpec(level.number + 1))),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _overlayButton(
                  label: 'Bölümler',
                  icon: Icons.map_rounded,
                  color: const Color(0xFF1F6FB2),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 240,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Kutlama konfetisi parçacığı.
class _Confetti {
  final double angle;
  final double speed;
  final Color color;
  final double rot;
  final double size;
  const _Confetti({
    required this.angle,
    required this.speed,
    required this.color,
    required this.rot,
    required this.size,
  });
}
