import 'package:flutter/material.dart';

import '../theme/app_type.dart';
import '../theme/zon_palette.dart';

/// A dropdown option.
class MonoOption<T> {
  const MonoOption(this.value, this.label);

  final T value;
  final String label;
}

/// Custom dropdown rendered with the ZON popup surface instead of the
/// default Material menu.
class MonoDropdown<T> extends StatefulWidget {
  const MonoDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.height = 32,
    this.width,
    this.dense = true,
    this.background,
  });

  final T value;
  final List<MonoOption<T>> options;
  final ValueChanged<T> onChanged;
  final double height;
  final double? width;
  final bool dense;
  final Color? background;

  @override
  State<MonoDropdown<T>> createState() => _MonoDropdownState<T>();
}

class _MonoDropdownState<T> extends State<MonoDropdown<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = widget.options
        .firstWhere(
          (option) => option.value == widget.value,
          orElse: () => MonoOption(widget.value, '${widget.value}'),
        )
        .label;

    return GestureDetector(
      onTap: _showMenu,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: widget.height,
          width: widget.width,
          padding: EdgeInsets.symmetric(horizontal: widget.dense ? 10 : 14),
          decoration: BoxDecoration(
            color:
                widget.background ??
                (_hovered ? palette.surfaceHighest : palette.surfaceHigh),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _hovered ? palette.borderStrong : palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: widget.width == null
                ? MainAxisSize.min
                : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(
                    palette.textPrimary,
                    size: widget.dense ? 12.5 : 13,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: palette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu() async {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final selected = await showMenu<T>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 6,
        offset.dx + size.width,
        offset.dy,
      ),
      constraints: BoxConstraints(minWidth: size.width, maxWidth: 260),
      items: [
        for (final option in widget.options)
          PopupMenuItem<T>(
            value: option.value,
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    style: AppType.body(
                      option.value == widget.value
                          ? context.palette.textPrimary
                          : context.palette.textSecondary,
                      size: 12.5,
                      weight: option.value == widget.value
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (option.value == widget.value)
                  Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: context.palette.textPrimary,
                  ),
              ],
            ),
          ),
      ],
    );

    if (selected != null) widget.onChanged(selected);
  }
}
