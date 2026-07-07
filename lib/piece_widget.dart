import 'package:flutter/material.dart';
import 'pieces.dart';

/// Tek bir dolu hücreyi çizer (yuvarlak köşe + hafif parlaklık).
class BlockCell extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const BlockCell({
    super.key,
    required this.color,
    required this.size,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.22;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, 0.25)!.withValues(alpha: opacity),
              color.withValues(alpha: opacity),
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: opacity == 1
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// Boş bir grid hücresi (arka plan).
class EmptyCell extends StatelessWidget {
  final double size;
  final Color? highlight;

  const EmptyCell({super.key, required this.size, this.highlight});

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.22;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      child: Container(
        decoration: BoxDecoration(
          color: highlight ?? Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Bir parçayı [cellSize] hücre boyutuyla çizer.
class PieceView extends StatelessWidget {
  final Piece piece;
  final double cellSize;
  final double opacity;

  const PieceView({
    super.key,
    required this.piece,
    required this.cellSize,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: piece.cols * cellSize,
      height: piece.rows * cellSize,
      child: Stack(
        children: [
          for (final cell in piece.cells)
            Positioned(
              left: cell[1] * cellSize,
              top: cell[0] * cellSize,
              child: BlockCell(
                color: piece.color,
                size: cellSize,
                opacity: opacity,
              ),
            ),
        ],
      ),
    );
  }
}
