import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/file_glyph.dart';
import '../../core/widgets/progress_bar.dart';
import '../../data/app_state.dart';
import '../../domain/models/download.dart';
import '../dashboard/download_card.dart';

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
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.backgroundRaised,
        borderRadius: BorderRadius.circular(22),
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

  void _act(DownloadCardAction action) => onAction(action, item);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _toolbar(),
          const SizedBox(height: 18),
          _Preview(item: item),
          const SizedBox(height: 18),
          Text(
            item.fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.body(
              palette.textPrimary,
              size: 17,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _origin(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.body(palette.textMuted, size: 12.5),
          ),
          _Section(label: 'PROGRESS', child: _progress(palette)),
          _Section(label: 'SPEED', child: _speed(palette)),
          if (!item.isMedia)
            _Section(
              label: item.isTorrent ? 'PEERS' : 'CONNECTIONS',
              child: _ConnectionMeter(
                count: item.connections,
                live: item.status == DownloadStatus.downloading,
              ),
            ),
          _Section(label: 'SAVE TO', child: _saveTo(context, palette)),
          _Section(label: 'ADDITIONAL INFO', child: _info()),
        ],
      ),
    );
  }

  Widget _toolbar() {
    final completed = item.status == DownloadStatus.completed;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ToolButton(
          icon: Icons.open_in_new_rounded,
          tooltip: completed ? 'Open file' : 'Opens when finished',
          onTap: completed ? () => _act(DownloadCardAction.openFile) : null,
        ),
        _ToolButton(
          icon: Icons.folder_outlined,
          tooltip: 'Show in folder',
          onTap: () => _act(DownloadCardAction.openFolder),
        ),
        _ToolButton(
          icon: Icons.copy_rounded,
          tooltip: 'Copy link',
          onTap: () => _act(DownloadCardAction.copyUrl),
        ),
        _ToolButton(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Remove',
          onTap: () => _act(DownloadCardAction.remove),
        ),
        if (onClose != null)
          _ToolButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onTap: onClose,
          ),
      ],
    );
  }

  Widget _progress(ZonPalette palette) {
    final eta = item.etaSeconds;
    final (IconData, String, DownloadCardAction)? control =
        switch (item.status) {
          DownloadStatus.downloading => (
            Icons.pause_rounded,
            'Pause',
            DownloadCardAction.pause,
          ),
          DownloadStatus.paused || DownloadStatus.cancelled => (
            Icons.play_arrow_rounded,
            'Resume',
            DownloadCardAction.resume,
          ),
          DownloadStatus.queued => (
            Icons.play_arrow_rounded,
            'Start now',
            DownloadCardAction.resume,
          ),
          DownloadStatus.failed => (
            Icons.refresh_rounded,
            'Retry',
            DownloadCardAction.resume,
          ),
          _ => null,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${(item.progress * 100).toStringAsFixed(1)}%',
              style: AppType.numeric(
                palette.textPrimary,
                size: 20,
                weight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (control case (final icon, final tooltip, final action))
              _ToolButton(
                icon: icon,
                tooltip: tooltip,
                size: 32,
                round: true,
                onTap: () => _act(action),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ZonProgressBar(
          value: item.progress,
          active: item.status == DownloadStatus.downloading,
          color: palette.textPrimary,
          muted: switch (item.status) {
            DownloadStatus.downloading ||
            DownloadStatus.verifying ||
            DownloadStatus.completed => false,
            _ => true,
          },
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
                    : '${formatBytes(item.downloadedBytes)}  •  ${sizeLabel(item)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.numeric(palette.textSecondary, size: 12),
              ),
            ),
            if (eta != null)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'ETA ',
                      style: TextStyle(color: palette.textMuted),
                    ),
                    TextSpan(text: formatEta(eta)),
                  ],
                ),
                style: AppType.numeric(palette.textPrimary, size: 12),
              ),
          ],
        ),
      ],
    );
  }

  Widget _speed(ZonPalette palette) {
    final live = item.status == DownloadStatus.downloading;
    return Row(
      children: [
        Text(
          live ? formatSpeed(item.speed) : '—',
          style: AppType.numeric(
            palette.textPrimary,
            size: 17,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SpeedBars(
            samples: state.speedSamplesFor(item.id),
            height: 34,
          ),
        ),
      ],
    );
  }

  Widget _saveTo(BuildContext context, ZonPalette palette) {
    // Only a download that has not started can change folders; partial
    // data would otherwise be left behind.
    final editable =
        item.status == DownloadStatus.queued && item.downloadedBytes == 0;
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _act(DownloadCardAction.openFolder),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 18, color: palette.textPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.savePath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(palette.textSecondary, size: 12.5),
                ),
              ),
              SizedBox(
                width: 38,
                height: 38,
                child: editable
                    ? IconButton(
                        tooltip: 'Change folder',
                        onPressed: () async {
                          final dir = await getDirectoryPath(
                            initialDirectory: item.savePath,
                          );
                          if (dir != null) state.setSavePath(item.id, dir);
                        },
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: palette.textPrimary,
                        ),
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: palette.textMuted,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info() {
    final picked = item.selectedFiles;
    return Column(
      children: [
        _InfoRow(
          label: 'File Type',
          value: item.isTorrent ? 'Torrent' : fileTypeLabel(item.fileName),
        ),
        _InfoRow(label: 'Size', value: sizeLabel(item)),
        _InfoRow(label: 'Added', value: formatDateTime(item.addedAt)),
        _InfoRow(label: 'Status', value: _statusLabel(item)),
        _InfoRow(label: 'Source', value: item.source),
        if (item.failureReason case final reason?)
          _InfoRow(label: 'Error', value: reason, lines: 3),
        if (item.isMedia) _InfoRow(label: 'Format', value: transferLabel(item)),
        if (item.isTorrent) ...[
          _InfoRow(label: 'Seeds', value: '${item.seeders}'),
          if (picked != null)
            _InfoRow(label: 'Files', value: '${picked.length} selected'),
        ],
        if (item.filePath case final path?)
          _InfoRow(label: 'Saved as', value: path, lines: 2),
      ],
    );
  }

  static String _origin(DownloadItem item) {
    final url = item.url;
    if (url.toLowerCase().startsWith('magnet:')) return 'Magnet link';
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) {
      return item.isTorrent ? 'Torrent file' : url;
    }
    return '${uri.scheme}://${uri.host}';
  }

  static String _statusLabel(DownloadItem item) => switch (item.status) {
    DownloadStatus.downloading => 'Downloading',
    DownloadStatus.paused => 'Paused',
    DownloadStatus.queued => 'Queued',
    DownloadStatus.completed => 'Completed',
    DownloadStatus.failed => 'Failed',
    DownloadStatus.cancelled => 'Cancelled',
    DownloadStatus.verifying => item.phase ?? 'Processing',
  };
}

/// Eyebrow label over its content, separated from the previous block by a
/// hairline.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: palette.border),
          const SizedBox(height: 18),
          Text(label, style: AppType.eyebrow(palette.textMuted)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Square (or round) icon button used in the panel's toolbar.
class _ToolButton extends StatefulWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 40,
    this.round = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final bool round;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = widget.onTap != null;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _hovered && enabled
                    ? palette.surfaceHighest
                    : palette.surfaceHigh,
                borderRadius: BorderRadius.circular(
                  widget.round ? widget.size / 2 : 12,
                ),
                border: Border.all(
                  color: _hovered && enabled
                      ? palette.borderStrong
                      : palette.border,
                ),
              ),
              child: Icon(
                widget.icon,
                size: widget.size * 0.45,
                color: palette.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wide artwork at the top: the video thumbnail, or a glowing type tile.
class _Preview extends StatelessWidget {
  const _Preview({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final thumbnail = item.thumbnailUrl;
    final dot = item.fileName.lastIndexOf('.');
    final extension = item.isTorrent
        ? 'TORRENT'
        : dot < 0
        ? ''
        : item.fileName.substring(dot + 1).toUpperCase();

    final art = Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _HorizonPainter(
            seed: item.fileName.hashCode,
            rim: palette.glow,
            sky: palette.background,
            ground: palette.surfaceHigh,
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: palette.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.isTorrent
                      ? Icons.hub_outlined
                      : fileIconFor(item.fileName),
                  size: 14,
                  color: palette.textPrimary,
                ),
                if (extension.isNotEmpty && extension.length <= 8) ...[
                  const SizedBox(width: 6),
                  Text(
                    extension,
                    style: AppType.eyebrow(
                      palette.textSecondary,
                      size: 9,
                      spacing: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: thumbnail == null
            ? art
            : Image.network(
                thumbnail,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => art,
              ),
      ),
    );
  }
}

/// A planet's lit horizon under a starfield, varied per file by [seed].
class _HorizonPainter extends CustomPainter {
  _HorizonPainter({
    required this.seed,
    required this.rim,
    required this.sky,
    required this.ground,
  });

  final int seed;
  final Color rim;
  final Color sky;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = sky);

    final random = math.Random(seed);
    final star = Paint();
    for (var i = 0; i < 46; i++) {
      final p = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height * 0.75,
      );
      star.color = Colors.white.withValues(
        alpha: 0.15 + random.nextDouble() * 0.55,
      );
      canvas.drawCircle(p, 0.4 + random.nextDouble() * 0.8, star);
    }

    // Planet: a huge circle whose edge crosses the frame diagonally.
    final radius = size.width * (0.95 + random.nextDouble() * 0.25);
    final center = Offset(
      size.width * (0.95 + random.nextDouble() * 0.2),
      size.height + radius * 0.55,
    );
    final planet = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.55, -0.75),
          radius: 0.9,
          colors: [ground, sky],
        ).createShader(planet),
    );
    // Atmosphere: soft glow outside, crisp lit rim on the edge.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = rim.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = SweepGradient(
          center: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.85),
            rim.withValues(alpha: 0.6),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.55, 0.68, 0.78, 0.9],
        ).createShader(planet),
    );
  }

  @override
  bool shouldRepaint(_HorizonPainter oldDelegate) =>
      oldDelegate.seed != seed ||
      oldDelegate.rim != rim ||
      oldDelegate.sky != sky ||
      oldDelegate.ground != ground;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.lines = 1});

  final String label;
  final String value;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppType.body(palette.textMuted, size: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: lines,
              overflow: TextOverflow.ellipsis,
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

/// "16 / 32" beside two rows of connection slots; live slots glow.
class _ConnectionMeter extends StatelessWidget {
  const _ConnectionMeter({required this.count, required this.live});

  final int count;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final slots = count <= 16 ? 16 : 32;
    final perRow = slots ~/ 2;
    final lit = live ? count.clamp(0, slots) : 0;

    Widget cell(int index) {
      final on = index < lit;
      return Container(
        width: 7,
        height: 12,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: on ? palette.glow.withValues(alpha: 0.35) : null,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: on ? palette.glow : palette.track,
            width: 1.3,
          ),
          boxShadow: on
              ? [
                  BoxShadow(
                    color: palette.glow.withValues(alpha: 0.4),
                    blurRadius: 5,
                  ),
                ]
              : null,
        ),
      );
    }

    return Row(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$lit'),
              TextSpan(
                text: ' / $slots',
                style: TextStyle(color: palette.textMuted),
              ),
            ],
          ),
          style: AppType.numeric(
            palette.textPrimary,
            size: 17,
            weight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Column(
          children: [
            for (var row = 0; row < 2; row++)
              Padding(
                padding: EdgeInsets.only(top: row == 0 ? 0 : 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < perRow; i++) cell(row * perRow + i),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Recent throughput as a strip of glowing bars.
class _SpeedBars extends StatelessWidget {
  const _SpeedBars({required this.samples, this.height = 44});

  final List<double> samples;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _SpeedBarsPainter(
        samples: samples,
        bar: context.palette.glow,
        track: context.palette.track,
      ),
    );
  }
}

class _SpeedBarsPainter extends CustomPainter {
  _SpeedBarsPainter({
    required this.samples,
    required this.bar,
    required this.track,
  });

  final List<double> samples;
  final Color bar;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 3.0;
    const width = 3.0;
    final count = ((size.width + gap) / (width + gap)).floor();
    if (count <= 0) return;
    final recent = samples.length > count
        ? samples.sublist(samples.length - count)
        : samples;
    final peak = recent.fold<double>(1024, (a, b) => b > a ? b : a);
    final offset = count - recent.length;

    for (var i = 0; i < count; i++) {
      final x = i * (width + gap);
      final sample = i < offset ? 0.0 : recent[i - offset];
      final h = sample <= 0 ? 2.0 : (sample / peak) * size.height;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, width, h),
        const Radius.circular(1.5),
      );
      // Fade the older bars so the strip reads left-to-right as time.
      final age = 0.35 + 0.65 * (i / count);
      canvas.drawRRect(
        rect,
        Paint()..color = sample <= 0 ? track : bar.withValues(alpha: age),
      );
    }
  }

  @override
  bool shouldRepaint(_SpeedBarsPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.bar != bar ||
      oldDelegate.track != track;
}
