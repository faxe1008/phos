import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../preview/nikon_filter.dart';
import '../theme/app_theme.dart';

/// A compact grading wheel: angle selects hue and distance from the centre
/// selects chroma. The centre is neutral; the outer edge is full chroma.
class ColorWheel extends StatelessWidget {
  const ColorWheel({
    super.key,
    required this.hue,
    required this.chroma,
    required this.onChanged,
    this.size = 142,
  });

  final double hue;
  final double chroma;
  final ValueChanged<({double hue, double chroma})> onChanged;
  final double size;

  void _update(Offset local) {
    final center = Offset(size / 2, size / 2);
    final vector = local - center;
    final radius = size / 2;
    final distance = vector.distance.clamp(0.0, radius);
    if (distance < 0.5) {
      onChanged((hue: hue, chroma: 0));
      return;
    }
    // Start red at the top and rotate clockwise, matching the usual wheel.
    final degrees =
        (math.atan2(vector.dx, -vector.dy) * 180 / math.pi + 360) % 360;
    onChanged((
      hue: degrees,
      chroma: (distance / radius * 100).clamp(0.0, 100.0),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _update(d.localPosition),
      onPanDown: (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      child: CustomPaint(
        size: Size.square(size),
        painter: _ColorWheelPainter(hue: hue, chroma: chroma),
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  const _ColorWheelPainter({required this.hue, required this.chroma});

  final double hue;
  final double chroma;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final ring = Paint()
      ..shader = const SweepGradient(
        // The picker maps hue zero/red to the top, then rotates clockwise.
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          Color(0xFFFF3B30),
          Color(0xFFFFCC00),
          Color(0xFF34C759),
          Color(0xFF00C7BE),
          Color(0xFF007AFF),
          Color(0xFFAF52DE),
          Color(0xFFFF3B30),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius - 6, ring);

    final selected = hslToRgb(hue, 1, 0.5);
    final interior = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.surfaceHigh,
          Color.fromARGB(
            255,
            (selected.$1 * 255).round(),
            (selected.$2 * 255).round(),
            (selected.$3 * 255).round(),
          ),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius - 13));
    canvas.drawCircle(center, radius - 13, interior);

    final angle = hue * math.pi / 180;
    final markerRadius = (radius - 13) * (chroma / 100).clamp(0.0, 1.0);
    final marker =
        center + Offset(math.sin(angle), -math.cos(angle)) * markerRadius;
    canvas.drawCircle(marker, 7, Paint()..color = AppTheme.textPrimary);
    canvas.drawCircle(
      marker,
      5,
      Paint()
        ..color = Color.fromARGB(
          255,
          (selected.$1 * 255).round(),
          (selected.$2 * 255).round(),
          (selected.$3 * 255).round(),
        ),
    );
  }

  @override
  bool shouldRepaint(_ColorWheelPainter old) =>
      old.hue != hue || old.chroma != chroma;
}
