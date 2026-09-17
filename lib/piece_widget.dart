import 'package:flutter/material.dart';
import 'game_state.dart';
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

/// Çini Macerası'nın özel hücresi: çini karo, taş ya da çatlamış taş.
class SpecialCell extends StatelessWidget {
  final Special kind;
  final double size;

  const SpecialCell({super.key, required this.kind, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _SpecialPainter(kind));
  }
}

class _SpecialPainter extends CustomPainter {
  _SpecialPainter(this.kind);
  final Special kind;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Rect.fromLTWH(s * 0.06, s * 0.06, s * 0.88, s * 0.88);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.2));
    if (kind == Special.cini) {
      paintCiniTile(canvas, rrect);
    } else {
      _paintStone(canvas, rrect, cracked: kind == Special.cracked);
    }
  }

  void _paintStone(Canvas canvas, RRect rrect, {required bool cracked}) {
    final r = rrect.outerRect;
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB9BECC), Color(0xFF7A7F92)],
        ).createShader(r),
    );
    final speck = Paint()..color = const Color(0x553A3F52);
    for (final o in const [Offset(0.25, 0.3), Offset(0.7, 0.25), Offset(0.4, 0.72), Offset(0.78, 0.68)]) {
      canvas.drawCircle(Offset(r.left + r.width * o.dx, r.top + r.height * o.dy), r.width * 0.06, speck);
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.width * 0.06
        ..color = const Color(0xFF4A4F63),
    );
    if (cracked) {
      final crack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.width * 0.07
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF2B2F3D);
      final path = Path()
        ..moveTo(r.left + r.width * 0.2, r.top + r.height * 0.15)
        ..lineTo(r.left + r.width * 0.45, r.top + r.height * 0.45)
        ..lineTo(r.left + r.width * 0.35, r.top + r.height * 0.62)
        ..lineTo(r.left + r.width * 0.62, r.top + r.height * 0.88)
        ..moveTo(r.left + r.width * 0.45, r.top + r.height * 0.45)
        ..lineTo(r.left + r.width * 0.8, r.top + r.height * 0.35);
      canvas.drawPath(path, crack);
    }
  }

  @override
  bool shouldRepaint(_SpecialPainter old) => old.kind != kind;
}

/// Kobalt/turkuaz çini karo: sekiz köşeli yıldız + göbek + köşe lale noktaları.
void paintCiniTile(Canvas canvas, RRect rrect) {
  final r = rrect.outerRect;
  final c = r.center;
  final w = r.width;
  canvas.drawRRect(rrect, Paint()..color = const Color(0xFFF3F8FF));
  // Sekiz köşeli yıldız: üst üste iki kare (biri 45° döndürülmüş).
  final star = Paint()..color = const Color(0xFF1F6FB2);
  for (final angle in [0.0, 0.7853981633974483]) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w * 0.52, height: w * 0.52), star);
    canvas.restore();
  }
  canvas.drawCircle(c, w * 0.17, Paint()..color = const Color(0xFF2EC4B6));
  canvas.drawCircle(c, w * 0.07, Paint()..color = const Color(0xFFE63946));
  final dot = Paint()..color = const Color(0xFFE63946);
  for (final o in const [Offset(0.14, 0.14), Offset(0.86, 0.14), Offset(0.14, 0.86), Offset(0.86, 0.86)]) {
    canvas.drawCircle(Offset(r.left + w * o.dx, r.top + r.height * o.dy), w * 0.055, dot);
  }
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..color = const Color(0xFF1F6FB2),
  );
}

/// Ekran arka planı için soluk, tekrarlanan çini yıldız deseni.
class CiniPatternPainter extends CustomPainter {
  const CiniPatternPainter({this.opacity = 0.05});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 56.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: opacity);
    for (double y = 0; y < size.height + step; y += step) {
      for (double x = (y ~/ step).isEven ? 0 : step / 2; x < size.width + step; x += step) {
        for (final angle in [0.0, 0.7853981633974483]) {
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(angle);
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 20, height: 20), paint);
          canvas.restore();
        }
        canvas.drawCircle(Offset(x, y), 4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CiniPatternPainter old) => old.opacity != opacity;
}
