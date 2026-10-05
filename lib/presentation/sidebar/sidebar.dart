import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/zon_logo.dart';
import '../../data/app_state.dart';
import '../../domain/models/ui_state.dart';

/// Left navigation rail (240px) or collapsed icon rail (76px) on compact
/// desktop widths.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.state,
    required this.onAddDownload,
    this.collapsed = false,
  });

  final AppState state;
  final VoidCallback onAddDownload;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: collapsed ? 76 : 240,
      decoration: BoxDecoration(
        color: palette.backgroundElevated,
        border: Border(right: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(collapsed ? 16 : 22, 24, 16, 0),
            child: collapsed
                ? const Center(child: ZonLogo(size: 36))
                : const ZonBrand(),
          ),
          const SizedBox(height: 26),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 14 : 16),
            child: collapsed
                ? MonoIconButton(
                    icon: Icons.add_rounded,
                    filled: true,
                    size: 44,
                    iconSize: 20,
                    tooltip: 'Add Download',
                    onTap: onAddDownload,
                  )
                : MonoButton(
                    label: 'Add Download',
                    icon: Icons.add_rounded,
                    expand: true,
                    variant: MonoButtonVariant.primary,
                    height: 42,
                    onTap: onAddDownload,
                  ),
          ),
          const SizedBox(height: 22),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Text('LIBRARY', style: AppType.eyebrow(palette.textMuted)),
            ),
          const SizedBox(height: 10),
          _NavItem(
            section: AppSection.all,
            collapsed: collapsed,
            badge: state.downloads.length,
            active: state.section == AppSection.all,
            onTap: () => state.setSection(AppSection.all),
          ),
          _NavItem(
            section: AppSection.active,
            collapsed: collapsed,
            badge: state.activeCount + state.verifyingCount,
            active: state.section == AppSection.active,
            onTap: () => state.setSection(AppSection.active),
          ),
          _NavItem(
            section: AppSection.queued,
            collapsed: collapsed,
            badge: state.queuedCount,
            active: state.section == AppSection.queued,
            onTap: () => state.setSection(AppSection.queued),
          ),
          _NavItem(
            section: AppSection.completed,
            collapsed: collapsed,
            badge: state.completedCount,
            active: state.section == AppSection.completed,
            onTap: () => state.setSection(AppSection.completed),
          ),
          _NavItem(
            section: AppSection.failed,
            collapsed: collapsed,
            badge: state.failedCount,
            active: state.section == AppSection.failed,
            onTap: () => state.setSection(AppSection.failed),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 26 : 22),
            child: Container(height: 1, color: palette.border),
          ),
          const SizedBox(height: 14),
          _NavItem(
            section: AppSection.history,
            collapsed: collapsed,
            badge: state.history.length,
            active: state.section == AppSection.history,
            onTap: () => state.setSection(AppSection.history),
          ),
          _NavItem(
            section: AppSection.settings,
            collapsed: collapsed,
            active: state.section == AppSection.settings,
            onTap: () => state.setSection(AppSection.settings),
          ),
          const Spacer(),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _ExtensionCard(
                onTap: () => state.showToast(
                  'Browser extension — connect ZON to your browser',
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(collapsed ? 8 : 22, 0, 16, 18),
            child: collapsed
                ? const Center(child: _VersionDot())
                : Row(
                    children: [
                      const _VersionDot(),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'ZON 1.0.0  •  ENGINE STANDBY',
                            style: AppType.eyebrow(
                              palette.textMuted,
                              size: 8.5,
                              spacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _VersionDot extends StatelessWidget {
  const _VersionDot();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: palette.textPrimary.withValues(alpha: 0.7),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.section,
    required this.active,
    required this.onTap,
    this.badge,
    this.collapsed = false,
  });

  final AppSection section;
  final bool active;
  final VoidCallback onTap;
  final int? badge;
  final bool collapsed;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = widget.active;
    final hovered = _hovered && !active;

    final Color background;
    final Color border;
    if (active) {
      background = palette.surfaceHigh;
      border = palette.textPrimary.withValues(alpha: 0.14);
    } else if (hovered) {
      background = palette.hover;
      border = Colors.transparent;
    } else {
      background = Colors.transparent;
      border = Colors.transparent;
    }

    final foreground = active
        ? palette.textPrimary
        : hovered
        ? palette.textSecondary
        : palette.textMuted;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: widget.collapsed
          ? Icon(widget.section.icon, size: 18, color: foreground)
          : Row(
              children: [
                Icon(widget.section.icon, size: 17, color: foreground),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    widget.section.label,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(
                      foreground,
                      size: 13,
                      weight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.badge != null && widget.badge! > 0)
                  Text(
                    '${widget.badge}',
                    style: AppType.numeric(
                      active ? palette.textSecondary : palette.textMuted,
                      size: 11,
                      weight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
    );

    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 14 : 16),
      child: content,
    );

    Widget body = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: row,
      ),
    );

    if (widget.collapsed) {
      body = Tooltip(message: widget.section.label, child: body);
    }
    return body;
  }
}

class _ExtensionCard extends StatefulWidget {
  const _ExtensionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ExtensionCard> createState() => _ExtensionCardState();
}

class _ExtensionCardState extends State<_ExtensionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _hovered ? palette.surfaceHigh : palette.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: _hovered ? palette.borderStrong : palette.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.extension_outlined,
                size: 16,
                color: palette.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Browser Extension',
                      style: AppType.body(
                        palette.textPrimary,
                        size: 12.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Capture links automatically',
                      style: AppType.body(palette.textMuted, size: 10.5),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
