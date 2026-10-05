import 'package:flutter/material.dart';

import '../theme/zon_palette.dart';

/// Picks a monochrome glyph that matches the file type.
IconData fileIconFor(String fileName) {
  final name = fileName.toLowerCase();
  if (name.endsWith('.iso')) return Icons.disc_full_rounded;
  if (name.endsWith('.dmg') || name.endsWith('.pkg') || name.endsWith('.app')) {
    return Icons.apps_outlined;
  }
  if (name.endsWith('.zip') ||
      name.endsWith('.rar') ||
      name.endsWith('.7z') ||
      name.endsWith('.tar') ||
      name.endsWith('.gz') ||
      name.endsWith('.xz')) {
    return Icons.folder_zip_outlined;
  }
  if (name.endsWith('.mkv') ||
      name.endsWith('.mp4') ||
      name.endsWith('.mov') ||
      name.endsWith('.avi') ||
      name.endsWith('.webm')) {
    return Icons.movie_outlined;
  }
  if (name.endsWith('.mp3') ||
      name.endsWith('.flac') ||
      name.endsWith('.wav') ||
      name.endsWith('.m4a') ||
      name.endsWith('.opus') ||
      name.endsWith('.aac')) {
    return Icons.audio_file_outlined;
  }
  if (name.endsWith('.png') ||
      name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.heic') ||
      name.endsWith('.webp')) {
    return Icons.image_outlined;
  }
  if (name.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (name.endsWith('.torrent')) return Icons.cloud_download_outlined;
  if (name.endsWith('.exe') || name.endsWith('.msi')) {
    return Icons.settings_input_component_outlined;
  }
  if (name.endsWith('.deb') || name.endsWith('.rpm')) {
    return Icons.terminal_rounded;
  }
  return Icons.insert_drive_file_outlined;
}

/// Rounded-square tile that represents a file inside cards and panels.
class FileGlyph extends StatelessWidget {
  const FileGlyph({
    super.key,
    required this.fileName,
    this.size = 44,
    this.thumbnailUrl,
    this.icon,
  });

  final String fileName;
  final double size;

  /// Video artwork (YouTube, Reels, ...) shown instead of the type icon.
  final String? thumbnailUrl;

  /// Overrides the icon picked from [fileName].
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = size * 0.26;
    final glyph = Icon(
      icon ?? fileIconFor(fileName),
      size: size * 0.44,
      color: palette.textSecondary,
    );
    final thumbnail = thumbnailUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.surfaceHighest, palette.surfaceHigh],
        ),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: thumbnail == null
          ? glyph
          : Image.network(
              thumbnail,
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => glyph,
            ),
    );
  }
}
