import 'dart:io';

import 'package:flutter/services.dart';

import 'package:nativeapi/nativeapi.dart' show NotificationManager;

/// OS services `AppState` needs: notifications, revealing files and
/// launch-at-login. Tests use [DesktopBridge.noop].
abstract class DesktopBridge {
  const DesktopBridge();

  const factory DesktopBridge.noop() = _NoopBridge;

  Future<void> notify(String title, String body);

  /// Opens the file manager with [path] selected.
  Future<void> reveal(String path);

  /// Opens [path] with its default application.
  Future<void> open(String path);

  Future<void> setLaunchAtStartup(bool enabled);

  /// Makes ZON (or stops making it) the handler for magnet: links.
  Future<void> setMagnetHandler(bool enabled);
}

class _NoopBridge extends DesktopBridge {
  const _NoopBridge();

  @override
  Future<void> notify(String title, String body) async {}

  @override
  Future<void> reveal(String path) async {}

  @override
  Future<void> open(String path) async {}

  @override
  Future<void> setLaunchAtStartup(bool enabled) async {}

  @override
  Future<void> setMagnetHandler(bool enabled) async {}
}

/// The real implementation for macOS, Windows and Linux.
class SystemBridge extends DesktopBridge {
  SystemBridge();

  bool? _notifierReady;
  int _tag = 0;

  @override
  Future<void> notify(String title, String body) async {
    try {
      if (Platform.isMacOS) {
        // UserNotifications, implemented in the runner's AppDelegate.
        await const MethodChannel('zon/notify')
            .invokeMethod<void>('show', {'title': title, 'body': body});
      } else if (Platform.isLinux) {
        await Process.run('notify-send', ['--app-name=ZON', title, body]);
      } else {
        final manager = NotificationManager.instance;
        _notifierReady ??= manager.isSupported() && manager.initialize();
        if (_notifierReady != true) return;
        manager.show(title, body, 'zon-${_tag++}', '');
      }
    } catch (_) {
      // Notifications are best-effort.
    }
  }

  @override
  Future<void> reveal(String path) async {
    final exists = await FileSystemEntity.type(path);
    if (exists == FileSystemEntityType.notFound) {
      return open(File(path).parent.path);
    }
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', path]);
    } else {
      // Most Linux file managers cannot select a file; open its folder.
      final dir = exists == FileSystemEntityType.directory
          ? path
          : File(path).parent.path;
      await Process.run('xdg-open', [dir]);
    }
  }

  @override
  Future<void> open(String path) async {
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else {
      await Process.run('xdg-open', [path]);
    }
  }

  @override
  Future<void> setLaunchAtStartup(bool enabled) async {
    final exe = Platform.resolvedExecutable;
    try {
      if (Platform.isMacOS) {
        await _macLaunchAgent(enabled, exe);
      } else if (Platform.isWindows) {
        const key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
        await Process.run('reg', [
          if (enabled) ...[
            'add',
            key,
            '/v',
            'ZON',
            '/t',
            'REG_SZ',
            '/d',
            '"$exe"',
            '/f',
          ] else ...[
            'delete',
            key,
            '/v',
            'ZON',
            '/f',
          ],
        ]);
      } else {
        final home = Platform.environment['HOME'] ?? '';
        final file = File('$home/.config/autostart/zon.desktop');
        if (enabled) {
          await file.parent.create(recursive: true);
          await file.writeAsString(
            '[Desktop Entry]\nType=Application\nName=ZON\n'
            'Exec="$exe"\nX-GNOME-Autostart-enabled=true\n',
          );
        } else if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> setMagnetHandler(bool enabled) async {
    final exe = Platform.resolvedExecutable;
    try {
      if (Platform.isMacOS) {
        // Info.plist declares the scheme; this makes ZON the default.
        if (!enabled) return;
        await Process.run('osascript', [
          '-l',
          'JavaScript',
          '-e',
          'ObjC.import("CoreServices");'
              r'$.LSSetDefaultHandlerForURLScheme($("magnet"), $("dev.zon.zon"))',
        ]);
      } else if (Platform.isWindows) {
        const key = r'HKCU\Software\Classes\magnet';
        if (enabled) {
          for (final args in [
            ['add', key, '/ve', '/d', 'URL:Magnet Link', '/f'],
            ['add', key, '/v', 'URL Protocol', '/d', '', '/f'],
            [
              'add',
              '$key\\shell\\open\\command',
              '/ve',
              '/d',
              '"$exe" "%1"',
              '/f',
            ],
          ]) {
            await Process.run('reg', args);
          }
        } else {
          await Process.run('reg', ['delete', key, '/f']);
        }
      } else {
        final home = Platform.environment['HOME'] ?? '';
        final file = File('$home/.local/share/applications/zon-magnet.desktop');
        if (enabled) {
          await file.parent.create(recursive: true);
          await file.writeAsString(
            '[Desktop Entry]\nType=Application\nName=ZON\nExec="$exe" %u\n'
            'MimeType=x-scheme-handler/magnet;\nNoDisplay=true\n',
          );
          await Process.run('xdg-mime', [
            'default',
            'zon-magnet.desktop',
            'x-scheme-handler/magnet',
          ]);
        } else if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
  }

  Future<void> _macLaunchAgent(bool enabled, String exe) async {
    final home = Platform.environment['HOME'] ?? '';
    final file = File('$home/Library/LaunchAgents/com.zon.app.plist');
    if (!enabled) {
      if (await file.exists()) await file.delete();
      return;
    }
    // `.../ZON.app/Contents/MacOS/zon` -> `.../ZON.app`
    final marker = exe.indexOf('.app/');
    final bundle = marker > 0 ? exe.substring(0, marker + 4) : exe;
    await file.parent.create(recursive: true);
    await file.writeAsString('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.zon.app</string>
  <key>ProgramArguments</key>
  <array><string>/usr/bin/open</string><string>-g</string><string>$bundle</string></array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
''');
  }
}
