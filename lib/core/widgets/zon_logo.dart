import 'package:flutter/material.dart';

import '../theme/zon_palette.dart';

/// The ZON brand mark.
///
/// Uses the supplied artwork — never substitutes Material icons — so the
/// identity stays identical across sidebar, splash, empty states and tray.
class ZonLogo extends StatelessWidget {
  const ZonLogo({super.key, this.size = 40, this.radius});

  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? size * 0.24),
      child: Image.asset(
        'assets/brand/zon_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _FallbackMark(size: size),
      ),
    );
  }
}

/// Vector copy of the ZON mark, used only if the asset fails to load.
class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const ZonMarkPainter(),
    );
  }
}

/// The ZON mark: one rounded stroke (across, then down-left) and a dot on a
/// green tile. Geometry is in a 248-unit box, as measured from the artwork.
class ZonMarkPainter extends CustomPainter {
  const ZonMarkPainter();

  static const green = Color(0xFF00674F);
  static const ink = Color(0xFF010101);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 248;
    canvas.drawRect(Offset.zero & size, Paint()..color = green);
    canvas.scale(scale);
    canvas.drawPath(
      Path()
        ..moveTo(77.5, 74.5)
        ..lineTo(170.5, 74.5)
        ..lineTo(78.5, 170.5),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 50.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(const Offset(169, 169), 25, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(ZonMarkPainter oldDelegate) => false;
}

/// Logo + wordmark used at the top of the sidebar and the mobile app bar.
class ZonBrand extends StatelessWidget {
  const ZonBrand({
    super.key,
    this.logoSize = 38,
    this.compact = false,
    this.tagline = 'THE DOWNLOAD MANAGER',
  });

  final double logoSize;
  final bool compact;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ZonLogo(size: logoSize),
        if (!compact) ...[
          const SizedBox(width: 11),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ZON',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.5,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
