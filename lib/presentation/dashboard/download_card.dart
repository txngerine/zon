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
  bool _hovered = false;

  DownloadItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ZonCard(
      selected: widget.selected,
      onTap: widget.onTap,
      padding: EdgeInsets.all(widget.compact ? 12 : 14),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: widget.compact ? _compactLayout(palette) : _fullLayout(palette),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Full card
  // --------------------------------------------------------------------------

  Widget _fullLayout(ZonPalette palette) {
    final (headline, caption) = _summary();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Phones: the summary column folds into the detail line.
        final narrow = constraints.maxWidth < 520;
        return _fullRow(palette, headline, caption, narrow);
      },
    );
  }

  Widget _fullRow(
    ZonPalette palette,
    String headline,
    String caption,
    bool narrow,
  ) {
    return Row(
      children: [
        FileGlyph(
          fileName: item.fileName,
          thumbnailUrl: item.thumbnailUrl,
          icon: item.isTorrent ? Icons.hub_outlined : null,
          size: narrow ? 40 : 48,
        ),
        SizedBox(width: narrow ? 12 : 16),
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
                style: AppType.body(palette.textMuted, size: 12),
              ),
              const SizedBox(height: 10),
              ZonProgressBar(
                value: item.progress,
                active: item.status == DownloadStatus.downloading,
                muted: _parked,
                height: 4,
              ),
              const SizedBox(height: 8),
              Text(
                narrow ? '$headline  •  ${_detail()}' : _detail(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.numeric(
                  _hovered || item.status == DownloadStatus.failed
                      ? palette.textPrimary
                      : palette.textSecondary,
                  size: 12,
                ),
              ),
            ],
          ),
        ),
        if (!narrow) ...[
          const SizedBox(width: 24),
          SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.numeric(
                    palette.textPrimary,
                    size: 15,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.numeric(palette.textSecondary, size: 12),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(width: 12),
        _Actions(
          item: item,
          showDetails: widget.showDetailsAction,
          onAction: widget.onAction,
        ),
      ],
    );
  }

  /// Parked transfers draw a grey bar instead of the live glow.
  bool get _parked => switch (item.status) {
    DownloadStatus.downloading ||
    DownloadStatus.verifying ||
    DownloadStatus.completed => false,
    _ => true,
  };

  /// Right-hand column: what the transfer is doing, then the key number.
  (String, String) _summary() {
    final percent = formatPercent(item.progress);
    return switch (item.status) {
      DownloadStatus.downloading => (percent, formatSpeed(item.speed)),
      DownloadStatus.completed => ('Completed', sizeLabel(item)),
      DownloadStatus.queued => ('Queued', 'Waiting…'),
      DownloadStatus.paused => ('Paused', _transferred()),
      DownloadStatus.failed => ('Failed', percent),
      DownloadStatus.cancelled => ('Cancelled', percent),
      DownloadStatus.verifying => (percent, item.phase ?? 'Processing'),
    };
  }

  /// Line under the progress bar.
  String _detail() {
    final eta = item.etaSeconds;
    return switch (item.status) {
      DownloadStatus.downloading => [
        _transferred(),
        if (eta != null) 'ETA ${formatEta(eta)}',
        transferLabel(item),
      ].join('  •  '),
      DownloadStatus.verifying => item.phase ?? 'Processing',
      DownloadStatus.completed => 'Saved to ${item.savePath}',
      DownloadStatus.queued => '${item.priority.label} priority',
      DownloadStatus.paused => 'Paused at ${formatPercent(item.progress)}',
      DownloadStatus.failed => item.failureReason ?? 'Transfer failed',
      DownloadStatus.cancelled => 'Cancelled by user',
    };
  }

  String _transferred() => item.sizeBytes > 0
      ? '${formatBytes(item.downloadedBytes)} / ${formatBytes(item.sizeBytes)}'
      : formatBytes(item.downloadedBytes);

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
                      muted: _parked,
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
            raised: !compact,
            tooltip: 'Pause',
            size: compact ? 30 : 36,
            circle: !compact,
            onTap: () => onAction(DownloadCardAction.pause, item),
          ),
        );
        buttons.add(const SizedBox(width: 6));
        buttons.add(
          MonoIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Cancel',
            size: compact ? 30 : 36,
            circle: !compact,
            onTap: () => onAction(DownloadCardAction.cancel, item),
          ),
        );
      case DownloadStatus.paused:
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        buttons.add(
          MonoIconButton(
            icon: Icons.play_arrow_rounded,
            raised: !compact,
            tooltip: 'Resume',
            size: compact ? 30 : 36,
            circle: !compact,
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
            circle: !compact,
            onTap: () => onAction(DownloadCardAction.cancel, item),
          ),
        );
      case DownloadStatus.queued:
        buttons.add(
          MonoIconButton(
            icon: Icons.play_arrow_rounded,
            raised: !compact,
            tooltip: 'Start now',
            size: compact ? 30 : 36,
            circle: !compact,
            onTap: () => onAction(DownloadCardAction.resume, item),
          ),
        );
        buttons.add(const SizedBox(width: 6));
        buttons.add(
          MonoIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Remove',
            size: compact ? 30 : 36,
            circle: !compact,
            onTap: () => onAction(DownloadCardAction.cancel, item),
          ),
        );
      case DownloadStatus.completed:
        buttons.add(
          MonoIconButton(
            icon: Icons.folder_open_rounded,
            tooltip: 'Open folder',
            size: compact ? 30 : 36,
            circle: !compact,
            onTap: () => onAction(DownloadCardAction.openFolder, item),
          ),
        );
        if (!compact) {
          buttons.add(const SizedBox(width: 6));
          buttons.add(
            MonoIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Download again',
              size: 36,
              circle: true,
              onTap: () => onAction(DownloadCardAction.redownload, item),
            ),
          );
        }
      case DownloadStatus.verifying:
        buttons.add(
          MonoIconButton(
            icon: Icons.folder_open_rounded,
            tooltip: 'Open folder',
            size: compact ? 30 : 36,
            circle: !compact,
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
          circle: true,
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
