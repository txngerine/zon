import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/file_glyph.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/mono_dropdown.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/app_state.dart';
import '../../domain/models/download.dart';
import '../dashboard/download_card.dart';
import '../dashboard/speed_panel.dart';

/// Right-hand details panel: full statistics, advanced metadata, transfer
/// graph and controls for the selected download.
class DetailsPanel extends StatelessWidget {
  const DetailsPanel({
    super.key,
    required this.state,
    required this.onAction,
    this.onClose,
  });

  final AppState state;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final item = state.selected;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: palette.backgroundRaised,
        border: Border(left: BorderSide(color: palette.border)),
      ),
      child: item == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: EmptyState(
                  compact: true,
                  title: 'Nothing selected',
                  message:
                      'Pick a download to inspect its progress and metadata.',
                ),
              ),
            )
          : DetailsView(
              state: state,
              item: item,
              onAction: onAction,
              onClose: onClose,
            ),
    );
  }
}

/// Borderless details content, reused by the desktop panel, the drawer and
/// the mobile bottom sheet.
class DetailsView extends StatelessWidget {
  const DetailsView({
    super.key,
    required this.state,
    required this.item,
    required this.onAction,
    this.onClose,
  });

  final AppState state;
  final DownloadItem item;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final eta = item.etaSeconds;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FileGlyph(
                fileName: item.fileName,
                thumbnailUrl: item.thumbnailUrl,
                size: 54,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(
                        palette.textPrimary,
                        size: 15,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.source,
                      style: AppType.body(palette.textMuted, size: 12),
                    ),
                  ],
                ),
              ),
              if (onClose != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Close',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text('PROGRESS', style: AppType.eyebrow(palette.textMuted)),
              const Spacer(),
              Text(
                formatPercent(item.progress),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  fontFeatures: AppType.tabular,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ZonProgressBar(
            value: item.progress,
            active: item.status == DownloadStatus.downloading,
            height: 6,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.status == DownloadStatus.verifying
                      ? (item.phase ?? 'Processing')
                      : item.sizeBytes > 0
                      ? '${formatBytes(item.downloadedBytes)} of ${formatBytes(item.sizeBytes)}'
                      : '${formatBytes(item.downloadedBytes)} • ${sizeLabel(item)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.numeric(palette.textMuted, size: 12),
                ),
              ),
              const SizedBox(width: 8),
              if (eta != null)
                Text(
                  '${formatEta(eta)} left',
                  style: AppType.numeric(palette.textSecondary, size: 12),
                ),
            ],
          ),
          const SizedBox(height: 26),
          Text('STATISTICS', style: AppType.eyebrow(palette.textMuted)),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Status',
            child: StatusChip(status: item.status, compact: true),
          ),
          _StatRow(
            label: 'Downloaded',
            value: '${formatBytes(item.downloadedBytes)} / ${sizeLabel(item)}',
          ),
          if (item.failureReason case final reason?)
            _StatRow(label: 'Error', value: reason),
          _StatRow(
            label: 'Speed',
            value: item.status == DownloadStatus.downloading
                ? formatSpeed(item.speed)
                : '—',
          ),
          _StatRow(label: 'ETA', value: eta == null ? '—' : formatEta(eta)),
          if (item.isMedia)
            _StatRow(label: 'Format', value: transferLabel(item))
          else
            _StatRow(label: 'Connections', value: '${item.connections}'),
          _StatRow(label: 'Save location', value: item.savePath),
          if (item.filePath case final path?)
            _StatRow(label: 'File', value: path, ellipsis: true),
          _StatRow(label: 'Source URL', value: item.url, ellipsis: true),
          _StatRow(label: 'Added', value: formatDateTime(item.addedAt)),
          const SizedBox(height: 22),
          Text('TRANSFER RATE', style: AppType.eyebrow(palette.textMuted)),
          const SizedBox(height: 12),
          MiniSpeedGraph(state: state, height: 66),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Peak ${formatSpeed(state.peakSpeed)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.numeric(palette.textMuted, size: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Avg ${formatSpeed(state.averageSpeed)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppType.numeric(palette.textMuted, size: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text('ADVANCED', style: AppType.eyebrow(palette.textMuted)),
          const SizedBox(height: 12),
          _StatRow(
            label: 'HTTP status',
            value: item.httpStatus == 0
                ? '—'
                : '${item.httpStatus} ${_statusText(item.httpStatus)}',
          ),
          _StatRow(
            label: 'Server',
            value: item.server.isEmpty ? '—' : item.server,
          ),
          _StatRow(label: 'Content type', value: item.contentType),
          _StatRow(
            label: 'Resume support',
            value: item.resumeSupported ? 'Yes — byte ranges' : 'No',
          ),
          _StatRow(label: 'Created', value: formatDateTime(item.addedAt)),
          _StatRow(
            label: 'Last activity',
            value: formatDateTime(item.lastActivity),
          ),
          _StatRow(
            label: 'Priority',
            child: MonoDropdown<DownloadPriority>(
              value: item.priority,
              options: [
                for (final priority in DownloadPriority.values)
                  MonoOption(priority, priority.label),
              ],
              onChanged: (priority) => state.setPriority(item.id, priority),
              height: 28,
              width: 116,
            ),
          ),
          const SizedBox(height: 26),
          ..._actions(context),
        ],
      ),
    );
  }

  static String _statusText(int code) => switch (code) {
    200 => 'OK',
    206 => 'Partial Content',
    403 => 'Forbidden',
    404 => 'Not Found',
    500 => 'Server Error',
    _ => '',
  };

  List<Widget> _actions(BuildContext context) {
    final widgets = <Widget>[];

    void primary(String label, IconData icon, DownloadCardAction action) {
      widgets.add(
        MonoButton(
          label: label,
          icon: icon,
          variant: MonoButtonVariant.primary,
          expand: true,
          height: 42,
          onTap: () => onAction(action, item),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }

    switch (item.status) {
      case DownloadStatus.downloading:
        primary('Pause', Icons.pause_rounded, DownloadCardAction.pause);
      case DownloadStatus.paused:
        primary('Resume', Icons.play_arrow_rounded, DownloadCardAction.resume);
      case DownloadStatus.failed:
        primary('Retry', Icons.refresh_rounded, DownloadCardAction.resume);
      case DownloadStatus.cancelled:
        primary('Resume', Icons.play_arrow_rounded, DownloadCardAction.resume);
      case DownloadStatus.queued:
        primary(
          'Start now',
          Icons.play_arrow_rounded,
          DownloadCardAction.resume,
        );
      case DownloadStatus.completed:
        primary(
          'Open file',
          Icons.open_in_new_rounded,
          DownloadCardAction.openFile,
        );
      case DownloadStatus.verifying:
        primary(
          'Open folder',
          Icons.folder_open_rounded,
          DownloadCardAction.openFolder,
        );
    }

    final secondary = <Widget>[];
    if (item.status != DownloadStatus.completed) {
      secondary.add(
        Expanded(
          child: MonoButton(
            label: item.status == DownloadStatus.queued ? 'Remove' : 'Cancel',
            expand: true,
            onTap: () => onAction(
              item.status == DownloadStatus.queued
                  ? DownloadCardAction.remove
                  : DownloadCardAction.cancel,
              item,
            ),
          ),
        ),
      );
      secondary.add(const SizedBox(width: 10));
    } else {
      secondary.add(
        Expanded(
          child: MonoButton(
            label: 'Download again',
            expand: true,
            onTap: () => onAction(DownloadCardAction.redownload, item),
          ),
        ),
      );
      secondary.add(const SizedBox(width: 10));
    }
    secondary.add(
      MonoButton(
        label: 'Folder',
        icon: Icons.folder_open_rounded,
        onTap: () => onAction(DownloadCardAction.openFolder, item),
      ),
    );
    widgets.add(Row(children: secondary));
    return widgets;
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    this.value,
    this.child,
    this.ellipsis = false,
  });

  final String label;
  final String? value;
  final Widget? child;
  final bool ellipsis;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: AppType.body(palette.textMuted, size: 12),
            ),
          ),
          Expanded(
            child:
                child ??
                Text(
                  value ?? '',
                  textAlign: TextAlign.right,
                  maxLines: ellipsis ? 2 : 1,
                  overflow: ellipsis
                      ? TextOverflow.ellipsis
                      : TextOverflow.clip,
                  style: AppType.body(
                    palette.textPrimary,
                    size: 12.5,
                    weight: FontWeight.w500,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
