// Uygulama ikonunu çini temasıyla üretir.
// Çalıştır: flutter test tool/render_icons_test.dart
// Çıktı: assets/icon/app_icon.png (1024, opak)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karekare/piece_widget.dart';
import 'package:karekare/pieces.dart';

void _block(Canvas canvas, Rect r, Color color) {
  final rr = RRect.fromRectAndRadius(r.deflate(r.width * 0.06), Radius.circular(r.width * 0.2));
  canvas.drawRRect(
    rr,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, 0.3)!, color],
      ).createShader(r),
  );
}

void main() {
  testWidgets('ikonu üret', (tester) async {
    await tester.runAsync(() async {
      const s = 1024.0;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      const full = Rect.fromLTWH(0, 0, s, s);
      canvas.drawRect(
        full,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B3A73), Color(0xFF0A1630)],
          ).createShader(full),
      );
      const CiniPatternPainter(opacity: 0.08).paint(canvas, const Size(s, s));

      // 3x3 tahta: köşegende çiniler, çevresinde renkli bloklar.
      const cell = 250.0;
      const origin = Offset(137, 137);
      final colors = kPieceColors;
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          final rect = Rect.fromLTWH(origin.dx + c * cell, origin.dy + r * cell, cell, cell);
          if (r == c) {
            paintCiniTile(canvas, RRect.fromRectAndRadius(rect.deflate(cell * 0.06), const Radius.circular(cell * 0.2)));
          } else {
            _block(canvas, rect, colors[(r * 3 + c) % colors.length]);
          }
        }
      }

      final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('assets/icon/app_icon.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
