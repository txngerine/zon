import 'package:flutter/material.dart';

import '../../core/theme/zon_palette.dart';
import '../../data/app_state.dart';
import '../../domain/models/download.dart';
import '../dialogs/add_download_dialog.dart';
import 'download_card.dart';
import 'download_list.dart';
import 'speed_panel.dart';
import 'url_input.dart';

/// Main dashboard: hero, URL entry, transfer analytics and the download list.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.state,
    required this.onAddDownload,
    required this.onQuickAction,
    required this.onCardTap,
    required this.onCardAction,
  });

  final AppState state;
  final void Function(AddDownloadMode mode, String url) onAddDownload;
  final void Function(QuickAction action) onQuickAction;
  final void Function(DownloadItem item) onCardTap;
  final void Function(DownloadCardAction action, DownloadItem item)
  onCardAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 780;
        final horizontal = narrow ? 20.0 : 34.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 32, horizontal, 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrlInputBar(
                  compact: narrow,
                  onDownload: (url) =>
                      onAddDownload(AddDownloadMode.single, url),
                  onQuickAction: onQuickAction,
                ),
                const SizedBox(height: 26),
                SpeedPanel(state: state),
                const SizedBox(height: 30),
                DownloadListSection(
                  state: state,
                  onCardTap: onCardTap,
                  onCardAction: onCardAction,
                  onAddDownload: () =>
                      onAddDownload(AddDownloadMode.single, ''),
                ),
                const SizedBox(height: 8),
                if (state.visibleDownloads.isNotEmpty)
                  Center(
                    child: Text(
                      '${state.activeCount} transferring  •  '
                      '${state.queuedCount} waiting  •  '
                      '${pausedLabel(state)}',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 11.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String pausedLabel(AppState state) {
    final count = state.pausedCount;
    if (count == 0) return 'nothing paused';
    return '$count paused';
  }
}
