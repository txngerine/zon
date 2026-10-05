import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/filter_tabs.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/mono_dropdown.dart';
import '../../data/app_state.dart';
import '../../domain/models/download.dart';
import '../../domain/models/ui_state.dart';
import 'download_card.dart';

/// Downloads header, filter tabs, sorting, view controls, queue tools and the
/// card list itself.
class DownloadListSection extends StatelessWidget {
  const DownloadListSection({
    super.key,
    required this.state,
    required this.onCardTap,
    required this.onCardAction,
    required this.onAddDownload,
  });

  final AppState state;
  final void Function(DownloadItem item) onCardTap;
  final void Function(DownloadCardAction action, DownloadItem item)
  onCardAction;
  final VoidCallback onAddDownload;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final items = state.visibleDownloads;
    final isQueue = state.section == AppSection.queued;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(state: state),
        if (isQueue && state.queuedCount > 0) ...[
          const SizedBox(height: 16),
          _QueueTools(state: state),
        ],
        const SizedBox(height: 16),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: EmptyState(
              compact: true,
              title: _emptyTitle(),
              message: _emptyMessage(),
              actionLabel: state.section == AppSection.all
                  ? 'Add Download'
                  : null,
              onAction: state.section == AppSection.all ? onAddDownload : null,
            ),
          )
        else if (isQueue)
          _QueueList(
            state: state,
            items: state.queuedDownloads,
            onCardTap: onCardTap,
            onCardAction: onCardAction,
          )
        else
          ..._buildCards(items, palette),
      ],
    );
  }

  List<Widget> _buildCards(List<DownloadItem> items, ZonPalette palette) {
    final compact = state.viewMode == ViewMode.compact;
    return [
      for (var i = 0; i < items.length; i++)
        _Enter(
          key: ValueKey(items[i].id),
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DownloadCard(
              item: items[i],
              compact: compact,
              selected: state.selected?.id == items[i].id,
              showDetailsAction: false,
              onTap: () => onCardTap(items[i]),
              onAction: onCardAction,
            ),
          ),
        ),
    ];
  }

  String _emptyTitle() {
    return switch (state.section) {
      AppSection.active => 'Nothing downloading.',
      AppSection.queued => 'Queue is empty.',
      AppSection.completed => 'No completed downloads.',
      AppSection.failed => 'No failed downloads.',
      _ => 'No downloads yet.',
    };
  }

  String _emptyMessage() {
    if (state.downloadQuery.isNotEmpty) {
      return 'No downloads match your search.';
    }
    return switch (state.section) {
      AppSection.active => 'Transfers you start will appear here in real time.',
      AppSection.queued =>
        'Downloads waiting for a free slot will line up here.',
      AppSection.completed => 'Finished files will be collected here.',
      AppSection.failed => 'Nothing went wrong — nice.',
      _ => 'Your downloads will appear here.',
    };
  }
}

/// Fade + slide entrance used for cards.
class _Enter extends StatelessWidget {
  const _Enter({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.05).clamp(0.0, 0.4);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + (index.clamp(0, 6) * 40)),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final count = state.visibleDownloads.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;

        final title = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Downloads',
              style: AppType.heading(
                palette.textPrimary,
                size: 20,
                spacing: -0.4,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.surfaceHighest,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                '$count',
                style: AppType.numeric(
                  palette.textSecondary,
                  size: 11,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

        final controls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MonoDropdown<SortOption>(
              value: state.sort,
              options: [
                for (final option in SortOption.values)
                  MonoOption(option, option.label),
              ],
              onChanged: state.setSort,
            ),
            const SizedBox(width: 8),
            _ViewToggle(state: state),
          ],
        );

        final tabs = FilterTabs<DownloadFilter>(
          values: DownloadFilter.values,
          selected: state.section.filter ?? DownloadFilter.all,
          labelOf: (filter) => filter.label,
          countOf: (filter) => switch (filter) {
            DownloadFilter.all => state.downloads.length,
            DownloadFilter.active => state.activeCount + state.verifyingCount,
            DownloadFilter.queued => state.queuedCount,
            DownloadFilter.completed =>
              state.downloads
                  .where((item) => item.status == DownloadStatus.completed)
                  .length,
            DownloadFilter.failed =>
              state.downloads
                  .where(
                    (item) =>
                        item.status == DownloadStatus.failed ||
                        item.status == DownloadStatus.cancelled,
                  )
                  .length,
          },
          onSelected: (filter) => state.setSection(switch (filter) {
            DownloadFilter.all => AppSection.all,
            DownloadFilter.active => AppSection.active,
            DownloadFilter.queued => AppSection.queued,
            DownloadFilter.completed => AppSection.completed,
            DownloadFilter.failed => AppSection.failed,
          }),
        );

        final search = _SearchField(state: state);

        if (wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  title,
                  const Spacer(),
                  search,
                  const SizedBox(width: 10),
                  controls,
                ],
              ),
              const SizedBox(height: 16),
              tabs,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [tabs, search]),
            const SizedBox(height: 12),
            controls,
          ],
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 210,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: palette.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 16, color: palette.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              onChanged: state.setDownloadQuery,
              style: AppType.body(palette.textPrimary, size: 12.5),
              cursorColor: palette.textPrimary,
              decoration: InputDecoration(
                hintText: 'Search downloads',
                hintStyle: AppType.body(palette.textMuted, size: 12.5),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (state.downloadQuery.isNotEmpty)
            GestureDetector(
              onTap: () => state.setDownloadQuery(''),
              child: Icon(
                Icons.close_rounded,
                size: 15,
                color: palette.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget button(IconData icon, ViewMode mode, String tooltip) {
      final active = state.viewMode == mode;
      return Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: () => state.setViewMode(mode),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 34,
              height: 32,
              decoration: BoxDecoration(
                color: active ? palette.surfaceHighest : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: active ? palette.textPrimary : palette.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.backgroundRaised,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.view_list_rounded, ViewMode.list, 'List view'),
          button(Icons.density_small_rounded, ViewMode.compact, 'Compact view'),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _QueueTools extends StatelessWidget {
  const _QueueTools({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: palette.backgroundRaised,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(
            state.queuePaused
                ? Icons.pause_rounded
                : Icons.drag_indicator_rounded,
            size: 16,
            color: palette.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.queuePaused
                  ? 'Queue paused — no new downloads will start.'
                  : 'Drag downloads to reorder the queue.',
              overflow: TextOverflow.ellipsis,
              style: AppType.body(palette.textMuted, size: 12),
            ),
          ),
          MonoButton(
            label: state.queuePaused ? 'Resume queue' : 'Pause queue',
            icon: state.queuePaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            height: 32,
            fontSize: 12,
            onTap: state.toggleQueue,
          ),
          const SizedBox(width: 8),
          MonoButton(
            label: 'Clear queue',
            icon: Icons.delete_sweep_rounded,
            height: 32,
            fontSize: 12,
            onTap: state.queuedCount == 0 ? null : state.clearQueue,
          ),
        ],
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({
    required this.state,
    required this.items,
    required this.onCardTap,
    required this.onCardAction,
  });

  final AppState state;
  final List<DownloadItem> items;
  final void Function(DownloadItem item) onCardTap;
  final void Function(DownloadCardAction action, DownloadItem item)
  onCardAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (items.isEmpty) return const SizedBox.shrink();

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: state.reorderQueue,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            key: ValueKey(items[i].id),
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReorderableDragStartListener(
                  index: i,
                  child: Tooltip(
                    message: 'Drag to reorder',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(
                        width: 30,
                        height: 56,
                        margin: const EdgeInsets.only(top: 16),
                        decoration: BoxDecoration(
                          color: palette.surfaceHigh,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: palette.border),
                        ),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 16,
                          color: palette.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DownloadCard(
                    item: items[i],
                    selected: state.selected?.id == items[i].id,
                    onTap: () => onCardTap(items[i]),
                    onAction: onCardAction,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
