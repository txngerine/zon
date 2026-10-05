import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/mono_dropdown.dart';
import '../../data/app_state.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/download.dart';

enum AddDownloadMode { single, multiple, torrent, batch }

/// Polished modal for creating downloads.
class AddDownloadDialog extends StatefulWidget {
  const AddDownloadDialog({
    super.key,
    required this.state,
    this.mode = AddDownloadMode.single,
    this.initialUrl = '',
  });

  final AppState state;
  final AddDownloadMode mode;
  final String initialUrl;

  static Future<void> show(
    BuildContext context, {
    required AppState state,
    AddDownloadMode mode = AddDownloadMode.single,
    String initialUrl = '',
  }) {
    final palette =
        Theme.of(context).extension<ZonPalette>() ?? ZonPalette.dark;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Add download',
      barrierColor: palette.scrim,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, _) =>
          AddDownloadDialog(state: state, mode: mode, initialUrl: initialUrl),
      transitionBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends State<AddDownloadDialog> {
  late final TextEditingController _url;
  final TextEditingController _fileName = TextEditingController();
  final TextEditingController _savePath = TextEditingController();

  late double _connections;
  late String _speedLimit;
  DownloadPriority _priority = DownloadPriority.normal;
  bool _startImmediately = true;
  bool _createSubfolder = false;
  bool _nameEdited = false;
  String? _torrentName;

  AppState get state => widget.state;
  AddDownloadMode get mode => widget.mode;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.initialUrl);
    _savePath.text = state.settings.defaultLocation;
    _connections = state.settings.defaultConnections.toDouble();
    _speedLimit = state.settings.defaultSpeedLimit;
    if (mode == AddDownloadMode.multiple || mode == AddDownloadMode.batch) {
      _startImmediately = false;
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _fileName.dispose();
    _savePath.dispose();
    super.dispose();
  }

  String get _title => switch (mode) {
    AddDownloadMode.single => 'Add Download',
    AddDownloadMode.multiple => 'Add Multiple Links',
    AddDownloadMode.torrent => 'Add Torrent',
    AddDownloadMode.batch => 'Batch Download',
  };

  List<String> get _urls {
    if (mode == AddDownloadMode.single) {
      final value = _url.text.trim();
      return value.isEmpty ? const [] : [value];
    }
    return _url.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.startsWith('http'))
        .toList();
  }

  bool get _canStart => switch (mode) {
    AddDownloadMode.torrent => _torrentName != null,
    _ => _urls.isNotEmpty,
  };

  void _submit() {
    if (!_canStart) return;
    final start = _startImmediately;
    final paths = List<String>.of(_urls);

    for (final link in paths) {
      state.createDownload(
        url: link,
        fileName: mode == AddDownloadMode.single ? _fileName.text : null,
        savePath: _savePath.text,
        connections: _connections.round(),
        priority: _priority,
        startImmediately: start,
        createSubfolder: _createSubfolder,
      );
    }

    if (mode == AddDownloadMode.torrent && _torrentName != null) {
      state.createDownload(
        url: 'magnet:?xt=urn:btih:${_torrentName!.replaceAll('.torrent', '')}',
        fileName: _torrentName!.replaceAll('.torrent', '.iso'),
        savePath: _savePath.text,
        connections: _connections.round(),
        priority: _priority,
        startImmediately: start,
        createSubfolder: _createSubfolder,
      );
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Dialog(
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: palette.surfaceHighest,
                        border: Border.all(color: palette.border),
                      ),
                      child: Icon(
                        mode == AddDownloadMode.torrent
                            ? Icons.cloud_outlined
                            : Icons.arrow_downward_rounded,
                        size: 17,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            style: AppType.heading(
                              palette.textPrimary,
                              size: 17,
                              spacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(switch (mode) {
                            AddDownloadMode.single =>
                              'ZON will fetch metadata before transferring.',
                            AddDownloadMode.multiple =>
                              'Paste one link per line.',
                            AddDownloadMode.torrent =>
                              'Select a .torrent file to inspect its metadata.',
                            AddDownloadMode.batch =>
                              'Queue many files at once — one link per line.',
                          }, style: AppType.body(palette.textMuted, size: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (mode == AddDownloadMode.torrent)
                  ..._torrentFields(palette)
                else ...[
                  _label('URL'),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _url,
                    hint: mode == AddDownloadMode.single
                        ? 'https://example.com/large-file.iso'
                        : 'https://example.com/file-1.iso\nhttps://example.com/file-2.iso',
                    multiline: mode != AddDownloadMode.single,
                    maxLines: mode != AddDownloadMode.single ? 5 : 1,
                    icon: Icons.link_rounded,
                    onChanged: (value) {
                      if (mode == AddDownloadMode.single && !_nameEdited) {
                        final name = fileNameFromUrl(value);
                        _fileName.text = value.trim().isEmpty ? '' : name;
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  if (mode == AddDownloadMode.single) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _column(
                            'FILE NAME',
                            _textField(
                              controller: _fileName,
                              hint: 'Detected from URL',
                              icon: Icons.drive_file_rename_outline_rounded,
                              onChanged: (_) =>
                                  setState(() => _nameEdited = true),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _column(
                            'SAVE LOCATION',
                            _textField(
                              controller: _savePath,
                              hint: '~/Downloads',
                              icon: Icons.folder_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    _label('SAVE LOCATION'),
                    const SizedBox(height: 8),
                    _textField(
                      controller: _savePath,
                      hint: '~/Downloads',
                      icon: Icons.folder_outlined,
                    ),
                    const SizedBox(height: 16),
                    if (mode == AddDownloadMode.multiple ||
                        mode == AddDownloadMode.batch)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '${_urls.length} link${_urls.length == 1 ? '' : 's'} detected',
                          style: AppType.body(palette.textSecondary, size: 12),
                        ),
                      ),
                  ],
                ],
                _label('TRANSFER'),
                const SizedBox(height: 10),
                _sliderRow(
                  palette,
                  label: 'Connections',
                  value: _connections,
                  min: 1,
                  max: 32,
                  divisionLabel: '${_connections.round()}',
                  onChanged: (value) => setState(() => _connections = value),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _column(
                        'SPEED LIMIT',
                        MonoDropdown<String>(
                          value: _speedLimit,
                          options: [
                            for (final limit in AppSettings.speedLimits)
                              MonoOption(limit, limit),
                          ],
                          onChanged: (value) =>
                              setState(() => _speedLimit = value),
                          height: 40,
                          width: double.infinity,
                          dense: false,
                          background: palette.surface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _column('PRIORITY', _priorityControl(palette)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _label('OPTIONS'),
                const SizedBox(height: 10),
                _optionRow(
                  palette,
                  'Start immediately',
                  'Begin transferring as soon as metadata is ready',
                  _startImmediately,
                  (value) => setState(() => _startImmediately = value),
                ),
                const SizedBox(height: 12),
                _optionRow(
                  palette,
                  'Add to queue',
                  'Wait for a free download slot instead',
                  !_startImmediately,
                  (value) => setState(() => _startImmediately = !value),
                ),
                const SizedBox(height: 12),
                _optionRow(
                  palette,
                  'Create subfolder',
                  'Organise files inside a folder named after the host',
                  _createSubfolder,
                  (value) => setState(() => _createSubfolder = value),
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MonoButton(
                      label: 'Cancel',
                      height: 42,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    MonoButton(
                      label: mode == AddDownloadMode.torrent
                          ? 'Start Download'
                          : _urls.length > 1
                          ? 'Start ${_urls.length} Downloads'
                          : 'Start Download',
                      icon: Icons.arrow_downward_rounded,
                      variant: MonoButtonVariant.primary,
                      height: 42,
                      hPadding: 20,
                      onTap: _canStart ? _submit : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------

  List<Widget> _torrentFields(ZonPalette palette) {
    return [
      _label('TORRENT FILE'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_outlined,
              size: 20,
              color: _torrentName == null
                  ? palette.textMuted
                  : palette.textPrimary,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _torrentName ?? 'No torrent selected',
                    style: AppType.body(
                      _torrentName == null
                          ? palette.textMuted
                          : palette.textPrimary,
                      size: 13,
                      weight: FontWeight.w500,
                    ),
                  ),
                  if (_torrentName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Metadata ready  •  5.9 GB  •  1,842 pieces  •  24 trackers',
                      style: AppType.body(palette.textMuted, size: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            MonoButton(
              label: _torrentName == null ? 'Choose file' : 'Replace',
              height: 34,
              fontSize: 12,
              onTap: () => setState(
                () => _torrentName = 'archlinux-2025.10.01-x86_64.torrent',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _label('SAVE LOCATION'),
      const SizedBox(height: 8),
      _textField(
        controller: _savePath,
        hint: '~/Downloads',
        icon: Icons.folder_outlined,
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _column(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_label(label), const SizedBox(height: 8), child],
    );
  }

  Widget _label(String text) {
    final palette = context.palette;
    return Text(text, style: AppType.eyebrow(palette.textMuted, size: 9.5));
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool multiline = false,
    ValueChanged<String>? onChanged,
  }) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: multiline ? 14 : 0),
            child: Icon(icon, size: 16, color: palette.textMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              maxLines: maxLines,
              minLines: null,
              keyboardType: multiline ? TextInputType.multiline : null,
              textInputAction: multiline
                  ? TextInputAction.newline
                  : TextInputAction.done,
              style: AppType.body(palette.textPrimary, size: 13.5),
              cursorColor: palette.textPrimary,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppType.body(palette.textMuted, size: 13),
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: multiline ? 14 : 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(
    ZonPalette palette, {
    required String label,
    required double value,
    required double min,
    required double max,
    required String divisionLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AppType.body(palette.textSecondary, size: 12.5),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 56,
          child: Text(
            divisionLabel,
            textAlign: TextAlign.right,
            style: AppType.numeric(
              palette.textPrimary,
              size: 12.5,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _priorityControl(ZonPalette palette) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          for (final priority in DownloadPriority.values)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _priority = priority),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  height: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _priority == priority
                        ? palette.surfaceHighest
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    priority.label,
                    style: AppType.body(
                      _priority == priority
                          ? palette.textPrimary
                          : palette.textMuted,
                      size: 12,
                      weight: _priority == priority
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _optionRow(
    ZonPalette palette,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        _checkbox(palette, value, onChanged),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppType.body(
                  palette.textPrimary,
                  size: 13,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: AppType.body(palette.textMuted, size: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _checkbox(
    ZonPalette palette,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: value ? palette.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: value ? palette.accent : palette.border),
          ),
          child: value
              ? Icon(Icons.check_rounded, size: 14, color: palette.onAccent)
              : null,
        ),
      ),
    );
  }
}
