import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/file_glyph.dart';
import '../../core/widgets/filter_tabs.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/app_state.dart';
import '../../domain/models/download.dart';
import '../../domain/models/ui_state.dart';

/// Searchable log of everything ZON has transferred.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entries = state.visibleHistory;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(34, 32, 34, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 760;

              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'History',
                        style: AppType.heading(
                          palette.textPrimary,
                          size: 26,
                          spacing: -0.6,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.surfaceHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palette.border),
                        ),
                        child: Text(
                          '${entries.length}',
                          style: AppType.numeric(
                            palette.textSecondary,
                            size: 11,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Every completed, failed and cancelled transfer.',
                    style: AppType.body(palette.textSecondary, size: 13.5),
                  ),
                ],
              );

              final search = _SearchField(state: state);

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heading, const SizedBox(height: 16), search],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 20),
                  search,
                  const SizedBox(width: 12),
                  MonoButton(
                    label: 'Clear history',
                    icon: Icons.delete_sweep_rounded,
                    onTap: state.history.isEmpty ? null : state.clearHistory,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilterTabs<HistoryFilter>(
                values: HistoryFilter.values,
                selected: state.historyFilter,
                labelOf: (filter) => filter.label,
                countOf: (filter) => state.history
                    .where((entry) => filter.matches(entry.status))
                    .length,
                onSelected: state.setHistoryFilter,
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(
                compact: true,
                title: state.historyQuery.isEmpty
                    ? 'No history yet.'
                    : 'Nothing found.',
                message: state.historyQuery.isEmpty
                    ? 'Completed, failed and cancelled downloads are recorded here.'
                    : 'Try a different search term.',
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final showDownloaded = width > 900;
                final showDate = width > 1040;
                final showDuration = width > 1140;

                return Column(
                  children: [
                    _HeaderRow(
                      showDownloaded: showDownloaded,
                      showDate: showDate,
                      showDuration: showDuration,
                    ),
                    const SizedBox(height: 6),
                    for (final entry in entries)
                      _HistoryRow(
                        key: ValueKey(entry.id),
                        entry: entry,
                        showDownloaded: showDownloaded,
                        showDate: showDate,
                        showDuration: showDuration,
                        onOpenFolder: () => state.revealHistory(entry),
                        onRedownload: () => state.redownload(entry),
                        onRemove: () => state.removeHistory(entry.id),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.state});

  final AppState state;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 240,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
              onChanged: widget.state.setHistoryQuery,
              style: AppType.body(palette.textPrimary, size: 12.5),
              cursorColor: palette.textPrimary,
              decoration: InputDecoration(
                hintText: 'Search history',
                hintStyle: AppType.body(palette.textMuted, size: 12.5),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          if (widget.state.historyQuery.isNotEmpty)
            GestureDetector(
              onTap: () => widget.state.setHistoryQuery(''),
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

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.showDownloaded,
    required this.showDate,
    required this.showDuration,
  });

  final bool showDownloaded;
  final bool showDate;
  final bool showDuration;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget cell(String label, {double? width, bool alignEnd = false}) {
      final child = Text(
        label,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        overflow: TextOverflow.ellipsis,
        style: AppType.eyebrow(palette.textMuted, size: 8.5, spacing: 1.3),
      );
      if (width == null) return Expanded(child: child);
      return SizedBox(width: width, child: child);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          cell('FILENAME'),
          cell('STATUS', width: 124),
          cell('SIZE', width: 84, alignEnd: true),
          if (showDownloaded) cell('DOWNLOADED', width: 104, alignEnd: true),
          if (showDate) cell('DATE', width: 136),
          if (showDuration) cell('DURATION', width: 82, alignEnd: true),
          cell('ACTIONS', width: 104, alignEnd: true),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  const _HistoryRow({
    super.key,
    required this.entry,
    required this.showDownloaded,
    required this.showDate,
    required this.showDuration,
    required this.onOpenFolder,
    required this.onRedownload,
    required this.onRemove,
  });

  final HistoryEntry entry;
  final bool showDownloaded;
  final bool showDate;
  final bool showDuration;
  final VoidCallback onOpenFolder;
  final VoidCallback onRedownload;
  final VoidCallback onRemove;

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entry = widget.entry;

    Widget sized(
      String text,
      double width, {
      bool alignEnd = false,
      Color? color,
    }) {
      return SizedBox(
        width: width,
        child: Text(
          text,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          overflow: TextOverflow.ellipsis,
          style: AppType.numeric(color ?? palette.textSecondary, size: 12),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? palette.surfaceHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered ? palette.border : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            FileGlyph(fileName: entry.fileName, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fileName,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(
                      palette.textPrimary,
                      size: 13,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.source,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(palette.textMuted, size: 11),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 124,
              child: StatusChip(status: entry.status, compact: true),
            ),
            sized(formatBytes(entry.sizeBytes), 84, alignEnd: true),
            if (widget.showDownloaded)
              sized(
                formatBytes(entry.downloadedBytes),
                104,
                alignEnd: true,
                color: palette.textMuted,
              ),
            if (widget.showDate) sized(formatDateTime(entry.date), 136),
            if (widget.showDuration)
              sized(formatDuration(entry.durationSeconds), 82, alignEnd: true),
            SizedBox(
              width: 104,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 140),
                opacity: _hovered ? 1 : 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MonoIconButton(
                      icon: Icons.folder_open_rounded,
                      tooltip: 'Open folder',
                      size: 28,
                      onTap: widget.onOpenFolder,
                    ),
                    const SizedBox(width: 4),
                    MonoIconButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Redownload',
                      size: 28,
                      onTap: widget.onRedownload,
                    ),
                    const SizedBox(width: 4),
                    MonoIconButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Remove',
                      size: 28,
                      onTap: widget.onRemove,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
