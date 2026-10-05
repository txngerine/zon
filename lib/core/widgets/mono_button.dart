import 'package:flutter/material.dart';

import '../theme/app_type.dart';
import '../theme/zon_palette.dart';

enum MonoButtonVariant { primary, secondary, ghost }

/// The single button style used throughout ZON.
class MonoButton extends StatefulWidget {
  const MonoButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.variant = MonoButtonVariant.secondary,
    this.height = 40,
    this.fontSize = 13,
    this.hPadding = 16,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final MonoButtonVariant variant;
  final double height;
  final double fontSize;
  final double hPadding;
  final bool expand;

  @override
  State<MonoButton> createState() => _MonoButtonState();
}

class _MonoButtonState extends State<MonoButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    late final Color background;
    late final Color border;
    late final Color foreground;

    switch (widget.variant) {
      case MonoButtonVariant.primary:
        background = _pressed && _enabled
            ? palette.accent.withValues(alpha: 0.82)
            : palette.accent;
        border = Colors.transparent;
        foreground = palette.onAccent;
      case MonoButtonVariant.secondary:
        background = _hovered && _enabled
            ? palette.surfaceHighest
            : palette.surfaceHigh;
        border = _hovered && _enabled ? palette.borderStrong : palette.border;
        foreground = palette.textPrimary;
      case MonoButtonVariant.ghost:
        background = _hovered && _enabled ? palette.hover : Colors.transparent;
        border = Colors.transparent;
        foreground = _hovered && _enabled
            ? palette.textPrimary
            : palette.textSecondary;
    }

    final opacity = _enabled ? 1.0 : 0.4;

    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: widget.fontSize + 3, color: foreground),
            const SizedBox(width: 7),
          ],
          Text(
            widget.label,
            style: AppType.body(
              foreground,
              size: widget.fontSize,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            height: widget.height,
            padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Compact icon-only action used on download cards and panels.
class MonoIconButton extends StatefulWidget {
  const MonoIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 34,
    this.iconSize = 17,
    this.filled = false,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool filled;
  final bool danger;

  @override
  State<MonoIconButton> createState() => _MonoIconButtonState();
}

class _MonoIconButtonState extends State<MonoIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final background = widget.filled
        ? palette.accent
        : _hovered
        ? palette.surfaceHighest
        : Colors.transparent;
    final foreground = widget.filled
        ? palette.onAccent
        : _hovered
        ? palette.textPrimary
        : palette.textSecondary;

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: widget.filled
            ? null
            : Border.all(
                color: _hovered ? palette.borderStrong : Colors.transparent,
              ),
      ),
      child: Icon(widget.icon, size: widget.iconSize, color: foreground),
    );

    if (widget.onTap != null) {
      button = GestureDetector(
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: button,
        ),
      );
    }

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}
