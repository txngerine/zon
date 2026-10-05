import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';

/// Dashboard hero: eyebrow, oversized statement and supporting copy.
class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final double fontSize;
        final double spacing;
        if (width >= 900) {
          fontSize = 56;
          spacing = -1.8;
        } else if (width >= 620) {
          fontSize = 44;
          spacing = -1.2;
        } else {
          fontSize = 33;
          spacing = -0.8;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Container(width: 26, height: 1, color: palette.textMuted),
                Text(
                  'FAST  •  STABLE  •  POWERFUL',
                  style: AppType.eyebrow(
                    palette.textMuted,
                    size: 10,
                    spacing: 2.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Download\nWithout ',
                    style: TextStyle(
                      color: palette.textPrimary.withValues(alpha: 0.78),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: spacing,
                      height: 1.04,
                    ),
                  ),
                  TextSpan(
                    text: 'Limits.',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: spacing,
                      height: 1.04,
                      shadows: Theme.of(context).brightness == Brightness.dark
                          ? [
                              Shadow(
                                color: palette.textPrimary.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 34,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'A fast, reliable download manager built for modern systems.',
                style: AppType.body(palette.textSecondary, size: 14),
              ),
            ),
          ],
        );
      },
    );
  }
}
