import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nativeapi/nativeapi.dart'
    show DropRegion, DropRegionDropDetails;

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/zon_logo.dart';
import '../../data/app_state.dart';
import '../../domain/models/download.dart';
import '../../engine/media/media_sites.dart';
import '../../engine/torrent/torrent_engine.dart';
import '../../domain/models/ui_state.dart';
import '../common/dialogs.dart';
import '../common/toast_overlay.dart';
import '../dashboard/dashboard.dart';
import '../dashboard/download_card.dart';
import '../dashboard/url_input.dart';
import '../details/details_panel.dart';
import '../dialogs/add_download_dialog.dart';
import '../history/history_screen.dart';
import '../mobile/mobile_shell.dart';
import '../settings/settings_screen.dart';
import '../sidebar/sidebar.dart';
import 'status_bar.dart';

class _OpenAddIntent extends Intent {
  const _OpenAddIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

/// Root shell: responsive layout, navigation, details drawer, splash and
/// global shortcuts.
class ZonShell extends StatefulWidget {
  const ZonShell({super.key, required this.state, this.nativeDrop = false});

  final AppState state;

  /// Accept drag & drop through the native window (off in widget tests,
  /// which have no native window).
  final bool nativeDrop;

  @override
  State<ZonShell> createState() => _ZonShellState();
}

class _ZonShellState extends State<ZonShell> with WidgetsBindingObserver {
  Timer? _splashTimer;
  bool _splashVisible = true;
  bool _detailsDrawerOpen = false;
  bool _persistentPanel = true;
  bool _dragging = false;

  /// Link found on the clipboard, offered in a banner.
  String? _clipboardOffer;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _splashTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _splashVisible = false);
    });
    // Whatever is on the clipboard at launch is old news.
    unawaited(
      Clipboard.getData(Clipboard.kTextPlain)
          .then((data) => state.markClipboardSeen(data?.text))
          .catchError((_) {}),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) unawaited(_checkClipboard());
  }

  Future<void> _checkClipboard() async {
    if (!state.settings.watchClipboard) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final link = state.takeClipboardLink(data?.text);
      if (link != null && mounted) setState(() => _clipboardOffer = link);
    } catch (_) {}
  }

  void _acceptClipboardOffer() {
    final link = _clipboardOffer;
    setState(() => _clipboardOffer = null);
    if (link != null) _openAddDialog(AddDownloadMode.single, link);
  }

  /// Accepts links dragged from a browser, `.txt` link lists and browser
  /// shortcuts (`.webloc`, `.url`, `.desktop`).
  Future<void> _handleDrop(DropRegionDropDetails details) async {
    setState(() => _dragging = false);
    final links = <String>[...extractLinks(details.text ?? '')];
    var torrents = 0;
    for (final path in details.filePaths) {
      final lower = path.toLowerCase();
      if (lower.endsWith('.torrent')) {
        torrents++;
        unawaited(state.addTorrentFile(path));
        continue;
      }
      try {
        if (await File(path).length() > 4 * 1024 * 1024) continue;
        links.addAll(extractLinks(await File(path).readAsString()));
      } catch (_) {}
    }
    if (!mounted) return;
    if (links.isEmpty) {
      if (torrents == 0) state.showToast('No links found in the dropped files');
      return;
    }
    if (links.length == 1) {
      _openAddDialog(AddDownloadMode.single, links.first);
    } else {
      _openAddDialog(AddDownloadMode.multiple, links.toSet().join('\n'));
    }
  }

  // --------------------------------------------------------------------------
  // Actions
  // --------------------------------------------------------------------------

  void _openAddDialog(AddDownloadMode mode, [String url = '']) {
    AddDownloadDialog.show(context, state: state, mode: mode, initialUrl: url);
  }

  Future<void> _handleQuickAction(QuickAction action) async {
    switch (action) {
      case QuickAction.clipboard:
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text?.trim() ?? '';
        if (!mounted) return;
        state.markClipboardSeen(text);
        final links = extractLinks(text);
        if (links.length > 1) {
          _openAddDialog(AddDownloadMode.multiple, links.join('\n'));
        } else {
          _openAddDialog(
            AddDownloadMode.single,
            links.isEmpty ? '' : links.first,
          );
        }
      case QuickAction.multiple:
        _openAddDialog(AddDownloadMode.multiple);
      case QuickAction.media:
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text?.trim() ?? '';
        if (!mounted) return;
        state.markClipboardSeen(text);
        final links = extractLinks(text);
        _openAddDialog(
          AddDownloadMode.media,
          links.isNotEmpty && isMediaUrl(links.first) ? links.first : '',
        );
      case QuickAction.torrent:
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text?.trim() ?? '';
        if (!mounted) return;
        state.markClipboardSeen(text);
        final links = extractLinks(text).where(isTorrentLink).toList();
        _openAddDialog(
          AddDownloadMode.torrent,
          links.isEmpty ? '' : links.first,
        );
      case QuickAction.batch:
        _openAddDialog(AddDownloadMode.batch);
    }
  }

  void _handleCardTap(DownloadItem item) {
    state.select(item.id);
    if (!_persistentPanel && !_detailsDrawerOpen) {
      setState(() => _detailsDrawerOpen = true);
    }
  }

  void _handleCardAction(DownloadCardAction action, DownloadItem item) {
    switch (action) {
      case DownloadCardAction.pause:
        state.pauseDownload(item.id);
      case DownloadCardAction.resume:
        state.resumeDownload(item.id);
      case DownloadCardAction.cancel:
        state.cancelDownload(item.id);
      case DownloadCardAction.remove:
        _remove(item);
      case DownloadCardAction.openFolder:
        unawaited(state.revealDownload(item));
      case DownloadCardAction.openFile:
        unawaited(state.openDownload(item));
      case DownloadCardAction.copyUrl:
        Clipboard.setData(ClipboardData(text: item.url));
        state.showToast('Link copied to clipboard');
      case DownloadCardAction.details:
        state.select(item.id);
        if (!_persistentPanel) setState(() => _detailsDrawerOpen = true);
      case DownloadCardAction.redownload:
        state.createDownload(
          url: item.url,
          fileName: item.isMedia ? null : item.fileName,
          savePath: item.savePath,
          kind: item.kind,
          mediaFormat: item.mediaFormat,
        );
      case DownloadCardAction.priorityHigh:
        state.setPriority(item.id, DownloadPriority.high);
      case DownloadCardAction.priorityNormal:
        state.setPriority(item.id, DownloadPriority.normal);
      case DownloadCardAction.priorityLow:
        state.setPriority(item.id, DownloadPriority.low);
    }
  }

  Future<void> _remove(DownloadItem item) async {
    if (!state.settings.confirmBeforeRemoving) {
      state.removeDownload(item.id);
      return;
    }
    final confirmed = await _confirmRemove(item);
    if (confirmed == true) state.removeDownload(item.id);
  }

  Future<bool?> _confirmRemove(DownloadItem item) {
    return showZonDialog<bool>(
      context,
      builder: (context) {
        final palette = context.palette;
        return Dialog(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remove download?',
                    style: AppType.heading(
                      palette.textPrimary,
                      size: 17,
                      spacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.status == DownloadStatus.completed
                        ? '"${item.fileName}" will be removed from the list. '
                              'The file stays on disk.'
                        : '"${item.fileName}" will be removed from ZON and its '
                              'partially downloaded data deleted.',
                    style: AppType.body(palette.textSecondary, size: 13),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      MonoButton(
                        label: 'Cancel',
                        height: 38,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                      const SizedBox(width: 10),
                      MonoButton(
                        label: 'Remove',
                        variant: MonoButtonVariant.primary,
                        height: 38,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _closeDrawer() {
    if (!_detailsDrawerOpen) return;
    setState(() => _detailsDrawerOpen = false);
  }

  // --------------------------------------------------------------------------
  // Layout
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ToastOverlay(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final size = MediaQuery.sizeOf(context);
          final layout = ZonBreakpoints.layoutOf(size.width);
          _persistentPanel = layout == ZonLayout.desktop;

          final body = switch (layout) {
            ZonLayout.mobile => MobileShell(
              state: state,
              onAddDownload: (mode, url) => _openAddDialog(mode, url),
              onQuickAction: _handleQuickAction,
              onCardTap: _handleCardTap,
              onCardAction: _handleCardAction,
            ),
            _ => _desktopLayout(layout, palette),
          };

          return Actions(
            actions: {
              _OpenAddIntent: CallbackAction<_OpenAddIntent>(
                onInvoke: (_) {
                  _openAddDialog(AddDownloadMode.single);
                  return null;
                },
              ),
              _EscapeIntent: CallbackAction<_EscapeIntent>(
                onInvoke: (_) {
                  if (_detailsDrawerOpen) _closeDrawer();
                  return null;
                },
              ),
            },
            child: Shortcuts(
              shortcuts: {
                const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
                    const _OpenAddIntent(),
                const SingleActivator(LogicalKeyboardKey.keyN, control: true):
                    const _OpenAddIntent(),
                const SingleActivator(LogicalKeyboardKey.escape):
                    const _EscapeIntent(),
              },
              child: Scaffold(
                backgroundColor: palette.background,
                body: _dropZone(
                  Stack(
                    children: [
                      body,
                      if (_dragging) const _DropHint(),
                      if (_clipboardOffer case final link?)
                        Positioned(
                          right: 20,
                          bottom: 112,
                          child: _ClipboardBanner(
                            link: link,
                            onAccept: _acceptClipboardOffer,
                            onDismiss: () =>
                                setState(() => _clipboardOffer = null),
                          ),
                        ),
                      _Splash(visible: _splashVisible),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dropZone(Widget child) {
    if (!widget.nativeDrop) return child;
    return DropRegion(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: () => setState(() => _dragging = false),
      onDropped: (details) => unawaited(_handleDrop(details)),
      child: child,
    );
  }

  Widget _desktopLayout(ZonLayout layout, ZonPalette palette) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Sidebar(
                state: state,
                collapsed: layout == ZonLayout.compact,
                onAddDownload: () => _openAddDialog(AddDownloadMode.single),
              ),
              Expanded(child: _mainContent(palette)),
              if (layout == ZonLayout.desktop)
                DetailsPanel(state: state, onAction: _handleCardAction),
            ],
          ),
        ),
        StatusBar(state: state),
        if (layout == ZonLayout.compact) _detailsDrawer(palette),
      ],
    );
  }

  Widget _mainContent(ZonPalette palette) {
    return ColoredBox(
      color: palette.background,
      child: switch (state.section) {
        AppSection.history => HistoryScreen(state: state),
        AppSection.settings => SettingsScreen(state: state),
        _ => DashboardScreen(
          state: state,
          onAddDownload: (mode, url) => _openAddDialog(mode, url),
          onQuickAction: _handleQuickAction,
          onCardTap: _handleCardTap,
          onCardAction: _handleCardAction,
        ),
      },
    );
  }

  Widget _detailsDrawer(ZonPalette palette) {
    final item = state.selected;

    return Stack(
      children: [
        IgnorePointer(
          ignoring: !_detailsDrawerOpen,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _detailsDrawerOpen ? 1 : 0,
            child: GestureDetector(
              onTap: _closeDrawer,
              child: Container(color: palette.scrim),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IgnorePointer(
            ignoring: !_detailsDrawerOpen,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: _detailsDrawerOpen ? Offset.zero : const Offset(1, 0),
              child: Container(
                width: 380,
                decoration: BoxDecoration(
                  color: palette.backgroundRaised,
                  border: Border(left: BorderSide(color: palette.border)),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.5),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: item == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: EmptyState(
                            compact: true,
                            title: 'Nothing selected',
                            message: 'Pick a download to inspect its details.',
                          ),
                        ),
                      )
                    : DetailsView(
                        state: state,
                        item: item,
                        onAction: _handleCardAction,
                        onClose: _closeDrawer,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pulls every http(s) link out of free text, `.webloc` plists, `.url` and
/// `.desktop` shortcut files.
List<String> extractLinks(String text) {
  final matches = RegExp(r'''(https?://[^\s<>"']+|magnet:\?[^\s<>"']+)''')
      .allMatches(text);
  return [
    for (final match in matches)
      match.group(0)!.replaceFirst(RegExp(r'[),.;]+$'), ''),
  ];
}

/// Full-window hint while files are dragged over ZON.
class _DropHint extends StatelessWidget {
  const _DropHint();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IgnorePointer(
      child: Container(
        color: palette.scrim,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.borderStrong),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.file_download_outlined, color: palette.textPrimary),
              const SizedBox(height: 10),
              Text(
                'Drop links to download',
                style: AppType.heading(palette.textPrimary, size: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Links, magnets, .torrent files and link lists',
                style: AppType.body(palette.textMuted, size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Download the link you just copied?" prompt.
class _ClipboardBanner extends StatelessWidget {
  const _ClipboardBanner({
    required this.link,
    required this.onAccept,
    required this.onDismiss,
  });

  final String link;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final site = detectMediaSite(link);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 380,
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          color: palette.surfaceHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.borderStrong),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: 0.4),
              blurRadius: 24,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              site == null
                  ? Icons.content_paste_rounded
                  : Icons.smart_display_outlined,
              size: 18,
              color: palette.textPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    site == null ? 'Link copied' : '${site.name} link copied',
                    style: AppType.body(
                      palette.textPrimary,
                      size: 13,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(palette.textMuted, size: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            MonoButton(
              label: 'Download',
              variant: MonoButtonVariant.primary,
              height: 32,
              fontSize: 12,
              onTap: onAccept,
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: Icon(
                Icons.close_rounded,
                size: 16,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Launch moment: brand mark, wordmark and a thin progress line.
class _Splash extends StatelessWidget {
  const _Splash({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        opacity: visible ? 1 : 0,
        child: Container(
          color: palette.background,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.85, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: ZonLogo(size: 92),
              ),
              const SizedBox(height: 26),
              Text(
                'ZON',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'THE DOWNLOAD MANAGER',
                style: AppType.eyebrow(
                  palette.textMuted,
                  size: 9.5,
                  spacing: 3.4,
                ),
              ),
              const SizedBox(height: 34),
              SizedBox(
                width: 180,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeInOut,
                  builder: (context, value, _) =>
                      ZonProgressBar(value: value, height: 3, active: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
