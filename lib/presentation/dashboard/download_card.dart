import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/file_glyph.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/zon_card.dart';
import '../../domain/models/download.dart';

/// Intent emitted by the card's action buttons and overflow menu.
enum DownloadCardAction {
  pause,
  resume,
  cancel,
  remove,
  openFolder,
  openFile,
  copyUrl,
  details,
  redownload,
  priorityHigh,
  priorityNormal,
  priorityLow,
}

/// Premium download card (and its compact variant).
class DownloadCard extends StatefulWidget {
  const DownloadCard({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onAction,
    this.compact = false,
    this.showDetailsAction = false,
  });

  final DownloadItem item;
  final bool selected;
  final VoidCallback onTap;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;
  final bool compact;
  final bool showDetailsAction;

  @override
  State<DownloadCard> createState() => _DownloadCardState();
}

class _DownloadCardState extends State<DownloadCard> {
  DownloadItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final live = item.status == DownloadStatus.downloading;

    return ZonCard(
      selected: widget.selected,
      onTap: widget.onTap,
      padding: widget.compact
          ? const EdgeInsets.all(12)
          : const EdgeInsets.fromLTRB(16, 14, 16, 14),
      // Live transfers get a faint green wash, brighter when selected.
      backgroundColor: live && !widget.compact
          ? Color.alphaBlend(
              palette.glow.withValues(alpha: widget.selected ? 0.10 : 0.05),
              palette.surface,
            )
          : null,
      borderColor: live && !widget.compact
          ? palette.glow.withValues(alpha: widget.selected ? 0.55 : 0.22)
          : null,
      child: widget.compact ? _compactLayout(palette) : _fullLayout(palette),
    );
  }

  // --------------------------------------------------------------------------
  // Full card
  // --------------------------------------------------------------------------

  Widget _fullLayout(ZonPalette palette) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _fullRow(palette, wide: constraints.maxWidth >= 560),
    );
  }

  /// Narrow cards drop the status column; the footer still says it all.
  Widget _fullRow(ZonPalette palette, {required bool wide}) {
    return Row(
      children: [
        FileGlyph(
          fileName: item.fileName,
          thumbnailUrl: item.thumbnailUrl,
          icon: item.isTorrent ? Icons.hub_outlined : null,
          size: 48,
        ),
        const SizedBox(width: 16),
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
              const SizedBox(height: 4),
              Text(
                '${item.source}  •  ${sizeLabel(item)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.numeric(palette.textMuted, size: 12),
              ),
              const SizedBox(height: 10),
              ZonProgressBar(
                value: item.progress,
                active: item.status == DownloadStatus.downloading,
                muted: _stalled,
                height: 4,
              ),
              const SizedBox(height: 8),
              Text(
                _footer(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.numeric(
                  item.status == DownloadStatus.failed
                      ? palette.textSecondary
                      : palette.textMuted,
                  size: 11.5,
                ),
              ),
            ],
          ),
        ),
        if (wide) ...[
          const SizedBox(width: 22),
          SizedBox(width: 104, child: _StatusColumn(item: item)),
        ],
        const SizedBox(width: 8),
        _Actions(
          item: item,
          showDetails: widget.showDetailsAction,
          onAction: widget.onAction,
        ),
      ],
    );
  }

  /// Not moving and not finished: the bar goes grey.
  bool get _stalled => switch (item.status) {
    DownloadStatus.paused ||
    DownloadStatus.queued ||
    DownloadStatus.failed ||
    DownloadStatus.cancelled => true,
    _ => false,
  };

  /// Line under the progress bar.
  String _footer() {
    final transferred = item.sizeBytes > 0
        ? '${formatBytes(item.downloadedBytes)} / ${formatBytes(item.sizeBytes)}'
        : formatBytes(item.downloadedBytes);
    switch (item.status) {
      case DownloadStatus.downloading:
        final eta = item.etaSeconds;
        return [
          transferred,
          if (eta != null) 'ETA ${formatEta(eta)}',
          transferLabel(item),
        ].join('  •  ');
      case DownloadStatus.verifying:
        return item.phase ?? 'Processing';
      case DownloadStatus.completed:
        return item.elapsedSeconds > 0
            ? 'Finished in ${formatDuration(item.elapsedSeconds)}'
            : 'Saved to ${item.savePath}';
      case DownloadStatus.queued:
        return '${item.priority.label} priority';
      case DownloadStatus.paused:
        return '$transferred  •  ${transferLabel(item)}';
      case DownloadStatus.failed:
        return item.failureReason ?? 'Transfer failed';
      case DownloadStatus.cancelled:
        return 'Cancelled by user';
    }
  }

  // --------------------------------------------------------------------------
  // Compact row
  // --------------------------------------------------------------------------

  Widget _compactLayout(ZonPalette palette) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 640;
        return Row(
          children: [
            FileGlyph(
              fileName: item.fileName,
              thumbnailUrl: item.thumbnailUrl,
              icon: item.isTorrent ? Icons.hub_outlined : null,
              size: 34,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: AppType.body(
                      palette.textPrimary,
                      size: 13,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _compactMeta(),
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(palette.textMuted, size: 11),
                  ),
                ],
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 18),
              SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatPercent(item.progress),
                          style: AppType.numeric(
                            palette.textPrimary,
                            size: 11,
                            weight: FontWeight.w600,
                          ),
                        ),
                        if (item.status == DownloadStatus.downloading)
                          Text(
                            formatSpeed(item.speed),
                            style: AppType.numeric(
                              palette.textSecondary,
                              size: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ZonProgressBar(
                      value: item.progress,
                      active: item.status == DownloadStatus.downloading,
                      height: 3,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 14),
            StatusChip(status: item.status, compact: true),
            const SizedBox(width: 8),
            _Actions(
              item: item,
              compact: true,
              showDetails: widget.showDetailsAction,
              onAction: widget.onAction,
            ),
          ],
        );
      },
    );
  }

  String _compactMeta() {
    return switch (item.status) {
      DownloadStatus.failed => item.failureReason ?? 'Failed',
      DownloadStatus.queued => 'Queued • ${item.priority.label} priority',
      DownloadStatus.completed => 'Completed • ${item.savePath}',
      DownloadStatus.verifying =>
        '${item.phase ?? 'Processing'} • ${sizeLabel(item)}',
      DownloadStatus.cancelled => 'Cancelled',
      _ => '${sizeLabel(item)}  •  ${item.source}  •  ${transferLabel(item)}',
    };
  }
}

// -----------------------------------------------------------------------------

/// Total size, or a placeholder while the server/extractor has not said.
String sizeLabel(DownloadItem item) {
  if (item.sizeBytes > 0) return formatBytes(item.sizeBytes);
  return switch (item.status) {
    DownloadStatus.downloading when item.downloadedBytes == 0 =>
      item.isMedia || item.isTorrent ? 'Fetching info…' : 'Connecting…',
    _ => 'Unknown size',
  };
}

/// "16 connections" for files, "MP3 · Audio" for media, swarm for torrents.
String transferLabel(DownloadItem item) {
  if (item.isTorrent) {
    final up = item.uploadSpeed > 0
        ? ' · ↑ ${formatSpeed(item.uploadSpeed)}'
        : '';
    String count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
    return '${count(item.connections, 'peer')} · '
        '${count(item.seeders, 'seed')}$up';
  }
  final format = item.mediaFormat;
  if (item.isMedia && format != null) {
    return '${format.label} · ${format.caption}';
  }
  return '${item.connections} connection${item.connections == 1 ? '' : 's'}';
}

/// Right-hand summary: percent and speed while moving, otherwise the state
/// in words (green once completed).
class _StatusColumn extends StatelessWidget {
  const _StatusColumn({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final transferred = item.sizeBytes > 0
        ? '${formatBytes(item.downloadedBytes)} / ${formatBytes(item.sizeBytes)}'
        : formatBytes(item.downloadedBytes);

    final (
      String title,
      Color titleColor,
      String detail,
    ) = switch (item.status) {
      DownloadStatus.downloading => (
        _percent(item.progress),
        palette.textPrimary,
        formatSpeed(item.speed),
      ),
      DownloadStatus.verifying => (
        item.phase ?? 'Processing',
        palette.textSecondary,
        _percent(item.progress),
      ),
      DownloadStatus.completed => ('Completed', palette.glow, sizeLabel(item)),
      DownloadStatus.queued => ('Queued', palette.textSecondary, 'Waiting…'),
      DownloadStatus.paused => ('Paused', palette.textSecondary, transferred),
      DownloadStatus.failed => (
        'Failed',
        palette.textPrimary,
        _percent(item.progress),
      ),
      DownloadStatus.cancelled => ('Cancelled', palette.textMuted, transferred),
    };
    final moving = item.status == DownloadStatus.downloading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.numeric(
            titleColor,
            size: moving ? 16 : 13.5,
            weight: moving ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.numeric(palette.textMuted, size: 12),
        ),
      ],
    );
  }

  /// "68.4%" — one decimal while it is still moving.
  static String _percent(double value) {
    final percent = (value * 100).clamp(0, 100);
    return percent >= 100 || percent == 0
        ? '${percent.toStringAsFixed(0)}%'
        : '${percent.toStringAsFixed(1)}%';
  }
}

// -----------------------------------------------------------------------------

class _Actions extends StatelessWidget {
  const _Actions({
    required this.item,
    required this.onAction,
    this.compact = false,
    this.showDetails = false,
  });

  final DownloadItem item;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;
  final bool compact;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    switch (item.status) {
      case DownloadStatus.downloading:
        buttons.add(
          MonoIconButton(
            icon: Icons.pause_rounded,
            raised: true,
            tooltip: 'Pause',
            size: compact ? 30 : 36,
            round: true,
            onTap: () => onAction(DownloadCardAction.pause, item),
          ),
        );
        buttons.add(const SizedBox(width: 6));
        buttons.add(
          MonoIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Cancel',
            size: compact ? 30 : 36,
            round: true,
            onTap: () => onAction(DownloadCardAction.cancel, item),
          ),
        );
      case DownloadStatus.paused:
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        buttons.add(
          MonoIconButton(
            icon: Icons.play_arrow_rounded,
            raised: true,
            tooltip: 'Resume',
            size: compact ? 30 : 36,
            round: true,
            onTap: () => onAction(DownloadCardAction.resume, item),
          ),
        );
        buttons.add(const SizedBox(width: 6));
        buttons.add(
          MonoIconButton(
            icon: Icons.close_rounded,
            tooltip: item.status == DownloadStatus.failed
                ? 'Dismiss'
                : 'Cancel',
            size: compact ? 30 : 36,
            round: true,
            onTap: () => onAction(DownloadCardAction.cancel, item),
          ),
        );
      case DownloadStatus.queued:
        buttons.add(
          MonoIconButton(
            icon: Icons.play_arrow_rounded,
            raised: true,
            tooltip: 'Start now',
            size: compact ? 30 : 36,
            round: true,
            onTap: () => onAction(DownloadCardAction.resume, item),
          ),
        );
        buttons.add(const SizedBox(width: 6));
        buttons.add(
          MonoIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Remove',
            size: compact ? 30 : 36,
            round: true,
            onTap: () => onAction(DownloadCardAction.cancel, item),
          ),
        );
      case DownloadStatus.completed:
        buttons.add(
          MonoIconButton(
            icon: Icons.folder_open_rounded,
            raised: true,
            tooltip: 'Open folder',
            size: compact ? 30 : 36,
            round: true,
            onTap: () => onAction(DownloadCardAction.openFolder, item),
          ),
        );
      case DownloadStatus.verifying:
        buttons.add(
          MonoIconButton(
            icon: Icons.folder_open_rounded,
            raised: true,
            tooltip: 'Open folder',
            size: compact ? 30 : 36,
            round: true,
            onTap: () => onAction(DownloadCardAction.openFolder, item),
          ),
        );
    }

    if (showDetails && !compact) {
      buttons.add(const SizedBox(width: 6));
      buttons.add(
        MonoIconButton(
          icon: Icons.info_outline_rounded,
          tooltip: 'Details',
          size: 36,
          round: true,
          onTap: () => onAction(DownloadCardAction.details, item),
        ),
      );
    }

    buttons.add(const SizedBox(width: 6));
    buttons.add(_MoreMenu(item: item, onAction: onAction, compact: compact));

    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.item,
    required this.onAction,
    required this.compact,
  });

  final DownloadItem item;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    PopupMenuItem<String> entry(
      String value,
      IconData icon,
      String label, {
      bool danger = false,
      bool check = false,
    }) {
      return PopupMenuItem<String>(
        value: value,
        height: 36,
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: danger ? palette.textPrimary : palette.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppType.body(
                  danger ? palette.textPrimary : palette.textSecondary,
                  size: 12.5,
                  weight: danger ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (check)
              Icon(Icons.check_rounded, size: 14, color: palette.textPrimary),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'More actions',
      onSelected: onActionString,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 210),
      icon: Icon(
        Icons.more_horiz_rounded,
        size: compact ? 16 : 18,
        color: palette.textSecondary,
      ),
      itemBuilder: (context) => [
        entry('details', Icons.toc_rounded, 'Details'),
        if (item.status == DownloadStatus.completed)
          entry('open', Icons.open_in_new_rounded, 'Open file'),
        entry('folder', Icons.folder_open_rounded, 'Show in folder'),
        entry('copy', Icons.link_rounded, 'Copy link'),
        if (item.status == DownloadStatus.completed ||
            item.status == DownloadStatus.failed)
          entry('redownload', Icons.refresh_rounded, 'Download again'),
        const PopupMenuDivider(height: 9),
        entry(
          'p_high',
          Icons.arrow_upward_rounded,
          'Priority: High',
          check: item.priority == DownloadPriority.high,
        ),
        entry(
          'p_normal',
          Icons.remove_rounded,
          'Priority: Normal',
          check: item.priority == DownloadPriority.normal,
        ),
        entry(
          'p_low',
          Icons.arrow_downward_rounded,
          'Priority: Low',
          check: item.priority == DownloadPriority.low,
        ),
        const PopupMenuDivider(height: 9),
        entry('remove', Icons.delete_outline_rounded, 'Remove', danger: true),
      ],
    );
  }

  void onActionString(String value) {
    final action = switch (value) {
      'open' => DownloadCardAction.openFile,
      'folder' => DownloadCardAction.openFolder,
      'copy' => DownloadCardAction.copyUrl,
      'redownload' => DownloadCardAction.redownload,
      'p_high' => DownloadCardAction.priorityHigh,
      'p_normal' => DownloadCardAction.priorityNormal,
      'p_low' => DownloadCardAction.priorityLow,
      'remove' => DownloadCardAction.remove,
      _ => DownloadCardAction.details,
    };
    onAction(action, item);
  }
}
