import 'package:flutter/material.dart';

import '../theme/zon_palette.dart';

/// Custom monochrome switch — avoids the default Material treatment.
class MonoSwitch extends StatefulWidget {
  const MonoSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 40,
    this.height = 23,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;

  @override
  State<MonoSwitch> createState() => _MonoSwitchState();
}

class _MonoSwitchState extends State<MonoSwitch> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = widget.onChanged != null;
    final value = widget.value;
    final thumb = widget.height - 4;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? () => widget.onChanged!(!value) : null,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: widget.width,
            height: widget.height,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: value ? palette.accent : palette.surfaceHighest,
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(
                color: value
                    ? palette.accent
                    : _hovered
                    ? palette.borderStrong
                    : palette.border,
              ),
            ),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: thumb,
              height: thumb,
              decoration: BoxDecoration(
                color: value ? palette.onAccent : palette.textMuted,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled switch row used throughout settings.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        MonoSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}
