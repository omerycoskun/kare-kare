import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'game_state.dart';
import 'piece_widget.dart';

class BoardWidget extends StatefulWidget {
  final GameState game;
  final double boardSize;
  final double cellSize;

  const BoardWidget({
    super.key,
    required this.game,
    required this.boardSize,
    required this.cellSize,
  });

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boardKey = GlobalKey();

  // Sürükleme önizleme durumu
  int? _previewTray;
  int? _previewRow;
  int? _previewCol;
  bool _previewValid = false;

  // Yerleşme/patlama animasyonu
  late final AnimationController _anim;
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// details.offset (feedback'in global sol-üst köşesi) → grid hücresi.
  void _computeCell(Offset globalOffset) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalOffset);
    _previewCol = (local.dx / widget.cellSize).round();
    _previewRow = (local.dy / widget.cellSize).round();
  }

  void _updatePreview(int trayIndex) {
    final piece = widget.game.tray[trayIndex];
    final ok = piece != null &&
        _previewRow != null &&
        widget.game.canPlace(piece, _previewRow!, _previewCol!);
    setState(() {
      _previewTray = trayIndex;
      _previewValid = ok;
    });
  }

  void _clearPreview() {
    setState(() {
      _previewTray = null;
      _previewRow = null;
      _previewCol = null;
      _previewValid = false;
    });
  }

  /// Önizleme için vurgulanacak hücreler: key = r*kGridSize + c.
  Map<int, Color> _previewCells() {
    final result = <int, Color>{};
    if (_previewTray == null || _previewRow == null || _previewCol == null) {
      return result;
    }
    final piece = widget.game.tray[_previewTray!];
    if (piece == null) return result;
    final base = _previewValid
        ? piece.color.withValues(alpha: 0.5)
        : Colors.red.withValues(alpha: 0.35);
    for (final cell in piece.cells) {
      final r = _previewRow! + cell[0];
      final c = _previewCol! + cell[1];
      if (r >= 0 && r < kGridSize && c >= 0 && c < kGridSize) {
        result[r * kGridSize + c] = base;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final boardSize = widget.boardSize;
    final cellSize = widget.cellSize;
    final game = widget.game;

    // Yeni hamle olduysa animasyonu başlat
    if (game.animTick != _lastTick) {
      _lastTick = game.animTick;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _anim.forward(from: 0);
      });
    }

    // Parmak parçanın altına inebilsin diye algılama alanını alta uzat.
    final slackBottom = cellSize * 1.6;
    final preview = _previewCells();
    final placedSet = {for (final p in game.lastPlaced) p[0] * kGridSize + p[1]};

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        _computeCell(details.offset);
        _updatePreview(details.data);
        return true; // her zaman kabul et; geçersizse place() reddeder
      },
      onMove: (details) {
        _computeCell(details.offset);
        _updatePreview(details.data);
      },
      onLeave: (_) => _clearPreview(),
      onAcceptWithDetails: (details) {
        _computeCell(details.offset);
        if (_previewRow != null && _previewCol != null) {
          game.place(details.data, _previewRow!, _previewCol!);
        }
        _clearPreview();
      },
      builder: (context, candidate, rejected) {
        return SizedBox(
          width: boardSize,
          height: boardSize + slackBottom,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Görünen tahta (koordinat hesabı bunun RenderBox'ına göre)
              Container(
                key: _boardKey,
                width: boardSize,
                height: boardSize,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(cellSize * 0.3),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Grid hücreleri
                    for (int r = 0; r < kGridSize; r++)
                      for (int c = 0; c < kGridSize; c++)
                        Positioned(
                          left: c * cellSize,
                          top: r * cellSize,
                          child: game.grid[r][c] != null
                              ? _AnimatedPlacedCell(
                                  color: game.grid[r][c]!,
                                  size: cellSize,
                                  anim: _anim,
                                  isNew: placedSet
                                      .contains(r * kGridSize + c),
                                )
                              : EmptyCell(
                                  size: cellSize,
                                  highlight: preview[r * kGridSize + c],
                                ),
                        ),
                    // Patlama efekti (üstte)
                    _BurstOverlay(
                      cleared: game.lastCleared,
                      cellSize: cellSize,
                      anim: _anim,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Yeni yerleştirilen hücre için hafif "pop" (büyüyüp yerine oturur).
class _AnimatedPlacedCell extends StatelessWidget {
  final Color color;
  final double size;
  final AnimationController anim;
  final bool isNew;

  const _AnimatedPlacedCell({
    required this.color,
    required this.size,
    required this.anim,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    if (!isNew) return BlockCell(color: color, size: size);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        // İlk %35'te 0.6 → 1.0 arası hafif zıplama
        final t = (anim.value / 0.35).clamp(0.0, 1.0);
        final scale = 0.6 + 0.4 * Curves.easeOutBack.transform(t);
        return Transform.scale(scale: scale, child: child);
      },
      child: BlockCell(color: color, size: size),
    );
  }
}

/// Patlayan hücreler için büyüyüp sönen renkli kareler.
class _BurstOverlay extends StatelessWidget {
  final Map<int, Color> cleared;
  final double cellSize;
  final AnimationController anim;

  const _BurstOverlay({
    required this.cleared,
    required this.cellSize,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    if (cleared.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = anim.value;
        if (t >= 1) return const SizedBox.shrink();
        final scale = 1 + 0.9 * t;
        final opacity = (1 - t).clamp(0.0, 1.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final entry in cleared.entries)
              Positioned(
                left: (entry.key % kGridSize) * cellSize,
                top: (entry.key ~/ kGridSize) * cellSize,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: cellSize,
                      height: cellSize,
                      padding: EdgeInsets.all(cellSize * 0.06),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color.lerp(entry.value, Colors.white, 0.4),
                          borderRadius: BorderRadius.circular(cellSize * 0.25),
                          boxShadow: [
                            BoxShadow(
                              color: entry.value.withValues(alpha: 0.6),
                              blurRadius: 8 * (1 - t),
                              spreadRadius: 2 * (1 - t),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
