import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/file_glyph.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/mono_dropdown.dart';
import '../../core/widgets/progress_bar.dart';
import '../../data/app_state.dart';
import '../../domain/models/download.dart';
import '../dashboard/download_card.dart';

/// Right-hand details panel: preview, progress, live speed, connections,
/// save location, metadata and controls for the selected download.
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
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
    final moving = item.status == DownloadStatus.downloading;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Toolbar(item: item, onAction: onAction, onClose: onClose),
          const SizedBox(height: 16),
          _Preview(item: item),
          const SizedBox(height: 16),
          Text(
            item.fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.body(
              palette.textPrimary,
              size: 16,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            shortUrl(item.url),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.body(palette.textMuted, size: 12),
          ),
          const _Divider(),
          _Eyebrow('PROGRESS'),
          Text(formatPercent(item.progress), style: _figure(palette)),
          const SizedBox(height: 12),
          ZonProgressBar(
            value: item.progress,
            active: moving,
            muted: !moving && item.status != DownloadStatus.completed,
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
                      ? '${formatBytes(item.downloadedBytes)} / ${formatBytes(item.sizeBytes)}'
                      : '${formatBytes(item.downloadedBytes)} • ${sizeLabel(item)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.numeric(palette.textMuted, size: 12),
                ),
              ),
              if (eta != null)
                Text(
                  'ETA ${formatEta(eta)}',
                  style: AppType.numeric(palette.textSecondary, size: 12),
                ),
            ],
          ),
          const _Divider(),
          _Eyebrow('SPEED'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                moving ? formatSpeed(item.speed) : '—',
                style: _figure(palette),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SpeedBars(
                  samples: state.speedHistoryFor(item.id),
                  height: 30,
                ),
              ),
            ],
          ),
          if (item.isTorrent) ...[
            const _Divider(),
            _Eyebrow('SWARM'),
            _StatRow(label: 'Peers', value: '${item.connections}'),
            _StatRow(label: 'Seeds', value: '${item.seeders}'),
            _StatRow(label: 'Upload', value: formatSpeed(item.uploadSpeed)),
          ] else if (!item.isMedia) ...[
            const _Divider(),
            _Eyebrow('CONNECTIONS'),
            Row(
              children: [
                Text(
                  '${item.connections} / ${_ConnectionGrid.slots}',
                  style: _figure(palette),
                ),
                const Spacer(),
                _ConnectionGrid(connections: item.connections, live: moving),
              ],
            ),
          ],
          const _Divider(),
          _Eyebrow('SAVE TO'),
          _SaveTo(item: item, onAction: onAction),
          const _Divider(),
          _Eyebrow('ADDITIONAL INFO'),
          _StatRow(label: 'File type', value: _fileType(item)),
          _StatRow(label: 'Size', value: sizeLabel(item)),
          _StatRow(label: 'Added', value: formatDateTime(item.addedAt)),
          _StatRow(label: 'Status', value: _statusLabel(item.status)),
          _StatRow(label: 'Source', value: item.source),
          if (item.isMedia)
            _StatRow(label: 'Format', value: transferLabel(item)),
          if (item.failureReason case final reason?)
            _StatRow(label: 'Error', value: reason, ellipsis: true),
          _StatRow(
            label: 'Priority',
            child: Align(
              alignment: Alignment.centerRight,
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
          ),
          const SizedBox(height: 6),
          _Advanced(
            children: [
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
                value: !item.resumeSupported
                    ? 'No'
                    : item.isTorrent
                    ? 'Yes — piece-verified'
                    : item.isMedia
                    ? 'Yes — continues partial streams'
                    : 'Yes — byte ranges',
              ),
              if (item.filePath case final path?)
                _StatRow(label: 'File', value: path, ellipsis: true),
              _StatRow(label: 'Source URL', value: item.url, ellipsis: true),
              _StatRow(
                label: 'Last activity',
                value: formatDateTime(item.lastActivity),
              ),
            ],
          ),
          const SizedBox(height: 22),
          ..._actions(context),
        ],
      ),
    );
  }

  static TextStyle _figure(ZonPalette palette) => TextStyle(
    color: palette.textPrimary,
    fontSize: 21,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    fontFeatures: AppType.tabular,
    height: 1.1,
  );

  static String _statusLabel(DownloadStatus status) => switch (status) {
    DownloadStatus.downloading => 'Downloading',
    DownloadStatus.paused => 'Paused',
    DownloadStatus.queued => 'Queued',
    DownloadStatus.completed => 'Completed',
    DownloadStatus.failed => 'Failed',
    DownloadStatus.verifying => 'Processing',
    DownloadStatus.cancelled => 'Cancelled',
  };

  /// "Disk Image", "Video", ... from the extension, else the MIME type.
  static String _fileType(DownloadItem item) {
    final name = item.fileName.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';
    return switch (ext) {
      'dmg' || 'iso' || 'img' => 'Disk Image',
      'pkg' || 'exe' || 'msi' || 'deb' || 'rpm' || 'appimage' => 'Installer',
      'zip' || 'rar' || '7z' || 'tar' || 'gz' || 'xz' => 'Archive',
      'mp4' || 'mkv' || 'mov' || 'avi' || 'webm' => 'Video',
      'mp3' || 'm4a' || 'flac' || 'wav' || 'opus' || 'aac' => 'Audio',
      'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'heic' => 'Image',
      'pdf' => 'PDF Document',
      'torrent' => 'Torrent',
      _ when item.isTorrent => 'Torrent',
      _ => item.contentType.isEmpty ? 'File' : item.contentType,
    };
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

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: AppType.eyebrow(context.palette.textMuted)),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Container(height: 1, color: context.palette.border),
    );
  }
}

/// Open, folder, copy link and remove, plus close in the drawer.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.item, required this.onAction, this.onClose});

  final DownloadItem item;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tooltip, DownloadCardAction? action) {
      return MonoIconButton(
        icon: icon,
        tooltip: tooltip,
        size: 36,
        raised: true,
        onTap: action == null ? null : () => onAction(action, item),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        button(
          Icons.open_in_new_rounded,
          'Open file',
          item.status == DownloadStatus.completed
              ? DownloadCardAction.openFile
              : null,
        ),
        button(
          Icons.folder_open_rounded,
          'Show in folder',
          DownloadCardAction.openFolder,
        ),
        button(Icons.link_rounded, 'Copy link', DownloadCardAction.copyUrl),
        button(
          Icons.delete_outline_rounded,
          'Remove',
          DownloadCardAction.remove,
        ),
        if (onClose != null)
          MonoIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            size: 36,
            onTap: onClose,
          ),
      ],
    );
  }
}

/// Large artwork: the media thumbnail, or the file-type glyph on a dark
/// gradient.
class _Preview extends StatelessWidget {
  const _Preview({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final glyph = Center(
      child: Icon(
        item.isTorrent ? Icons.hub_outlined : fileIconFor(item.fileName),
        size: 54,
        color: palette.textSecondary,
      ),
    );
    final thumbnail = item.thumbnailUrl;

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
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

/// Bar chart of one download's recent speed, newest on the right.
class _SpeedBars extends StatelessWidget {
  const _SpeedBars({required this.samples, required this.height});

  final List<double> samples;
  final double height;

  static const int bars = 24;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _SpeedBarsPainter(
          samples: samples.length > bars
              ? samples.sublist(samples.length - bars)
              : samples,
          glow: context.palette.glow,
          idle: context.palette.track,
        ),
      ),
    );
  }
}

class _SpeedBarsPainter extends CustomPainter {
  _SpeedBarsPainter({
    required this.samples,
    required this.glow,
    required this.idle,
  });

  final List<double> samples;
  final Color glow;
  final Color idle;

  @override
  void paint(Canvas canvas, Size size) {
    const count = _SpeedBars.bars;
    final slot = size.width / count;
    final width = (slot * 0.45).clamp(1.5, 3.0);
    final peak = samples.fold<double>(1024, (a, b) => b > a ? b : a);
    // Right-align the samples we have; empty slots show as stubs.
    final offset = count - samples.length;
    for (var i = 0; i < count; i++) {
      final value = i >= offset ? samples[i - offset] : 0.0;
      final fraction = value / peak;
      final bar = (size.height * fraction).clamp(2.0, size.height);
      final x = size.width - (count - i) * slot + (slot - width) / 2;
      final age = i / (count - 1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - bar, width, bar),
          const Radius.circular(1),
        ),
        Paint()
          ..color = value > 0
              ? glow.withValues(alpha: 0.35 + 0.65 * age)
              : idle,
      );
    }
  }

  @override
  bool shouldRepaint(_SpeedBarsPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.glow != glow ||
      oldDelegate.idle != idle;
}

/// [slots] cells in two rows; the first [connections] light up while the
/// download is moving.
class _ConnectionGrid extends StatelessWidget {
  const _ConnectionGrid({required this.connections, required this.live});

  final int connections;
  final bool live;

  /// Most connections one download may use (see the add dialog).
  static const int slots = 32;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const perRow = slots ~/ 2;

    Widget cell(int index) {
      final lit = live && index < connections;
      final used = index < connections;
      return Container(
        width: 6,
        height: 11,
        margin: const EdgeInsets.only(left: 3),
        decoration: BoxDecoration(
          color: lit ? palette.glow : Colors.transparent,
          borderRadius: BorderRadius.circular(1.5),
          border: Border.all(
            color: lit
                ? palette.glow
                : used
                ? palette.textMuted
                : palette.borderStrong,
          ),
          boxShadow: lit
              ? [
                  BoxShadow(
                    color: palette.glow.withValues(alpha: 0.45),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (var i = 0; i < perRow; i++) cell(i)],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (var i = perRow; i < slots; i++) cell(i)],
        ),
      ],
    );
  }
}

/// Folder field; tapping it reveals the folder.
class _SaveTo extends StatelessWidget {
  const _SaveTo({required this.item, required this.onAction});

  final DownloadItem item;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onAction(DownloadCardAction.openFolder, item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 17,
                color: palette.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.savePath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(palette.textPrimary, size: 12.5),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Show in folder',
                child: Icon(
                  Icons.arrow_outward_rounded,
                  size: 15,
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapsed-by-default technical metadata.
class _Advanced extends StatefulWidget {
  const _Advanced({required this.children});

  final List<Widget> children;

  @override
  State<_Advanced> createState() => _AdvancedState();
}

class _AdvancedState extends State<_Advanced> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text('ADVANCED', style: AppType.eyebrow(palette.textMuted)),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(children: widget.children),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
