import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/widgets/filter_tabs.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/mono_dropdown.dart';
import '../../core/widgets/mono_switch.dart';
import '../../data/app_state.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/media_format.dart';
import '../../engine/media/ytdlp.dart';
import '../common/browser_integration_dialog.dart';

/// Complete settings screen organised in the sections defined by the product
/// specification.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  AppSettings get _settings => state.settings;

  void _update(AppSettings next) => state.updateSettings(next);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(34, 32, 34, 44),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings',
                          style: AppType.heading(
                            palette.textPrimary,
                            size: 26,
                            spacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Everything ZON does, exactly how you want it.',
                          style: AppType.body(
                            palette.textSecondary,
                            size: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  MonoButton(
                    label: 'Reset all settings',
                    icon: Icons.restart_alt_rounded,
                    onTap: state.resetSettings,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _section(context, 'GENERAL', [
                _row(
                  context,
                  'Default download location',
                  'New downloads are saved here',
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: _InlineField(
                          width: 220,
                          icon: Icons.folder_outlined,
                          hint: '~/Downloads',
                          value: _settings.defaultLocation,
                          onChanged: (value) => _update(
                            _settings.copyWith(defaultLocation: value),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      MonoButton(
                        label: 'Browse',
                        height: 36,
                        onTap: () async {
                          final dir = await getDirectoryPath(
                            initialDirectory: _settings.defaultLocation,
                          );
                          if (dir != null) {
                            _update(_settings.copyWith(defaultLocation: dir));
                          }
                        },
                      ),
                    ],
                  ),
                ),
                _switchRow(
                  context,
                  'Start on system startup',
                  'Launch ZON when you sign in',
                  _settings.startOnStartup,
                  (value) => _update(_settings.copyWith(startOnStartup: value)),
                ),
                _switchRow(
                  context,
                  'Minimize to tray',
                  'Keep transfers running in the background',
                  _settings.minimizeToTray,
                  (value) => _update(_settings.copyWith(minimizeToTray: value)),
                ),
                _switchRow(
                  context,
                  'Confirm before removing',
                  'Ask before deleting a download',
                  _settings.confirmBeforeRemoving,
                  (value) =>
                      _update(_settings.copyWith(confirmBeforeRemoving: value)),
                ),
              ]),
              _section(context, 'DOWNLOADS', [
                _row(
                  context,
                  'Maximum simultaneous downloads',
                  'Everything else waits in the queue',
                  _stepper(
                    context,
                    value: _settings.maxSimultaneous,
                    min: 1,
                    max: 8,
                    onChanged: (value) =>
                        _update(_settings.copyWith(maxSimultaneous: value)),
                  ),
                ),
                _row(
                  context,
                  'Default connections per download',
                  'Parallel chunks used for new transfers',
                  _stepper(
                    context,
                    value: _settings.defaultConnections,
                    min: 1,
                    max: 32,
                    onChanged: (value) =>
                        _update(_settings.copyWith(defaultConnections: value)),
                  ),
                ),
                _row(
                  context,
                  'Default speed limit',
                  'Applied to every new download',
                  MonoDropdown<String>(
                    value: _settings.defaultSpeedLimit,
                    options: [
                      for (final limit in AppSettings.speedLimits)
                        MonoOption(limit, limit),
                    ],
                    onChanged: (value) =>
                        _update(_settings.copyWith(defaultSpeedLimit: value)),
                    height: 34,
                    width: 160,
                  ),
                ),
                _row(
                  context,
                  'Retry count',
                  'Attempts before a download is marked failed',
                  _stepper(
                    context,
                    value: _settings.retryCount,
                    min: 0,
                    max: 10,
                    onChanged: (value) =>
                        _update(_settings.copyWith(retryCount: value)),
                  ),
                ),
                _row(
                  context,
                  'Retry delay',
                  'Wait between attempts',
                  _stepper(
                    context,
                    value: _settings.retryDelay,
                    min: 1,
                    max: 60,
                    suffix: 's',
                    onChanged: (value) =>
                        _update(_settings.copyWith(retryDelay: value)),
                  ),
                ),
              ]),
              _MediaSection(state: state, section: _section, row: _row),
              _section(context, 'TORRENTS', [
                _row(
                  context,
                  'aria2',
                  state.installProgress != null &&
                          !(state.mediaTools?.hasAria2 ?? false)
                      ? '${state.installStage ?? 'Downloading aria2'}… '
                            '${(state.installProgress! * 100).round()}%'
                      : state.mediaTools?.hasAria2 ?? false
                      ? 'Found • ${state.mediaTools!.aria2Path}'
                      : 'Not found — needed for torrents and magnet links. '
                            'Install with: ${MediaTools.aria2InstallCommand}',
                  state.mediaTools?.hasAria2 ?? false
                      ? Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: palette.textPrimary,
                        )
                      : MonoButton(
                          label: MediaTools.canInstallAria2
                              ? 'Install'
                              : 'Re-scan',
                          icon: MediaTools.canInstallAria2
                              ? Icons.download_rounded
                              : Icons.refresh_rounded,
                          onTap: state.mediaToolsBusy
                              ? null
                              : () => unawaited(
                                  MediaTools.canInstallAria2
                                      ? state.installAria2()
                                      : state.refreshMediaTools(),
                                ),
                        ),
                ),
                _switchRow(
                  context,
                  'Seed after downloading',
                  'Keep sharing finished torrents while ZON is open',
                  _settings.seedAfterDownload,
                  (value) =>
                      _update(_settings.copyWith(seedAfterDownload: value)),
                ),
                _switchRow(
                  context,
                  'Open magnet links with ZON',
                  'Clicking a magnet link in your browser adds it here',
                  _settings.magnetHandler,
                  (value) => _update(_settings.copyWith(magnetHandler: value)),
                ),
                _row(
                  context,
                  'Seed ratio',
                  'Stop sharing once this much has been uploaded',
                  MonoDropdown<String>(
                    value: _settings.seedRatio,
                    options: [
                      for (final ratio in AppSettings.seedRatios)
                        MonoOption(ratio, '$ratio×'),
                    ],
                    onChanged: (value) =>
                        _update(_settings.copyWith(seedRatio: value)),
                    height: 34,
                    width: 180,
                  ),
                ),
              ]),
              _section(context, 'INTEGRATIONS', [
                _switchRow(
                  context,
                  'Watch clipboard',
                  'Offer to download links you copy elsewhere',
                  _settings.watchClipboard,
                  (value) => _update(_settings.copyWith(watchClipboard: value)),
                ),
                _switchRow(
                  context,
                  'Browser button',
                  'Accept links from the ZON bookmarklet on 127.0.0.1',
                  _settings.localApi,
                  (value) => _update(_settings.copyWith(localApi: value)),
                ),
                _row(
                  context,
                  'Bookmarklet',
                  'One click sends the page you are on — YouTube, Reels, files',
                  MonoButton(
                    label: 'Set up',
                    icon: Icons.bookmark_add_outlined,
                    onTap: () => BrowserIntegrationDialog.show(context, state),
                  ),
                ),
              ]),
              _section(context, 'NETWORK', [
                _row(
                  context,
                  'Proxy',
                  'Leave empty to connect directly',
                  _InlineField(
                    width: 260,
                    icon: Icons.wifi_tethering_rounded,
                    hint: '127.0.0.1:8080',
                    value: _settings.proxy,
                    onChanged: (value) =>
                        _update(_settings.copyWith(proxy: value)),
                  ),
                ),
                _row(
                  context,
                  'User agent',
                  'Sent with every HTTP request',
                  _InlineField(
                    width: 260,
                    icon: Icons.fingerprint_rounded,
                    hint: 'ZON/1.0',
                    value: _settings.userAgent,
                    onChanged: (value) =>
                        _update(_settings.copyWith(userAgent: value)),
                  ),
                ),
                _row(
                  context,
                  'Connection timeout',
                  'Seconds before a connection is dropped',
                  _stepper(
                    context,
                    value: _settings.connectionTimeout,
                    min: 5,
                    max: 120,
                    suffix: 's',
                    onChanged: (value) =>
                        _update(_settings.copyWith(connectionTimeout: value)),
                  ),
                ),
                _row(
                  context,
                  'Request timeout',
                  'Seconds before a stalled request is retried',
                  _stepper(
                    context,
                    value: _settings.requestTimeout,
                    min: 10,
                    max: 600,
                    suffix: 's',
                    onChanged: (value) =>
                        _update(_settings.copyWith(requestTimeout: value)),
                  ),
                ),
              ]),
              _section(context, 'BEHAVIOR', [
                _switchRow(
                  context,
                  'Auto-start downloads',
                  'Begin transfers as soon as they are added',
                  _settings.autoStart,
                  (value) => _update(_settings.copyWith(autoStart: value)),
                ),
                _switchRow(
                  context,
                  'Auto-resume failed downloads',
                  'Retry interrupted transfers automatically',
                  _settings.autoResumeFailed,
                  (value) =>
                      _update(_settings.copyWith(autoResumeFailed: value)),
                ),
                _switchRow(
                  context,
                  'Automatically open completed files',
                  'Reveal finished files in the file manager',
                  _settings.autoOpenCompleted,
                  (value) =>
                      _update(_settings.copyWith(autoOpenCompleted: value)),
                ),
              ]),
              _section(context, 'APPEARANCE', [
                _row(
                  context,
                  'Theme',
                  'ZON is built monochrome — pick your side of the light',
                  FilterTabs<ThemePreference>(
                    values: ThemePreference.values,
                    selected: _settings.theme,
                    labelOf: (theme) => theme.label,
                    onSelected: (theme) =>
                        _update(_settings.copyWith(theme: theme)),
                  ),
                ),
                _row(
                  context,
                  'UI scale',
                  'Adjust text and control sizing',
                  _slider(
                    context,
                    value: _settings.uiScale,
                    min: 0.9,
                    max: 1.3,
                    divisions: 4,
                    label: '${(_settings.uiScale * 100).round()}%',
                    onChanged: (value) =>
                        _update(_settings.copyWith(uiScale: value)),
                  ),
                ),
              ]),
              _section(context, 'NOTIFICATIONS', [
                _switchRow(
                  context,
                  'Download completed',
                  'Notify when a transfer finishes',
                  _settings.notifyCompleted,
                  (value) =>
                      _update(_settings.copyWith(notifyCompleted: value)),
                ),
                _switchRow(
                  context,
                  'Download failed',
                  'Notify when a transfer cannot continue',
                  _settings.notifyFailed,
                  (value) => _update(_settings.copyWith(notifyFailed: value)),
                ),
                _switchRow(
                  context,
                  'Download paused',
                  'Notify when a transfer is suspended',
                  _settings.notifyPaused,
                  (value) => _update(_settings.copyWith(notifyPaused: value)),
                ),
              ]),
              _section(context, 'ADVANCED', [
                _row(
                  context,
                  'Data folder',
                  '${state.downloads.length} downloads and '
                      '${state.history.length} history entries in library.json',
                  MonoButton(
                    label: 'Open folder',
                    icon: Icons.storage_rounded,
                    onTap: state.dataDir.isEmpty
                        ? null
                        : () => unawaited(state.openPath(state.dataDir)),
                  ),
                ),
                _row(
                  context,
                  'Media cache',
                  'yt-dlp extractor cache — clear it if a site suddenly fails',
                  MonoButton(
                    label: 'Clear cache',
                    icon: Icons.cleaning_services_rounded,
                    onTap: state.mediaTools?.hasYtDlp ?? false
                        ? () => unawaited(state.clearMediaCache())
                        : null,
                  ),
                ),
                _row(
                  context,
                  'Completed downloads',
                  'Remove finished items from the list (files stay on disk)',
                  MonoButton(
                    label: 'Clear completed',
                    icon: Icons.playlist_remove_rounded,
                    onTap: state.clearCompleted,
                  ),
                ),
                _row(
                  context,
                  'Reset settings',
                  'Restore every preference to its default',
                  MonoButton(
                    label: 'Reset to defaults',
                    icon: Icons.restart_alt_rounded,
                    onTap: state.resetSettings,
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'ZON 1.0.0  •  HTTP ENGINE READY  •  '
                  '${state.mediaTools?.version == null ? 'YT-DLP NOT INSTALLED' : 'YT-DLP ${state.mediaTools!.version}'}',
                  style: AppType.eyebrow(
                    palette.textMuted,
                    size: 8.5,
                    spacing: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Building blocks
  // --------------------------------------------------------------------------

  Widget _section(BuildContext context, String title, List<Widget> rows) {
    final palette = context.palette;
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) children.add(Container(height: 1, color: palette.border));
      children.add(rows[i]);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.eyebrow(palette.textMuted, size: 9.5)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String title,
    String subtitle,
    Widget control,
  ) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 520) {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppType.body(
                          palette.textPrimary,
                          size: 13.5,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppType.body(palette.textMuted, size: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                control,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppType.body(
                  palette.textPrimary,
                  size: 13.5,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppType.body(palette.textMuted, size: 11.5),
              ),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: control),
            ],
          );
        },
      ),
    );
  }

  Widget _switchRow(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return _row(
      context,
      title,
      subtitle,
      MonoSwitch(value: value, onChanged: onChanged),
    );
  }

  Widget _stepper(
    BuildContext context, {
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    String suffix = '',
  }) {
    final palette = context.palette;

    Widget button(IconData icon, VoidCallback? onTap) {
      return _StepButton(icon: icon, onTap: onTap);
    }

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: palette.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            Icons.remove_rounded,
            value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 58,
            child: Text(
              '$value$suffix',
              textAlign: TextAlign.center,
              style: AppType.numeric(
                palette.textPrimary,
                size: 12.5,
                weight: FontWeight.w600,
              ),
            ),
          ),
          button(
            Icons.add_rounded,
            value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _slider(
    BuildContext context, {
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    final palette = context.palette;
    return SizedBox(
      width: 260,
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 46,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: AppType.numeric(
                palette.textPrimary,
                size: 12.5,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small +/- control used by numeric settings.
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: enabled ? palette.surfaceHighest : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled ? palette.border : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            size: 15,
            color: enabled ? palette.textPrimary : palette.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Single-line settings input with its own controller lifecycle.
class _InlineField extends StatefulWidget {
  const _InlineField({
    required this.value,
    required this.icon,
    required this.hint,
    required this.onChanged,
    this.width,
  });

  final String value;
  final IconData icon;
  final String hint;
  final ValueChanged<String> onChanged;
  final double? width;

  @override
  State<_InlineField> createState() => _InlineFieldState();
}

class _InlineFieldState extends State<_InlineField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_InlineField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: widget.width,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: palette.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 15, color: palette.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              style: AppType.body(palette.textPrimary, size: 12.5),
              cursorColor: palette.textPrimary,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppType.body(palette.textMuted, size: 12.5),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// yt-dlp / ffmpeg status and media download preferences.
class _MediaSection extends StatelessWidget {
  const _MediaSection({
    required this.state,
    required this.section,
    required this.row,
  });

  final AppState state;
  final Widget Function(BuildContext, String, List<Widget>) section;
  final Widget Function(BuildContext, String, String, Widget) row;

  AppSettings get _settings => state.settings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tools = state.mediaTools;
    final hasYtDlp = tools?.hasYtDlp ?? false;
    final hasFfmpeg = tools?.hasFfmpeg ?? false;
    final busy = state.mediaToolsBusy;
    final install = state.installProgress;

    final String ytDlpStatus;
    if (install != null) {
      final stage = state.installStage ?? 'Downloading yt-dlp';
      ytDlpStatus = '$stage… ${(install * 100).round()}%';
    } else if (tools == null || !tools.resolved) {
      ytDlpStatus = 'Checking…';
    } else if (hasYtDlp) {
      ytDlpStatus = 'Version ${tools.version} • ${tools.ytDlpPath}';
    } else {
      ytDlpStatus =
          'Not installed — needed for YouTube, Reels, TikTok and 1000+ sites';
    }

    final installCommand = Platform.isMacOS
        ? 'brew install ffmpeg'
        : Platform.isWindows
        ? 'winget install ffmpeg'
        : 'sudo apt install ffmpeg';

    final String ffmpegStatus;
    if (hasFfmpeg) {
      ffmpegStatus = 'Found • ${tools!.ffmpegPath}';
    } else if (install != null) {
      final stage = state.installStage ?? 'Setting up bundled tools';
      ffmpegStatus = '$stage… ${(install * 100).round()}%';
    } else {
      ffmpegStatus =
          'Not found — required for MP3 and HD video. '
          'Install with: $installCommand';
    }

    return section(context, 'MEDIA', [
      row(
        context,
        'yt-dlp',
        ytDlpStatus,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasYtDlp)
              MonoButton(
                label: 'Install',
                icon: Icons.download_rounded,
                variant: MonoButtonVariant.primary,
                onTap: busy || tools == null
                    ? null
                    : () => unawaited(state.installYtDlp()),
              )
            else if (tools!.isManaged)
              MonoButton(
                label: 'Update',
                icon: Icons.system_update_alt_rounded,
                onTap: busy ? null : () => unawaited(state.updateYtDlp()),
              ),
            const SizedBox(width: 8),
            MonoIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Re-scan',
              onTap: busy ? null : () => unawaited(state.refreshMediaTools()),
            ),
          ],
        ),
      ),
      row(
        context,
        'ffmpeg',
        ffmpegStatus,
        Icon(
          hasFfmpeg ? Icons.check_circle_outline_rounded : Icons.info_outline,
          size: 18,
          color: hasFfmpeg ? palette.textPrimary : palette.textMuted,
        ),
      ),
      row(
        context,
        'Custom yt-dlp path',
        'Leave empty to auto-detect',
        _InlineField(
          width: 260,
          icon: Icons.terminal_rounded,
          hint: '/usr/local/bin/yt-dlp',
          value: _settings.ytDlpPath,
          onChanged: (value) =>
              state.updateSettings(_settings.copyWith(ytDlpPath: value)),
        ),
      ),
      row(
        context,
        'Default format',
        'Used for links added without picking one',
        MonoDropdown<MediaFormat>(
          value: _settings.defaultMediaFormat,
          options: [
            for (final format in MediaFormat.values)
              MonoOption(format, '${format.label} · ${format.caption}'),
          ],
          onChanged: (value) => state.updateSettings(
            _settings.copyWith(defaultMediaFormat: value),
          ),
          height: 34,
          width: 180,
        ),
      ),
      row(
        context,
        'MP3 quality',
        'Bitrate for audio conversions',
        MonoDropdown<String>(
          value: _settings.audioQuality,
          options: [
            for (final quality in AppSettings.audioQualities)
              MonoOption(quality, '${quality.replaceAll('K', '')} kbps'),
          ],
          onChanged: (value) =>
              state.updateSettings(_settings.copyWith(audioQuality: value)),
          height: 34,
          width: 180,
        ),
      ),
      row(
        context,
        'Browser cookies',
        'Use your logged-in session for Instagram, private and age-gated videos',
        MonoDropdown<String>(
          value: _settings.cookiesBrowser,
          options: [
            for (final browser in AppSettings.cookieBrowsers)
              MonoOption(browser, browser),
          ],
          onChanged: (value) =>
              state.updateSettings(_settings.copyWith(cookiesBrowser: value)),
          height: 34,
          width: 180,
        ),
      ),
      row(
        context,
        'Embed metadata',
        'Write title, artist and cover art into the file',
        MonoSwitch(
          value: _settings.embedMetadata,
          onChanged: (value) =>
              state.updateSettings(_settings.copyWith(embedMetadata: value)),
        ),
      ),
    ]);
  }
}
