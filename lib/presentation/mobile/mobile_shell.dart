import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/widgets/zon_logo.dart';
import '../../data/app_state.dart';
import '../../domain/models/download.dart';
import '../../domain/models/ui_state.dart';
import '../dashboard/dashboard.dart';
import '../dashboard/download_card.dart';
import '../dashboard/url_input.dart';
import '../dialogs/add_download_dialog.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';

/// Single-column layout used on phones and other narrow viewports.
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
  final void Function(DownloadItem item) onCardTap;
  final void Function(DownloadCardAction action, DownloadItem item)
  onCardAction;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  bool _searching = false;

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(
          state: state,
          searching: _searching,
          onToggleSearch: () {
            setState(() => _searching = !_searching);
            if (!_searching) state.setDownloadQuery('');
          },
        ),
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
            child: _MobileSearch(state: state),
          ),
        Expanded(
          child: switch (state.section) {
            AppSection.settings => SettingsScreen(state: state),
            AppSection.history => HistoryScreen(state: state),
            _ => _dashboard(),
          },
        ),
        _BottomNav(state: state),
      ],
    );
  }

  Widget _dashboard() {
    return DashboardScreen(
      state: state,
      onAddDownload: widget.onAddDownload,
      onQuickAction: widget.onQuickAction,
      onCardTap: widget.onCardTap,
      onCardAction: widget.onCardAction,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.searching,
    required this.onToggleSearch,
  });

  final AppState state;
  final bool searching;
  final VoidCallback onToggleSearch;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: palette.backgroundElevated,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          ZonLogo(size: 30),
          const SizedBox(width: 11),
          Text(
            'ZON',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.4,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onToggleSearch,
            tooltip: 'Search',
            icon: Icon(
              searching ? Icons.close_rounded : Icons.search_rounded,
              size: 20,
              color: searching ? palette.textPrimary : palette.textSecondary,
            ),
          ),
          IconButton(
            onPressed: () => state.setSection(AppSection.settings),
            tooltip: 'Settings',
            icon: Icon(
              Icons.tune_rounded,
              size: 20,
              color: state.section == AppSection.settings
                  ? palette.textPrimary
                  : palette.textSecondary,
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
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 17, color: palette.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (value) {
                if (state.section.isRoot) state.setSection(AppSection.all);
                state.setDownloadQuery(value);
              },
              style: AppType.body(palette.textPrimary, size: 14),
              cursorColor: palette.textPrimary,
              decoration: InputDecoration(
                hintText: 'Search downloads',
                hintStyle: AppType.body(palette.textMuted, size: 14),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.state});

  final AppState state;

  static const _items = [
    (AppSection.all, Icons.home_outlined, 'Home'),
    (AppSection.active, Icons.downloading_outlined, 'Active'),
    (AppSection.queued, Icons.schedule_outlined, 'Queued'),
    (AppSection.completed, Icons.check_circle_outline_rounded, 'Completed'),
    (AppSection.settings, Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(bottom: safeBottom),
      decoration: BoxDecoration(
        color: palette.backgroundElevated,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            for (final (section, icon, label) in _items)
              Expanded(
                child: _NavItem(
                  icon: icon,
                  label: label,
                  active: state.section == section,
                  badge: switch (section) {
                    AppSection.active => state.activeCount,
                    AppSection.queued => state.queuedCount,
                    AppSection.completed => state.completedCount,
                    _ => null,
                  },
                  onTap: () => state.setSection(section),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? badge;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = widget.active
        ? palette.textPrimary
        : _pressed
        ? palette.textSecondary
        : palette.textMuted;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: widget.active
              ? palette.textPrimary.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.active
                ? palette.textPrimary.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(widget.icon, size: 19, color: color),
                if (widget.badge != null && widget.badge! > 0)
                  Positioned(
                    right: -8,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfaceHighest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        '${widget.badge}',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
