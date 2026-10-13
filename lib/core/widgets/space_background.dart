import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/zon_palette.dart';

/// Deep-space backdrop behind the floating shell panels: a starfield, the
/// rim of a planet at the top and a faint glow in the corners. Light mode
/// gets the plain background.
class SpaceBackground extends StatelessWidget {
  const SpaceBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (!dark) return ColoredBox(color: palette.background);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SpacePainter(
          background: palette.background,
          glow: palette.glow,
        ),
      ),
    );
  }
}

class _SpacePainter extends CustomPainter {
  _SpacePainter({required this.background, required this.glow});

  final Color background;
  final Color glow;

  /// Fixed seed so the stars stay put between frames and launches.
  static final List<(double, double, double, double)> _stars = () {
    final random = math.Random(11);
    return [
      for (var i = 0; i < 160; i++)
        (
          random.nextDouble(),
          random.nextDouble(),
          0.3 + random.nextDouble() * 0.8,
          0.12 + random.nextDouble() * 0.45,
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = background);

    void haze(Offset center, double radius, double alpha) {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            colors: [
              glow.withValues(alpha: alpha),
              glow.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final reach = size.longestSide;
    haze(Offset(size.width * 0.04, size.height * 0.9), reach * 0.4, 0.12);
    haze(Offset(size.width * 0.98, size.height * 0.05), reach * 0.3, 0.05);

    final star = Paint();
    for (final (x, y, radius, alpha) in _stars) {
      star.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x * size.width, y * size.height), radius, star);
    }

    // Planet: a dark disc above the window whose lower edge catches light.
    final radius = size.width * 0.34;
    final center = Offset(size.width * 0.52, size.height * 0.07 - radius);
    final disc = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, 0.6),
          colors: [const Color(0xFF15191A), background],
        ).createShader(disc),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = SweepGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.45),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.15, 0.32, 0.5],
        ).createShader(disc),
    );
  }

  @override
  bool shouldRepaint(_SpacePainter oldDelegate) =>
      oldDelegate.background != background || oldDelegate.glow != glow;
}
