import 'package:flutter/material.dart';

/// Illustrated bottles used where a product has no photo (and on the welcome
/// hero), drawn in the style of `frontend/src/components/brand/product-art.tsx`.
enum ProductArtKind { dropper, pump, jar, tube, toner }

ProductArtKind artKindFor(String seed) {
  final s = seed.toLowerCase();
  if (s.contains('serum') || s.contains('сыворот') || s.contains('drop')) return ProductArtKind.dropper;
  if (s.contains('cleans') || s.contains('tozal') || s.contains('ko‘pik') || s.contains('foam') || s.contains('gel')) return ProductArtKind.pump;
  if (s.contains('sun') || s.contains('spf') || s.contains('quyosh') || s.contains('himoya')) return ProductArtKind.tube;
  if (s.contains('toner') || s.contains('tonik')) return ProductArtKind.toner;
  if (s.contains('krem') || s.contains('cream') || s.contains('moist') || s.contains('namlan')) return ProductArtKind.jar;
  return ProductArtKind.values[seed.hashCode.abs() % ProductArtKind.values.length];
}

class ProductArt extends StatelessWidget {
  const ProductArt({super.key, required this.kind, this.size = 96});
  final ProductArtKind kind;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size * 1.25,
        child: CustomPaint(painter: _ArtPainter(kind)),
      );
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.kind);
  final ProductArtKind kind;

  static const _gold = Color(0xFFC9A24B);
  static const _goldDeep = Color(0xFF9A7424);
  static const _cream = Color(0xFFF3EEE2);
  static const _amber = Color(0xFFA8733A);
  static const _dark = Color(0xFF2B2620);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final shadow = Paint()..color = const Color(0x1A2A2418);
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, h * 0.95), width: w * 0.62, height: h * 0.05), shadow);
    RRect rr(double l, double t, double r, double b, double rad) => RRect.fromLTRBR(l * w, t * h, r * w, b * h, Radius.circular(rad * w));
    final label = Paint()..color = Colors.white;
    final line = Paint()
      ..color = const Color(0xFF7A705D)
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;
    switch (kind) {
      case ProductArtKind.dropper:
        canvas.drawRRect(rr(0.43, 0.04, 0.57, 0.2, 0.07), Paint()..color = _dark);
        canvas.drawRRect(rr(0.37, 0.18, 0.63, 0.3, 0.03), Paint()..color = _gold);
        canvas.drawRRect(rr(0.27, 0.29, 0.73, 0.93, 0.1), Paint()..color = _amber);
        canvas.drawRRect(rr(0.36, 0.5, 0.64, 0.72, 0.02), label);
        canvas.drawLine(Offset(w * 0.42, h * 0.57), Offset(w * 0.58, h * 0.57), line);
        canvas.drawLine(Offset(w * 0.44, h * 0.63), Offset(w * 0.56, h * 0.63), line);
      case ProductArtKind.pump:
        canvas.drawRRect(rr(0.47, 0.04, 0.53, 0.16, 0.02), Paint()..color = _dark);
        canvas.drawRRect(rr(0.47, 0.04, 0.66, 0.08, 0.02), Paint()..color = _dark);
        canvas.drawRRect(rr(0.4, 0.14, 0.6, 0.22, 0.03), Paint()..color = _dark);
        canvas.drawRRect(rr(0.3, 0.21, 0.7, 0.93, 0.14), Paint()..color = _cream);
        canvas.drawLine(Offset(w * 0.42, h * 0.5), Offset(w * 0.58, h * 0.5), line);
        canvas.drawLine(Offset(w * 0.44, h * 0.55), Offset(w * 0.56, h * 0.55), line);
      case ProductArtKind.jar:
        canvas.drawRRect(rr(0.2, 0.42, 0.8, 0.54, 0.04), Paint()..color = _gold);
        canvas.drawRRect(rr(0.22, 0.52, 0.78, 0.92, 0.1), Paint()..color = _cream);
        canvas.drawRRect(rr(0.31, 0.62, 0.69, 0.8, 0.03), label);
        canvas.drawLine(Offset(w * 0.4, h * 0.69), Offset(w * 0.6, h * 0.69), line);
      case ProductArtKind.tube:
        canvas.drawRRect(rr(0.36, 0.1, 0.64, 0.8, 0.06), Paint()..color = _cream);
        canvas.drawRRect(rr(0.39, 0.78, 0.61, 0.93, 0.03), Paint()..color = _gold);
        canvas.drawLine(Offset(w * 0.5, h * 0.16), Offset(w * 0.5, h * 0.38), Paint()..color = _goldDeep..strokeWidth = w * 0.04);
      case ProductArtKind.toner:
        canvas.drawRRect(rr(0.43, 0.08, 0.57, 0.2, 0.03), Paint()..color = const Color(0xFF7A705D));
        canvas.drawRRect(rr(0.34, 0.19, 0.66, 0.93, 0.08), Paint()..color = const Color(0xFFE9DFC8));
        canvas.drawRRect(rr(0.4, 0.45, 0.6, 0.65, 0.02), label);
    }
    // soft highlight
    canvas.drawRRect(rr(0.31, 0.32, 0.35, 0.8, 0.02), Paint()..color = const Color(0x22FFFFFF));
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.kind != kind;
}
