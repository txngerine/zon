import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/app_state.dart';
import '../../domain/models/download.dart';
import '../../domain/models/ui_state.dart';
import '../dashboard/download_card.dart';
import '../dashboard/url_input.dart';
import '../dialogs/add_download_dialog.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'add_download_sheet.dart';
import 'mobile_details_page.dart';
import 'mobile_download_card.dart';

/// Single-column layout used on phones and other narrow viewports: link
/// field, filter chips and download rows, a bottom bar with a central add
/// button, and full-screen details.
class MobileShell extends StatefulWidget {
  const MobileShell({
    super.key,
    required this.state,
    required this.onAddDownload,
    required this.onQuickAction,
    required this.onCardTap,
    required this.onCardAction,
  });

  final AppState state;
  final void Function(AddDownloadMode mode, String url) onAddDownload;
  final void Function(QuickAction action) onQuickAction;

  /// Unused here: a tap opens [MobileDetailsPage] instead of a side panel.
  final void Function(DownloadItem item) onCardTap;
  final void Function(DownloadCardAction action, DownloadItem item)
  onCardAction;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  bool _searching = false;

  AppState get state => widget.state;

  void _openAdd() => AddDownloadSheet.show(
    context,
    onAddDownload: widget.onAddDownload,
    onQuickAction: widget.onQuickAction,
  );

  void _openDetails(DownloadItem item) => MobileDetailsPage.open(
    context,
    state: state,
    item: item,
    onAction: widget.onCardAction,
  );

  @override
  Widget build(BuildContext context) {
    final onList =
        state.section != AppSection.settings &&
        state.section != AppSection.history;
    return Column(
      children: [
        _TopBar(
          state: state,
          searching: _searching,
          showSearch: onList,
          onToggleSearch: () {
            setState(() => _searching = !_searching);
            if (!_searching) state.setDownloadQuery('');
          },
        ),
        if (_searching && onList)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: _MobileSearch(state: state),
          ),
        Expanded(
          child: switch (state.section) {
            AppSection.settings => SettingsScreen(state: state),
            AppSection.history => HistoryScreen(state: state),
            _ => _Home(
              state: state,
              onSubmitLink: (url) =>
                  widget.onAddDownload(AddDownloadMode.single, url),
              onPasteFromClipboard: () =>
                  widget.onQuickAction(QuickAction.clipboard),
              onOpen: _openDetails,
              onAction: widget.onCardAction,
              onAdd: _openAdd,
            ),
          },
        ),
        _BottomNav(state: state, onAdd: _openAdd),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Top bar
// -----------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.searching,
    required this.showSearch,
    required this.onToggleSearch,
  });

  final AppState state;
  final bool searching;
  final bool showSearch;
  final VoidCallback onToggleSearch;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, top + 14, 10, 10),
      child: Row(
        children: [
          Text(
            'ZON',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 9,
              height: 1,
            ),
          ),
          const Spacer(),
          if (showSearch)
            IconButton(
              onPressed: onToggleSearch,
              tooltip: 'Search',
              icon: Icon(
                searching ? Icons.close_rounded : Icons.search_rounded,
                size: 22,
                color: palette.textSecondary,
              ),
            ),
          IconButton(
            onPressed: () => state.setSection(AppSection.settings),
            tooltip: 'Settings',
            icon: Icon(
              Icons.settings_outlined,
              size: 22,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileSearch extends StatelessWidget {
  const _MobileSearch({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 17, color: palette.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              autofocus: true,
              onChanged: (value) {
                if (state.section.isRoot) state.setSection(AppSection.all);
                state.setDownloadQuery(value);
              },
              style: AppType.body(palette.textPrimary, size: 14),
              cursorColor: palette.glow,
              decoration: InputDecoration(
                hintText: 'Search downloads',
                hintStyle: AppType.body(palette.textMuted, size: 14),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Home
// -----------------------------------------------------------------------------

class _Home extends StatelessWidget {
  const _Home({
    required this.state,
    required this.onSubmitLink,
    required this.onPasteFromClipboard,
    required this.onOpen,
    required this.onAction,
    required this.onAdd,
  });

  final AppState state;
  final ValueChanged<String> onSubmitLink;
  final VoidCallback onPasteFromClipboard;
  final ValueChanged<DownloadItem> onOpen;
  final void Function(DownloadCardAction action, DownloadItem item) onAction;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final items = state.section == AppSection.queued
        ? state.queuedDownloads
        : state.visibleDownloads;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        _LinkPill(onSubmit: onSubmitLink, onEmpty: onPasteFromClipboard),
        const SizedBox(height: 16),
        _FilterChips(state: state),
        const SizedBox(height: 14),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 36),
            child: EmptyState(
              compact: true,
              title: state.downloadQuery.isNotEmpty
                  ? 'No matches.'
                  : 'Nothing here yet.',
              message: state.downloadQuery.isNotEmpty
                  ? 'No downloads match your search.'
                  : 'Tap + to add a link, video or torrent.',
              actionLabel: 'Add Download',
              onAction: onAdd,
            ),
          )
        else
          for (final item in items)
            Padding(
              key: ValueKey(item.id),
              padding: const EdgeInsets.only(bottom: 10),
              child: MobileDownloadCard(
                item: item,
                onTap: () => onOpen(item),
                onAction: onAction,
              ),
            ),
      ],
    );
  }
}

/// "Paste a link…" with a green go button; empty submits read the clipboard.
class _LinkPill extends StatefulWidget {
  const _LinkPill({required this.onSubmit, required this.onEmpty});

  final ValueChanged<String> onSubmit;
  final VoidCallback onEmpty;

  @override
  State<_LinkPill> createState() => _LinkPillState();
}

class _LinkPillState extends State<_LinkPill> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return widget.onEmpty();
    widget.onSubmit(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 58,
      padding: const EdgeInsets.only(left: 18, right: 6),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.borderStrong),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 20, color: palette.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _submit(),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              style: AppType.body(palette.textPrimary, size: 14),
              cursorColor: palette.glow,
              decoration: InputDecoration(
                hintText: 'Paste a link to start downloading…',
                hintStyle: AppType.body(palette.textMuted, size: 14),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          Tooltip(
            message: 'Download',
            child: GestureDetector(
              onTap: _submit,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: palette.glow,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(
                      color: palette.glow.withValues(alpha: 0.35),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: Color(0xFF04140E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontally scrolling All / Active / Queued / Completed / Failed chips.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.state});

  final AppState state;

  int _count(DownloadFilter filter) =>
      state.downloads.where((item) => filter.matches(item.status)).length;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selected = state.section.filter ?? DownloadFilter.all;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final filter in DownloadFilter.values) ...[
            if (filter != DownloadFilter.all) const SizedBox(width: 8),
            GestureDetector(
              onTap: () => state.setSection(switch (filter) {
                DownloadFilter.all => AppSection.all,
                DownloadFilter.active => AppSection.active,
                DownloadFilter.queued => AppSection.queued,
                DownloadFilter.completed => AppSection.completed,
                DownloadFilter.failed => AppSection.failed,
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filter == selected ? palette.accent : palette.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: filter == selected ? palette.accent : palette.border,
                  ),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: filter.label),
                      if (filter != DownloadFilter.all)
                        TextSpan(
                          text: '  ${_count(filter)}',
                          style: TextStyle(
                            color: filter == selected
                                ? palette.onAccent.withValues(alpha: 0.6)
                                : palette.textMuted,
                          ),
                        ),
                    ],
                  ),
                  style: AppType.body(
                    filter == selected
                        ? palette.onAccent
                        : palette.textSecondary,
                    size: 13,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Bottom bar
// -----------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.state, required this.onAdd});

  final AppState state;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final section = state.section;
    final onHome =
        section != AppSection.history &&
        section != AppSection.queued &&
        section != AppSection.settings;

    Widget item(IconData icon, String label, bool active, AppSection target) {
      return Expanded(
        child: _NavItem(
          icon: icon,
          label: label,
          active: active,
          onTap: () => state.setSection(target),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(bottom: safeBottom),
      decoration: BoxDecoration(
        color: palette.backgroundElevated,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SizedBox(
        height: 66,
        child: Row(
          children: [
            item(Icons.home_rounded, 'Home', onHome, AppSection.all),
            item(
              Icons.history_rounded,
              'History',
              section == AppSection.history,
              AppSection.history,
            ),
            Expanded(
              child: Center(
                child: Tooltip(
                  message: 'Add download',
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: palette.glow,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: palette.glow.withValues(alpha: 0.45),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 28,
                        color: Color(0xFF04140E),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            item(
              Icons.format_list_bulleted_rounded,
              'Queue',
              section == AppSection.queued,
              AppSection.queued,
            ),
            item(
              Icons.settings_outlined,
              'Settings',
              section == AppSection.settings,
              AppSection.settings,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = active ? palette.glow : palette.textMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
