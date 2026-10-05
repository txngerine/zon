import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import '../data/app_state.dart';

/// Window lifecycle and the system-tray icon.
///
/// Closing the window hides ZON to the tray (when enabled) so downloads keep
/// running; "Quit" flushes the library and exits.
class DesktopShell with WindowListener {
  DesktopShell(this.state);

  final AppState state;

  // Native wrappers must stay referenced or the icon disappears.
  tray.TrayIcon? _icon;
  tray.Menu? _menu;
  tray.MenuItem? _statusItem;
  tray.MenuItem? _queueItem;
  bool _quitting = false;
  int _lastActive = -1;
  bool? _lastPaused;

  bool get hasTray => _icon != null;

  static Future<void> ensureWindow() async {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(minimumSize: Size(420, 560), title: 'ZON'),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  Future<void> init() async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    try {
      _createTray();
    } catch (_) {
      // No tray on this desktop (e.g. GNOME without an indicator extension).
      _icon = null;
    }
    state.addListener(_onState);
    _onState();
  }

  void _createTray() {
    final icon = tray.TrayIcon.create();
    if (icon == null) return;
    final image = tray.ImageAsset.fromAsset(
      Platform.isMacOS
          ? 'assets/tray/tray_icon.png'
          : 'assets/tray/tray_icon_color.png',
    );
    if (image == null) return;
    icon.icon = image;
    if (Platform.isMacOS) icon.isIconTemplate = true;
    icon.setTooltip('ZON');

    tray.MenuItem item(String label, void Function() onClick) {
      final entry = tray.MenuItem.createWithLabelAndType(
        label,
        tray.MenuItemType.normal,
      )!;
      entry.addListener((event) {
        if (event is tray.MenuItemClickedEvent) onClick();
      });
      return entry;
    }

    final menu = tray.Menu.create()!;
    _statusItem = item('No active downloads', () {})..isEnabled = false;
    _queueItem = item('Pause queue', state.toggleQueue);
    menu
      ..addItem(_statusItem)
      ..addSeparator()
      ..addItem(item('Show ZON', () => unawaited(show())))
      ..addItem(item('Pause all', state.pauseAll))
      ..addItem(item('Resume all', state.resumeAll))
      ..addItem(_queueItem)
      ..addSeparator()
      ..addItem(item('Quit ZON', () => unawaited(quit())));
    icon.setContextMenu(menu);

    if (Platform.isWindows) {
      // Windows convention: left click opens the app, right click the menu.
      icon.setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked);
      icon.addListener((event) {
        if (event is tray.TrayIconClickedEvent) unawaited(show());
      });
    } else {
      icon.setContextMenuTrigger(tray.ContextMenuTrigger.clicked);
    }
    icon.setVisible(true);
    _icon = icon;
    _menu = menu;
  }

  void _onState() {
    final active = state.activeCount;
    final paused = state.queuePaused;
    if (active == _lastActive && paused == _lastPaused) return;
    _lastActive = active;
    _lastPaused = paused;
    if (_icon == null) return;
    _statusItem?.label = active == 0
        ? 'No active downloads'
        : '$active downloading';
    _queueItem?.label = paused ? 'Resume queue' : 'Pause queue';
    if (Platform.isMacOS) _icon?.setTitle(active == 0 ? null : '$active');
  }

  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    state.removeListener(_onState);
    await state.shutdown();
    _icon?.dispose();
    _menu?.dispose();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (state.settings.minimizeToTray && hasTray) {
      unawaited(windowManager.hide());
    } else {
      unawaited(quit());
    }
  }
}
