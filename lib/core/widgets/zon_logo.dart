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

/// Vector reconstruction of the ZON mark, used only if the asset fails to load.
class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF111111),
      alignment: Alignment.center,
      child: Text(
        'Z',
        style: TextStyle(
          color: const Color(0xFF1FE3A0),
          fontSize: size * 0.56,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
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
