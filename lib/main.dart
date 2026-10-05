import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/app_state.dart';
import 'platform/desktop_shell.dart';
import 'platform/local_api.dart';

/// Links the OS passes on the command line: a clicked magnet (Windows,
/// Linux), "Open with ZON" on a .torrent, or a plain URL.
bool _isIncomingLink(String arg) {
  final lower = arg.toLowerCase();
  return lower.startsWith('magnet:?') ||
      lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      (lower.endsWith('.torrent') && File(arg).existsSync());
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // A second launch hands its links to the running ZON and quits.
  final incoming = args.where(_isIncomingLink).toList();
  if (incoming.isNotEmpty) {
    final token = await AppState.storedApiToken();
    if (token != null) {
      var forwarded = true;
      for (final link in incoming) {
        forwarded &= await LocalApiServer.forward(link, token: token);
      }
      if (forwarded) exit(0);
    }
  }

  await DesktopShell.ensureWindow();

  final state = await AppState.bootstrap();
  final shell = DesktopShell(state);
  final api = LocalApiServer(
    token: () => state.settings.apiToken,
    onAdd: (url, format) {
      unawaited(state.addFromBrowser(url, format: format));
      unawaited(shell.show());
    },
    onAddFile: (path) {
      unawaited(state.addIncoming(path));
      unawaited(shell.show());
    },
  );

  void syncApi() {
    // Needed for the bookmarklet, and for a second launch (magnet click on
    // Windows/Linux) to reach this instance.
    final wanted = state.settings.localApi || state.settings.magnetHandler;
    if (wanted && !api.running) {
      unawaited(api.start());
    } else if (!wanted && api.running) {
      unawaited(api.stop());
    }
  }

  state.addListener(syncApi);
  syncApi();

  runApp(ZonApp(state: state, nativeIntegration: true));
  state.startTicking();
  unawaited(shell.init());

  for (final link in incoming) {
    unawaited(state.addIncoming(link));
  }

  // macOS delivers magnet clicks as URL events (app_links) and opened
  // .torrent files through the AppDelegate's `zon/open_files` channel.
  if (Platform.isMacOS) {
    const files = MethodChannel('zon/open_files');
    files.setMethodCallHandler((call) async {
      if (call.method != 'open') return;
      for (final path in (call.arguments as List).cast<String>()) {
        unawaited(state.addIncoming(path));
      }
      unawaited(shell.show());
    });
    try {
      final queued = await files.invokeListMethod<String>('ready') ?? [];
      for (final path in queued) {
        unawaited(state.addIncoming(path));
      }
    } on MissingPluginException {
      // Older runner without the hook.
    }
    AppLinks().uriLinkStream.listen((uri) {
      final link = uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
      unawaited(state.addIncoming(link));
      unawaited(shell.show());
    });
  }
}
