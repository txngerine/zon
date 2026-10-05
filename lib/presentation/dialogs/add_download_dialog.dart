import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/mono_dropdown.dart';
import '../../data/app_state.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/download.dart';
import '../../domain/models/media_format.dart';
import '../../engine/media/media_sites.dart';
import '../../engine/media/ytdlp.dart';

/// `media` is the single-link dialog with video/audio options forced on, for
/// sites ZON does not recognise by URL.
enum AddDownloadMode { single, multiple, media, batch }

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
  late MediaFormat _format;
  DownloadPriority _priority = DownloadPriority.normal;
  bool _startImmediately = true;
  bool _createSubfolder = false;
  bool _nameEdited = false;

  // Media preview (yt-dlp metadata).
  Timer? _probeDebounce;
  int _probeToken = 0;
  bool _probing = false;
  MediaInfo? _info;
  String? _probeError;
  String _probedUrl = '';
  bool _wholePlaylist = true;

  AppState get state => widget.state;
  AddDownloadMode get mode => widget.mode;
  bool get _singleLink =>
      mode == AddDownloadMode.single || mode == AddDownloadMode.media;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.initialUrl);
    _savePath.text = state.settings.defaultLocation;
    _connections = state.settings.defaultConnections.toDouble();
    _speedLimit = 'No Limit';
    _format = state.settings.defaultMediaFormat;
    if (mode == AddDownloadMode.multiple || mode == AddDownloadMode.batch) {
      _startImmediately = false;
    }
    if (widget.initialUrl.isNotEmpty) _onUrlChanged(widget.initialUrl);
    state.addListener(_onState);
  }

  @override
  void dispose() {
    state.removeListener(_onState);
    _probeDebounce?.cancel();
    _url.dispose();
    _fileName.dispose();
    _savePath.dispose();
    super.dispose();
  }

  /// Re-probe once yt-dlp finishes installing.
  void _onState() {
    if (!mounted) return;
    final ready = state.mediaTools?.hasYtDlp ?? false;
    if (ready && _isMedia && _info == null && !_probing) {
      _scheduleProbe(_url.text.trim(), immediate: true);
    }
    setState(() {});
  }

  String get _title => switch (mode) {
    AddDownloadMode.single => 'Add Download',
    AddDownloadMode.multiple => 'Add Multiple Links',
    AddDownloadMode.media => 'Download Video or Audio',
    AddDownloadMode.batch => 'Batch Download',
  };

  List<String> get _urls {
    if (_singleLink) {
      final value = _url.text.trim();
      return value.isEmpty ? const [] : [value];
    }
    return _url.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.startsWith('http'))
        .toList();
  }

  MediaSite? get _site => detectMediaSite(_url.text.trim());

  /// The single link goes through yt-dlp.
  bool get _isMedia =>
      _singleLink &&
      _url.text.trim().isNotEmpty &&
      (mode == AddDownloadMode.media || _site != null);

  int get _mediaLinkCount => _urls.where(isMediaUrl).length;

  bool get _hasYtDlp => state.mediaTools?.hasYtDlp ?? false;
  bool get _hasFfmpeg => state.mediaTools?.hasFfmpeg ?? false;

  bool get _canStart {
    if (_urls.isEmpty) return false;
    if (_isMedia && !_hasYtDlp) return false;
    if (_isMedia && _format.needsFfmpeg && !_hasFfmpeg) return false;
    return true;
  }

  void _onUrlChanged(String value) {
    if (_singleLink && !_nameEdited) {
      final link = value.trim();
      _fileName.text = link.isEmpty || _isMedia ? '' : fileNameFromUrl(link);
    }
    if (_isMedia) {
      _scheduleProbe(value.trim());
    } else {
      _probeDebounce?.cancel();
      _info = null;
      _probeError = null;
      _probing = false;
      _probedUrl = '';
    }
  }

  void _scheduleProbe(String link, {bool immediate = false}) {
    if (link == _probedUrl && (_info != null || _probing)) return;
    _probeDebounce?.cancel();
    _info = null;
    _probeError = null;
    if (!_hasYtDlp || Uri.tryParse(link)?.hasAuthority != true) {
      _probing = false;
      return;
    }
    _probing = true;
    _probeDebounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 650),
      () => _probe(link),
    );
  }

  Future<void> _probe(String link) async {
    final token = ++_probeToken;
    _probedUrl = link;
    try {
      final info = await state.probeMedia(link);
      if (!mounted || token != _probeToken) return;
      setState(() {
        _info = info;
        _probing = false;
      });
    } catch (error) {
      if (!mounted || token != _probeToken) return;
      setState(() {
        _probeError = '$error';
        _probing = false;
      });
    }
  }

  Future<void> _browse() async {
    final dir = await getDirectoryPath(initialDirectory: _savePath.text);
    if (dir != null && mounted) setState(() => _savePath.text = dir);
  }

  void _submit() {
    if (!_canStart) return;
    final start = _startImmediately;
    final connections = _connections.round();

    if (_isMedia) {
      final info = _info;
      if (info != null && info.isPlaylist && _wholePlaylist) {
        state.createMediaBatch(
          info.entries,
          format: _format,
          savePath: _savePath.text,
          connections: connections,
          priority: _priority,
          startImmediately: start,
          createSubfolder: _createSubfolder,
          speedLimit: _speedLimit,
        );
      } else {
        final typed = _fileName.text.trim();
        state.createDownload(
          url: _url.text,
          fileName: typed.isNotEmpty
              ? typed
              : (info == null || info.isPlaylist ? null : info.title),
          lockName: typed.isNotEmpty,
          savePath: _savePath.text,
          connections: connections,
          priority: _priority,
          startImmediately: start,
          createSubfolder: _createSubfolder,
          kind: DownloadKind.media,
          mediaFormat: _format,
          speedLimit: _speedLimit,
          thumbnailUrl: info?.thumbnail,
        );
      }
      Navigator.of(context).pop();
      return;
    }

    if (_singleLink) {
      state.createDownload(
        url: _url.text,
        fileName: _fileName.text,
        savePath: _savePath.text,
        connections: connections,
        priority: _priority,
        startImmediately: start,
        createSubfolder: _createSubfolder,
        speedLimit: _speedLimit,
      );
    } else {
      for (final link in List<String>.of(_urls)) {
        // Playlists in the list expand into their videos.
        unawaited(
          state.addLink(
            link,
            savePath: _savePath.text,
            connections: connections,
            priority: _priority,
            startImmediately: start,
            createSubfolder: _createSubfolder,
            mediaFormat: _format,
            speedLimit: _speedLimit,
          ),
        );
      }
    }
    Navigator.of(context).pop();
  }

  String get _startLabel {
    final info = _info;
    if (_isMedia && info != null && info.isPlaylist && _wholePlaylist) {
      return 'Download ${info.entries.length} Videos';
    }
    if (_isMedia) return _format.isAudio ? 'Download Audio' : 'Download Video';
    return _urls.length > 1
        ? 'Start ${_urls.length} Downloads'
        : 'Start Download';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final media = _isMedia;
    final mediaInList = !_singleLink && _mediaLinkCount > 0;

    return Dialog(
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
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
                        media || mode == AddDownloadMode.media
                            ? Icons.smart_display_outlined
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
                            _ when media =>
                              '${_site?.name ?? 'Media'} link — pick video or audio.',
                            AddDownloadMode.single =>
                              'Files, YouTube, Reels, TikTok — paste any link.',
                            AddDownloadMode.media => 'YouTube, Instagram Reels, TikTok, X and 1000+ sites.',
                            AddDownloadMode.multiple =>
                              'Paste one link per line.',
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
                _label('URL'),
                const SizedBox(height: 8),
                _textField(
                  controller: _url,
                  hint: switch (mode) {
                    AddDownloadMode.single =>
                      'https://example.com/file.iso or a YouTube link',
                    AddDownloadMode.media =>
                      'https://www.youtube.com/watch?v=…',
                    _ => 'https://example.com/file-1.iso\nhttps://youtu.be/…',
                  },
                  multiline: !_singleLink,
                  maxLines: _singleLink ? 1 : 5,
                  icon: Icons.link_rounded,
                  onChanged: (value) => setState(() => _onUrlChanged(value)),
                ),
                const SizedBox(height: 16),
                if (media) ..._mediaFields(palette),
                if (_singleLink) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _column(
                          'FILE NAME',
                          _textField(
                            controller: _fileName,
                            hint: media
                                ? 'Video title (default)'
                                : 'Detected from server',
                            icon: Icons.drive_file_rename_outline_rounded,
                            onChanged: (_) =>
                                setState(() => _nameEdited = true),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _column('SAVE LOCATION', _locationField()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  _label('SAVE LOCATION'),
                  const SizedBox(height: 8),
                  _locationField(),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '${_urls.length} link${_urls.length == 1 ? '' : 's'} detected'
                      '${mediaInList ? '  •  $_mediaLinkCount video/audio' : ''}',
                      style: AppType.body(palette.textSecondary, size: 12),
                    ),
                  ),
                  if (mediaInList) ...[
                    _label('FORMAT FOR VIDEO LINKS'),
                    const SizedBox(height: 10),
                    _formatChips(palette),
                    const SizedBox(height: 16),
                  ],
                ],
                _label('TRANSFER'),
                const SizedBox(height: 10),
                _sliderRow(
                  palette,
                  label: media ? 'Fragments' : 'Connections',
                  value: media ? _connections.clamp(1, 8) : _connections,
                  min: 1,
                  max: media ? 8 : 32,
                  divisionLabel:
                      '${(media ? _connections.clamp(1, 8) : _connections).round()}',
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
                  'Begin as soon as a download slot is free',
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
                  media
                      ? 'Organise files inside a folder named after the site'
                      : 'Organise files inside a folder named after the host',
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
                      label: _startLabel,
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
  // Media
  // --------------------------------------------------------------------------

  List<Widget> _mediaFields(ZonPalette palette) {
    if (!_hasYtDlp) return [_installCard(palette), const SizedBox(height: 16)];
    return [
      _previewCard(palette),
      const SizedBox(height: 16),
      _label('FORMAT'),
      const SizedBox(height: 10),
      _formatChips(palette),
      if (!_hasFfmpeg) ...[
        const SizedBox(height: 10),
        Text(
          'ffmpeg not found: MP3 is unavailable and video is limited to '
          'single-file streams (often 720p or lower).',
          style: AppType.body(palette.textMuted, size: 11.5),
        ),
      ],
      const SizedBox(height: 16),
    ];
  }

  Widget _installCard(ZonPalette palette) {
    final progress = state.installProgress;
    final busy = state.mediaToolsBusy;
    return _panel(
      palette,
      Row(
        children: [
          Icon(Icons.extension_outlined, size: 20, color: palette.textPrimary),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'yt-dlp is needed for video sites',
                  style: AppType.body(
                    palette.textPrimary,
                    size: 13,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  progress != null
                      ? 'Downloading… ${(progress * 100).round()}%'
                      : 'Free, open source, about 35 MB. ZON keeps it updated.',
                  style: AppType.body(palette.textMuted, size: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          MonoButton(
            label: busy ? 'Installing…' : 'Install',
            icon: Icons.download_rounded,
            variant: MonoButtonVariant.primary,
            height: 34,
            fontSize: 12,
            onTap: busy ? null : () => unawaited(state.installYtDlp()),
          ),
        ],
      ),
    );
  }

  Widget _previewCard(ZonPalette palette) {
    final info = _info;
    final error = _probeError;

    if (_probing || (info == null && error == null)) {
      return _panel(
        palette,
        Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(width: 13),
            Text(
              'Reading video info…',
              style: AppType.body(palette.textSecondary, size: 12.5),
            ),
          ],
        ),
      );
    }

    if (info == null) {
      return _panel(
        palette,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: palette.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppType.body(palette.textSecondary, size: 12),
              ),
            ),
          ],
        ),
      );
    }

    final details = <String>[
      ?info.uploader,
      if (info.isPlaylist) 'Playlist • ${info.entries.length} videos',
      if (info.duration case final duration?)
        formatDuration(duration.inSeconds),
      if (info.maxHeight case final height?) 'up to ${height}p',
      info.site,
    ];

    return _panel(
      palette,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  width: 112,
                  height: 63,
                  color: palette.surfaceHighest,
                  child: info.thumbnail == null
                      ? Icon(
                          Icons.smart_display_outlined,
                          color: palette.textMuted,
                        )
                      : Image.network(
                          info.thumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.smart_display_outlined,
                            color: palette.textMuted,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(
                        palette.textPrimary,
                        size: 13,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      details.join('  •  '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(palette.textMuted, size: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (info.isPlaylist && info.entries.isNotEmpty) ...[
            const SizedBox(height: 12),
            _optionRow(
              palette,
              'Download all ${info.entries.length} videos',
              'Each video becomes its own download in the queue',
              _wholePlaylist,
              (value) => setState(() => _wholePlaylist = value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _formatChips(ZonPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final format in MediaFormat.values)
          _FormatChip(
            format: format,
            selected: _format == format,
            enabled: !format.needsFfmpeg || _hasFfmpeg,
            onTap: () => setState(() => _format = format),
          ),
      ],
    );
  }

  Widget _panel(ZonPalette palette, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }

  Widget _locationField() {
    return Row(
      children: [
        Expanded(
          child: _textField(
            controller: _savePath,
            hint: '~/Downloads',
            icon: Icons.folder_outlined,
          ),
        ),
        const SizedBox(width: 6),
        MonoIconButton(
          icon: Icons.more_horiz_rounded,
          tooltip: 'Choose folder',
          size: 42,
          onTap: _browse,
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------

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

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.format,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final MediaFormat format;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = !enabled
        ? palette.textMuted.withValues(alpha: 0.5)
        : selected
        ? palette.onAccent
        : palette.textPrimary;
    final chip = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected && enabled ? palette.accent : palette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected && enabled ? palette.accent : palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                format.isAudio
                    ? Icons.music_note_rounded
                    : Icons.movie_outlined,
                size: 14,
                color: foreground,
              ),
              const SizedBox(width: 7),
              Text(
                format.label,
                style: AppType.body(
                  foreground,
                  size: 12.5,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                format.caption,
                style: AppType.body(
                  foreground.withValues(alpha: 0.6),
                  size: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (enabled) return chip;
    return Tooltip(message: 'Install ffmpeg to enable', child: chip);
  }
}
