import 'package:flutter/material.dart';

import '../theme/zon_palette.dart';

/// The base surface used across ZON: soft black elevation, hairline border,
/// generous corner radius and an optional hover/selected treatment.
class ZonCard extends StatefulWidget {
  const ZonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 16,
    this.selected = false,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.expand = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool selected;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool expand;

  @override
  State<ZonCard> createState() => _ZonCardState();
}

class _ZonCardState extends State<ZonCard> {
  bool _hovered = false;

  bool get _interactive => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final interactive = _interactive;

    Color background;
    Color border;
    if (widget.backgroundColor != null) {
      background = widget.backgroundColor!;
      border = widget.borderColor ?? palette.border;
    } else if (widget.selected) {
      background = palette.surfaceHigh;
      border = palette.textPrimary.withValues(alpha: 0.16);
    } else if (_hovered && interactive) {
      background = palette.surfaceHigh;
      border = palette.borderStrong;
    } else {
      background = palette.surface;
      border = palette.border;
    }

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: border),
        boxShadow: widget.selected
            ? [
                BoxShadow(
                  color: palette.shadow.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: widget.child,
    );

    final body = widget.expand
        ? SizedBox(width: double.infinity, child: content)
        : content;

    if (!interactive) return body;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: body,
      ),
    );
  }
}

/// Thin vertical/horizontal divider used between content groups.
class ZonDivider extends StatelessWidget {
  const ZonDivider({super.key, this.vertical = false, this.inset = 0});

  final bool vertical;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (vertical) {
      return Container(width: 1, height: inset, color: palette.border);
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Container(height: 1, color: palette.border),
    );
  }
}
