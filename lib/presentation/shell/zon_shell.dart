import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/mono_button.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/zon_logo.dart';
import '../../data/app_state.dart';
import '../../domain/models/download.dart';
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
  const ZonShell({super.key, required this.state});

  final AppState state;

  @override
  State<ZonShell> createState() => _ZonShellState();
}

class _ZonShellState extends State<ZonShell> {
  Timer? _splashTimer;
  bool _splashVisible = true;
  bool _detailsDrawerOpen = false;
  bool _persistentPanel = true;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _splashVisible = false);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
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
        final text = data?.text?.trim();
        if (!mounted) return;
        final value = (text == null || text.isEmpty)
            ? 'https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-desktop-amd64.iso'
            : text;
        _openAddDialog(AddDownloadMode.single, value);
      case QuickAction.multiple:
        _openAddDialog(AddDownloadMode.multiple);
      case QuickAction.torrent:
        _openAddDialog(AddDownloadMode.torrent);
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
        state.showToast('Revealed ${item.fileName} in ${item.savePath}');
      case DownloadCardAction.copyUrl:
        Clipboard.setData(ClipboardData(text: item.url));
        state.showToast('Link copied to clipboard');
      case DownloadCardAction.details:
        state.select(item.id);
        if (!_persistentPanel) setState(() => _detailsDrawerOpen = true);
      case DownloadCardAction.redownload:
        state.createDownload(url: item.url, fileName: item.fileName);
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
                    '"${item.fileName}" will be removed from ZON. '
                    'The partially downloaded file stays on disk.',
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
                body: Stack(
                  children: [
                    body,
                    _Splash(visible: _splashVisible),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
