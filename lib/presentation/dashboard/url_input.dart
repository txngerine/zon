import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/widgets/mono_button.dart';

/// Quick actions offered underneath the URL field.
enum QuickAction { clipboard, multiple, media, batch }

class UrlInputBar extends StatefulWidget {
  const UrlInputBar({
    super.key,
    required this.onDownload,
    required this.onQuickAction,
    this.compact = false,
    this.initialValue = '',
  });

  final ValueChanged<String> onDownload;
  final ValueChanged<QuickAction> onQuickAction;
  final bool compact;
  final String initialValue;

  @override
  State<UrlInputBar> createState() => _UrlInputBarState();
}

class _UrlInputBarState extends State<UrlInputBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      widget.onQuickAction(QuickAction.clipboard);
      return;
    }
    widget.onDownload(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final height = widget.compact ? 56.0 : 66.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 8 : 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              Icon(
                Icons.link_rounded,
                size: widget.compact ? 17 : 19,
                color: palette.textMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(),
                  style: AppType.body(palette.textPrimary, size: 14),
                  cursorColor: palette.textPrimary,
                  decoration: InputDecoration(
                    hintText: 'Paste a link to start downloading...',
                    hintStyle: AppType.body(palette.textMuted, size: 14),
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MonoButton(
                label: widget.compact ? 'Start' : 'Download',
                icon: Icons.arrow_downward_rounded,
                variant: MonoButtonVariant.primary,
                height: widget.compact ? 38 : 44,
                hPadding: widget.compact ? 14 : 20,
                fontSize: 13.5,
                onTap: _submit,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _QuickChip(
              icon: Icons.content_paste_rounded,
              label: 'From Clipboard',
              onTap: () => widget.onQuickAction(QuickAction.clipboard),
            ),
            _QuickChip(
              icon: Icons.format_list_bulleted_rounded,
              label: 'Multiple Links',
              onTap: () => widget.onQuickAction(QuickAction.multiple),
            ),
            _QuickChip(
              icon: Icons.smart_display_outlined,
              label: 'YouTube / Reels / MP3',
              onTap: () => widget.onQuickAction(QuickAction.media),
            ),
            _QuickChip(
              icon: Icons.playlist_add_rounded,
              label: 'Batch Download',
              onTap: () => widget.onQuickAction(QuickAction.batch),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickChip extends StatefulWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickChip> createState() => _QuickChipState();
}

class _QuickChipState extends State<_QuickChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = _hovered ? palette.textPrimary : palette.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hovered ? palette.surfaceHighest : palette.surfaceHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? palette.borderStrong : palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: foreground),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: AppType.body(
                  foreground,
                  size: 12,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
