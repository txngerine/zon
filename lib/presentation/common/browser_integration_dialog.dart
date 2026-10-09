import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/widgets/mono_button.dart';
import '../../data/app_state.dart';
import '../../domain/models/media_format.dart';
import '../../platform/local_api.dart';
import 'dialogs.dart';

/// Sets up the "Send to ZON" browser extension, with bookmarklets as a
/// fallback.
class BrowserIntegrationDialog extends StatelessWidget {
  const BrowserIntegrationDialog({super.key, required this.state});

  final AppState state;

  static Future<void> show(BuildContext context, AppState state) {
    return showZonDialog<void>(
      context,
      builder: (_) => BrowserIntegrationDialog(state: state),
    );
  }

  void _copy(BuildContext context, String label, MediaFormat? format) {
    final code = LocalApiServer.bookmarklet(
      token: state.settings.apiToken,
      format: format,
    );
    Clipboard.setData(ClipboardData(text: code));
    // Don't offer our own bookmarklet back as a "copied link".
    state.markClipboardSeen(code);
    state.showToast('$label bookmarklet copied');
  }

  void _copyKey() {
    final key = state.settings.apiToken;
    Clipboard.setData(ClipboardData(text: key));
    state.markClipboardSeen(key);
    state.showToast('Pairing key copied');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = state.settings.localApi;

    Widget step(String number, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.borderStrong),
            ),
            child: Text(
              number,
              style: AppType.numeric(palette.textSecondary, size: 10.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppType.body(palette.textSecondary, size: 12.5),
            ),
          ),
        ],
      ),
    );

    return Dialog(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.extension_outlined,
                    size: 18,
                    color: palette.textPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Browser extension',
                      style: AppType.heading(palette.textPrimary, size: 17),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              step(
                '1',
                'Show the extension folder. Chrome, Edge or Brave: open '
                    'chrome://extensions, turn on Developer mode, click Load '
                    'unpacked and pick that folder. Firefox: about:debugging › '
                    'This Firefox › Load Temporary Add-on › manifest.json.',
              ),
              step(
                '2',
                'Copy the pairing key and paste it into the extension\'s '
                    'settings, which open on install.',
              ),
              step(
                '3',
                'Click the ZON toolbar button to send the page, or right-click '
                    'any link or video › Download with ZON.',
              ),
              if (!enabled)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 6),
                  child: Text(
                    'Turn on "Browser button" in Settings › Integrations first.',
                    style: AppType.body(
                      palette.textPrimary,
                      size: 12,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  MonoButton(
                    label: 'Show extension folder',
                    icon: Icons.folder_open_rounded,
                    variant: MonoButtonVariant.primary,
                    onTap: state.revealBrowserExtension,
                  ),
                  MonoButton(
                    label: 'Copy key',
                    icon: Icons.key_rounded,
                    onTap: _copyKey,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'No extension? Copy a bookmarklet and paste it as the URL of a '
                'new bookmark.',
                style: AppType.body(palette.textSecondary, size: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  MonoButton(
                    label: 'Send to ZON',
                    icon: Icons.bookmark_add_outlined,
                    onTap: () => _copy(context, 'Send to ZON', null),
                  ),
                  MonoButton(
                    label: 'ZON → MP3',
                    icon: Icons.music_note_rounded,
                    onTap: () =>
                        _copy(context, 'ZON → MP3', MediaFormat.audioMp3),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Links go to 127.0.0.1:${LocalApiServer.defaultPort} only — '
                'nothing leaves this computer. The key is private to this '
                'install, so other websites cannot add downloads.',
                style: AppType.body(palette.textMuted, size: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
