import 'package:flutter/material.dart';

import '../theme/app_type.dart';
import '../theme/zon_palette.dart';

/// Segmented filter tabs (All / Active / Queued / ...).
class FilterTabs<T> extends StatelessWidget {
  const FilterTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelected,
    required this.labelOf,
    this.countOf,
    this.compact = false,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) labelOf;
  final int Function(T)? countOf;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final height = compact ? 30.0 : 34.0;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.backgroundRaised,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: palette.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in values)
              _Tab<T>(
                value: value,
                isActive: value == selected,
                label: labelOf(value),
                count: countOf?.call(value),
                height: height,
                onTap: () => onSelected(value),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab<T> extends StatefulWidget {
  const _Tab({
    required this.value,
    required this.isActive,
    required this.label,
    required this.height,
    required this.onTap,
    this.count,
  });

  final T value;
  final bool isActive;
  final String label;
  final int? count;
  final double height;
  final VoidCallback onTap;

  @override
  State<_Tab<T>> createState() => _TabState<T>();
}

class _TabState<T> extends State<_Tab<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = widget.isActive
        ? palette.textPrimary
        : _hovered
        ? palette.textSecondary
        : palette.textMuted;

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: widget.isActive
                ? palette.surfaceHighest
                : _hovered
                ? palette.hover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: widget.isActive
                ? Border.all(color: palette.textPrimary.withValues(alpha: 0.12))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: AppType.body(
                  foreground,
                  size: 12.5,
                  weight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (widget.count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '${widget.count}',
                  style: AppType.numeric(
                    widget.isActive ? foreground : palette.textMuted,
                    size: 11,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
