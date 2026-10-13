import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/file_glyph.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/space_background.dart';
import '../../data/app_state.dart';
import '../../domain/models/download.dart';
import '../dashboard/download_card.dart';
import '../details/details_panel.dart';

/// Full-screen details for one download on phones: artwork over the space
/// backdrop, progress, three stat tiles, facts and big actions.
class MobileDetailsPage extends StatelessWidget {
  const MobileDetailsPage({
    super.key,
    required this.state,
    required this.id,
    required this.onAction,
  });

  final AppState state;
  final String id;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;

  /// Pushes the page for [item].
  static Future<void> open(
    BuildContext context, {
    required AppState state,
    required DownloadItem item,
    required void Function(DownloadCardAction, DownloadItem) onAction,
  }) {
    state.select(item.id);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MobileDetailsPage(state: state, id: item.id, onAction: onAction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final item = state.downloads.where((d) => d.id == id).firstOrNull;
          if (item == null) {
            // Removed while open.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.of(context).maybePop();
            });
            return const SizedBox.shrink();
          }
          return _Body(state: state, item: item, onAction: onAction);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.item,
    required this.onAction,
  });

  final AppState state;
  final DownloadItem item;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final eta = item.etaSeconds;
    final moving = item.status == DownloadStatus.downloading;
    final history = state.speedHistoryFor(item.id);
    final peak = history.fold<double>(0, (a, b) => b > a ? b : a);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Hero(item: item, topInset: top, onAction: onAction),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _percent(item.progress),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppType.tabular,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ZonProgressBar(
                        value: item.progress,
                        active: moving,
                        muted:
                            !moving && item.status != DownloadStatus.completed,
                        height: 8,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.sizeBytes > 0
                                  ? '${formatBytes(item.downloadedBytes)} / ${formatBytes(item.sizeBytes)}'
                                  : formatBytes(item.downloadedBytes),
                              style: AppType.numeric(
                                palette.textMuted,
                                size: 12.5,
                              ),
                            ),
                          ),
                          if (eta != null)
                            Text(
                              'ETA ${formatEta(eta)}',
                              style: AppType.numeric(
                                palette.textMuted,
                                size: 12.5,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              value: moving ? formatSpeed(item.speed) : '—',
                              label: 'Speed',
                              chart: SpeedBars(samples: history, height: 22),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              value: peak > 0 ? formatSpeed(peak) : '—',
                              label: 'Peak',
                              chart: Opacity(
                                opacity: 0.55,
                                child: SpeedBars(samples: history, height: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _thirdTile()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _Facts(item: item, onAction: onAction),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 14 + bottom),
          child: _ActionRow(item: item, onAction: onAction),
        ),
      ],
    );
  }

  /// Connections for files, peers for torrents, format for media.
  Widget _thirdTile() {
    if (item.isTorrent) {
      return _StatTile(value: '${item.connections}', label: 'Peers');
    }
    if (item.isMedia) {
      return _StatTile(value: item.mediaFormat?.label ?? '—', label: 'Format');
    }
    return _StatTile(
      value: '${item.connections} / ${ConnectionGrid.slots}',
      label: 'Connections',
      chart: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: ConnectionGrid(
          connections: item.connections,
          live: item.status == DownloadStatus.downloading,
        ),
      ),
    );
  }

  static String _percent(double value) {
    final percent = (value * 100).clamp(0, 100);
    return percent >= 100 || percent == 0
        ? '${percent.toStringAsFixed(0)}%'
        : '${percent.toStringAsFixed(1)}%';
  }
}

/// Space backdrop with back/more buttons, the artwork tile, name and host.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.item,
    required this.topInset,
    required this.onAction,
  });

  final DownloadItem item;
  final double topInset;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 300 + topInset,
      child: Stack(
        children: [
          const Positioned.fill(child: SpaceBackground()),
          // Fade the backdrop into the page.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.background.withValues(alpha: 0),
                    palette.background,
                  ],
                  stops: const [0.55, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                MonoIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  tooltip: 'Back',
                  size: 40,
                  iconSize: 17,
                  round: true,
                  raised: true,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                _MoreMenu(item: item, onAction: onAction),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              children: [
                FileGlyph(
                  fileName: item.fileName,
                  thumbnailUrl: item.thumbnailUrl,
                  icon: item.isTorrent ? Icons.hub_outlined : null,
                  size: 80,
                ),
                const SizedBox(height: 18),
                Text(
                  item.fileName,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(
                    palette.textPrimary,
                    size: 18,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.source,
                  style: AppType.body(palette.textMuted, size: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.item, required this.onAction});

  final DownloadItem item;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    PopupMenuItem<DownloadCardAction> entry(
      DownloadCardAction action,
      IconData icon,
      String label,
    ) => PopupMenuItem(
      value: action,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 16, color: palette.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: AppType.body(palette.textPrimary, size: 13)),
        ],
      ),
    );

    return PopupMenuButton<DownloadCardAction>(
      tooltip: 'More',
      onSelected: (action) {
        if (action == DownloadCardAction.remove) {
          Navigator.of(context).maybePop();
        }
        onAction(action, item);
      },
      itemBuilder: (_) => [
        if (item.status == DownloadStatus.completed)
          entry(
            DownloadCardAction.openFile,
            Icons.open_in_new_rounded,
            'Open file',
          ),
        entry(DownloadCardAction.copyUrl, Icons.link_rounded, 'Copy link'),
        if (item.status == DownloadStatus.completed ||
            item.status == DownloadStatus.failed)
          entry(
            DownloadCardAction.redownload,
            Icons.refresh_rounded,
            'Download again',
          ),
        entry(
          DownloadCardAction.remove,
          Icons.delete_outline_rounded,
          'Remove',
        ),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: palette.surfaceHigh,
          shape: BoxShape.circle,
          border: Border.all(color: palette.border),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 19,
          color: palette.textPrimary,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.chart});

  final String value;
  final String label;
  final Widget? chart;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 112,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppType.numeric(
                palette.textPrimary,
                size: 16,
                weight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: AppType.body(palette.textMuted, size: 11.5)),
          const Spacer(),
          ?chart,
        ],
      ),
    );
  }
}

/// Status, sizes, time left, source and folder.
class _Facts extends StatelessWidget {
  const _Facts({required this.item, required this.onAction});

  final DownloadItem item;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final eta = item.etaSeconds;
    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppType.body(palette.textMuted, size: 12.5),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
    Text text(String value) => Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppType.body(palette.textPrimary, size: 12.5),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          row('Status', text(_status(item))),
          row('File Size', text(sizeLabel(item))),
          row('Downloaded', text(formatBytes(item.downloadedBytes))),
          row('Time Left', text(eta == null ? '—' : formatEta(eta))),
          row('Source', text(shortUrl(item.url))),
          row(
            'Save To',
            Row(
              children: [
                Expanded(child: text(item.savePath)),
                MonoIconButton(
                  icon: Icons.folder_open_rounded,
                  tooltip: 'Show in folder',
                  size: 30,
                  iconSize: 15,
                  round: true,
                  onTap: () => onAction(DownloadCardAction.openFolder, item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _status(DownloadItem item) => switch (item.status) {
    DownloadStatus.downloading => 'Downloading',
    DownloadStatus.paused => 'Paused',
    DownloadStatus.queued => 'Queued',
    DownloadStatus.completed => 'Completed',
    DownloadStatus.failed => item.failureReason ?? 'Failed',
    DownloadStatus.verifying => item.phase ?? 'Processing',
    DownloadStatus.cancelled => 'Cancelled',
  };
}

/// Pause/Resume, Cancel/Remove and Open Folder as big tiles.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item, required this.onAction});

  final DownloadItem item;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;

  @override
  Widget build(BuildContext context) {
    final primary = switch (item.status) {
      DownloadStatus.downloading => (
        Icons.pause_rounded,
        'Pause',
        DownloadCardAction.pause,
      ),
      DownloadStatus.completed => (
        Icons.open_in_new_rounded,
        'Open',
        DownloadCardAction.openFile,
      ),
      DownloadStatus.failed => (
        Icons.refresh_rounded,
        'Retry',
        DownloadCardAction.resume,
      ),
      DownloadStatus.verifying => (
        Icons.hourglass_top_rounded,
        'Working',
        null,
      ),
      _ => (Icons.play_arrow_rounded, 'Resume', DownloadCardAction.resume),
    };
    final finished = item.status == DownloadStatus.completed;

    return Row(
      children: [
        Expanded(
          child: _BigAction(
            icon: primary.$1,
            label: primary.$2,
            onTap: primary.$3 == null
                ? null
                : () => onAction(primary.$3!, item),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BigAction(
            icon: finished ? Icons.delete_outline_rounded : Icons.close_rounded,
            label: finished ? 'Remove' : 'Cancel',
            onTap: () {
              if (finished) Navigator.of(context).maybePop();
              onAction(
                finished
                    ? DownloadCardAction.remove
                    : DownloadCardAction.cancel,
                item,
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BigAction(
            icon: Icons.folder_open_rounded,
            label: 'Open Folder',
            onTap: () => onAction(DownloadCardAction.openFolder, item),
          ),
        ),
      ],
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onTap != null;
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: enabled ? palette.textPrimary : palette.textMuted,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppType.body(
                  enabled ? palette.textPrimary : palette.textMuted,
                  size: 13,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
