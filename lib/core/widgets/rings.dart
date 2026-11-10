import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/gd_colors.dart';

/// The brand motif: concentric gold rings (logo and hero backgrounds).
class GdRings extends StatelessWidget {
  const GdRings({super.key, this.color, this.count = 3, this.strokeWidth = 1.2, this.child});

  final Color? color;
  final int count;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _RingsPainter(color ?? context.gd.gold, count, strokeWidth),
        child: child,
      );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.color, this.count, this.strokeWidth);
  final Color color;
  final int count;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = math.min(size.width, size.height) / 2;
    for (var i = 0; i < count; i++) {
      final r = maxR * (i + 1) / count;
      final opacity = 1 - i / (count + 0.5);
      canvas.drawCircle(
        center,
        r - strokeWidth,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = color.withValues(alpha: color.a * opacity * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.color != color || old.count != count;
}

/// The app icon: dark rounded square with three gold rings.
class GdLogo extends StatelessWidget {
  const GdLogo({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: const Color(0xFF2B2620), borderRadius: BorderRadius.circular(size * 14 / 64)),
          child: Padding(
            padding: EdgeInsets.all(size * 9 / 64),
            child: const GdRings(color: Color(0xFFC9A24B), strokeWidth: 2),
          ),
        ),
      );
}

/// "Glow Derma" wordmark in the display face.
class GdWordmark extends StatelessWidget {
  const GdWordmark({super.key, this.color, this.size = 28});
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
        'Glow Derma',
        style: context.gdText.title.copyWith(fontSize: size, height: 1.1, color: color ?? context.gd.ink),
      );
}
