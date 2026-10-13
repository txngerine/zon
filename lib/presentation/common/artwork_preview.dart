import 'package:flutter/material.dart';

import '../../core/theme/zon_palette.dart';
import '../../core/widgets/file_glyph.dart';
import '../../domain/models/download.dart';

/// Large artwork: the media thumbnail, or the file-type glyph on a dark
/// gradient.
class ArtworkPreview extends StatelessWidget {
  const ArtworkPreview({
    super.key,
    required this.item,
    this.aspectRatio = 16 / 10,
    this.radius = 16,
    this.iconSize = 54,
  });

  final DownloadItem item;
  final double aspectRatio;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final glyph = Center(
      child: Icon(
        item.isTorrent ? Icons.hub_outlined : fileIconFor(item.fileName),
        size: iconSize,
        color: palette.textSecondary,
      ),
    );
    final thumbnail = item.thumbnailUrl;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: palette.border),
          gradient: RadialGradient(
            center: const Alignment(-0.6, -0.8),
            radius: 1.4,
            colors: [
              palette.glow.withValues(alpha: 0.06),
              palette.surfaceHigh,
              palette.surface,
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: thumbnail == null
            ? glyph
            : Image.network(
                thumbnail,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => glyph,
              ),
      ),
    );
  }
}
