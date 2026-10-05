import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_state.dart';
import 'platform/desktop_shell.dart';
import 'platform/local_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DesktopShell.ensureWindow();

  final state = await AppState.bootstrap();
  final shell = DesktopShell(state);
  final api = LocalApiServer(
    onAdd: (url, format) {
      state.addFromBrowser(url, format: format);
      unawaited(shell.show());
    },
  );

  void syncApi() {
    final wanted = state.settings.localApi;
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
}
