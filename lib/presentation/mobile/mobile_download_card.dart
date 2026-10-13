import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/file_glyph.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/progress_bar.dart';
import '../../domain/models/download.dart';
import '../dashboard/download_card.dart';

/// Phone row: artwork, name and progress on the left, percent and one round
/// action on the right. Everything else lives on the details page.
class MobileDownloadCard extends StatelessWidget {
  const MobileDownloadCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onAction,
  });

  final DownloadItem item;
  final VoidCallback onTap;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final live = item.status == DownloadStatus.downloading;
    final showBar =
        live ||
        item.status == DownloadStatus.paused ||
        item.status == DownloadStatus.verifying;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: live
              ? Color.alphaBlend(
                  palette.glow.withValues(alpha: 0.05),
                  palette.surface,
                )
              : palette.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: live ? palette.glow.withValues(alpha: 0.22) : palette.border,
          ),
        ),
        child: Row(
          children: [
            FileGlyph(
              fileName: item.fileName,
              thumbnailUrl: item.thumbnailUrl,
              icon: item.isTorrent ? Icons.hub_outlined : null,
              size: 56,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(
                      palette.textPrimary,
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.source}  •  ${sizeLabel(item)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.numeric(palette.textMuted, size: 11.5),
                  ),
                  const SizedBox(height: 8),
                  if (showBar) ...[
                    ZonProgressBar(
                      value: item.progress,
                      active: live,
                      muted: !live,
                      height: 4,
                    ),
                    const SizedBox(height: 7),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        _stateWord(),
                        style: AppType.body(
                          item.status == DownloadStatus.completed
                              ? palette.glow
                              : palette.textSecondary,
                          size: 12,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    _detail(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.numeric(palette.textMuted, size: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showBar) ...[
                  Text(
                    _percent(item.progress),
                    style: AppType.numeric(
                      live ? palette.glow : palette.textSecondary,
                      size: 15,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _primaryButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton() {
    final (
      IconData icon,
      String tooltip,
      DownloadCardAction action,
    ) = switch (item.status) {
      DownloadStatus.downloading => (
        Icons.pause_rounded,
        'Pause',
        DownloadCardAction.pause,
      ),
      DownloadStatus.completed || DownloadStatus.verifying => (
        Icons.folder_open_rounded,
        'Open folder',
        DownloadCardAction.openFolder,
      ),
      DownloadStatus.failed => (
        Icons.refresh_rounded,
        'Retry',
        DownloadCardAction.resume,
      ),
      _ => (Icons.play_arrow_rounded, 'Resume', DownloadCardAction.resume),
    };
    return MonoIconButton(
      icon: icon,
      tooltip: tooltip,
      size: 42,
      iconSize: 20,
      round: true,
      raised: true,
      onTap: () => onAction(action, item),
    );
  }

  String _stateWord() => switch (item.status) {
    DownloadStatus.completed => 'Completed',
    DownloadStatus.queued => 'Queued',
    DownloadStatus.failed => 'Failed',
    DownloadStatus.cancelled => 'Cancelled',
    DownloadStatus.paused => 'Paused',
    DownloadStatus.verifying => item.phase ?? 'Processing',
    DownloadStatus.downloading => 'Downloading',
  };

  String _detail() {
    final transferred = item.sizeBytes > 0
        ? '${formatBytes(item.downloadedBytes)} / ${formatBytes(item.sizeBytes)}'
        : formatBytes(item.downloadedBytes);
    switch (item.status) {
      case DownloadStatus.downloading:
        final eta = item.etaSeconds;
        return [
          transferred,
          formatSpeed(item.speed),
          if (eta != null) 'ETA ${formatEta(eta)}',
        ].join('  •  ');
      case DownloadStatus.completed:
        return item.elapsedSeconds > 0
            ? '${sizeLabel(item)}  •  Finished in '
                  '${formatDuration(item.elapsedSeconds)}'
            : sizeLabel(item);
      case DownloadStatus.queued:
        return 'Waiting…';
      case DownloadStatus.failed:
        return item.failureReason ?? 'Transfer failed';
      case DownloadStatus.paused:
      case DownloadStatus.verifying:
        return transferred;
      case DownloadStatus.cancelled:
        return 'Cancelled by user';
    }
  }

  static String _percent(double value) {
    final percent = (value * 100).clamp(0, 100);
    return percent >= 100 || percent == 0
        ? '${percent.toStringAsFixed(0)}%'
        : '${percent.toStringAsFixed(1)}%';
  }
}
