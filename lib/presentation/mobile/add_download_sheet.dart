import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../dashboard/url_input.dart';
import '../dialogs/add_download_dialog.dart';

/// Phone entry point for new downloads: a paste field, the four kinds as
/// tiles, and shortcuts. Each choice hands over to [AddDownloadDialog] (via
/// [onAddDownload]) or a quick action, so the options live in one place.
class AddDownloadSheet extends StatefulWidget {
  const AddDownloadSheet({
    super.key,
    required this.onAddDownload,
    required this.onQuickAction,
  });

  final void Function(AddDownloadMode mode, String url) onAddDownload;
  final void Function(QuickAction action) onQuickAction;

  static Future<void> show(
    BuildContext context, {
    required void Function(AddDownloadMode mode, String url) onAddDownload,
    required void Function(QuickAction action) onQuickAction,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.palette.scrim,
      builder: (_) => AddDownloadSheet(
        onAddDownload: onAddDownload,
        onQuickAction: onQuickAction,
      ),
    );
  }

  @override
  State<AddDownloadSheet> createState() => _AddDownloadSheetState();
}

class _AddDownloadSheetState extends State<AddDownloadSheet> {
  final _link = TextEditingController();
  AddDownloadMode _mode = AddDownloadMode.single;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  /// Closes the sheet, then runs [then] (dialogs must not stack on it).
  void _close(VoidCallback then) {
    Navigator.of(context).pop();
    then();
  }

  void _openMode(AddDownloadMode mode) =>
      _close(() => widget.onAddDownload(mode, _link.text.trim()));

  void _quick(QuickAction action) => _close(() => widget.onQuickAction(action));

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) setState(() => _link.text = text);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final safe = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: palette.backgroundRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: palette.border),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + safe),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add Download',
                      style: AppType.heading(palette.textPrimary, size: 20),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LinkField(
                controller: _link,
                onPaste: _paste,
                onSubmit: () => _openMode(_mode),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final (mode, icon, label) in const [
                    (AddDownloadMode.single, Icons.link_rounded, 'Link'),
                    (
                      AddDownloadMode.multiple,
                      Icons.format_list_bulleted_rounded,
                      'Multiple',
                    ),
                    (
                      AddDownloadMode.media,
                      Icons.smart_display_outlined,
                      'YouTube',
                    ),
                    (AddDownloadMode.torrent, Icons.hub_outlined, 'Torrent'),
                  ]) ...[
                    if (mode != AddDownloadMode.single)
                      const SizedBox(width: 10),
                    Expanded(
                      child: _KindTile(
                        icon: icon,
                        label: label,
                        selected: _mode == mode,
                        onTap: () {
                          if (_mode == mode) return _openMode(mode);
                          setState(() => _mode = mode);
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _Group(
                rows: [
                  (
                    Icons.content_paste_rounded,
                    'Scan from Clipboard',
                    () => _quick(QuickAction.clipboard),
                  ),
                  (
                    Icons.playlist_add_rounded,
                    'Batch Download',
                    () => _quick(QuickAction.batch),
                  ),
                  (
                    Icons.description_outlined,
                    'Import .torrent file',
                    () => _quick(QuickAction.torrent),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('QUICK ACTIONS', style: AppType.eyebrow(palette.textMuted)),
              const SizedBox(height: 10),
              _Group(
                rows: [
                  (
                    Icons.smart_display_outlined,
                    'YouTube Video',
                    () => _quick(QuickAction.media),
                  ),
                  (
                    Icons.format_list_bulleted_rounded,
                    'YouTube Playlist',
                    () => _quick(QuickAction.media),
                  ),
                  (
                    Icons.video_library_outlined,
                    'Reels / Shorts',
                    () => _quick(QuickAction.media),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkField extends StatelessWidget {
  const _LinkField({
    required this.controller,
    required this.onPaste,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onPaste;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 54,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderStrong),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 18, color: palette.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSubmit(),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              style: AppType.body(palette.textPrimary, size: 14),
              cursorColor: palette.glow,
              decoration: InputDecoration(
                hintText: 'Paste a link…',
                hintStyle: AppType.body(palette.textMuted, size: 14),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Paste',
            onPressed: onPaste,
            icon: Icon(
              Icons.content_paste_rounded,
              size: 19,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 74,
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  palette.glow.withValues(alpha: 0.12),
                  palette.surface,
                )
              : palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? palette.glow : palette.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected ? palette.glow : palette.textSecondary,
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: AppType.body(
                selected ? palette.textPrimary : palette.textSecondary,
                size: 11.5,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Row = (IconData, String, VoidCallback);

/// Card of tappable rows with chevrons.
class _Group extends StatelessWidget {
  const _Group({required this.rows});

  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Container(height: 1, color: palette.border),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: rows[i].$3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(rows[i].$1, size: 19, color: palette.textSecondary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          rows[i].$2,
                          style: AppType.body(palette.textPrimary, size: 13.5),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: palette.textMuted,
                      ),
                    ],
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
