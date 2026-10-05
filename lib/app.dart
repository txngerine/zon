import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/app_state.dart';
import 'domain/models/app_settings.dart';
import 'presentation/shell/zon_shell.dart';

/// Root widget: theming, text scaling and the shell.
class ZonApp extends StatefulWidget {
  const ZonApp({super.key, required this.state});

  final AppState state;

  @override
  State<ZonApp> createState() => _ZonAppState();
}

class _ZonAppState extends State<ZonApp> {
  late ThemePreference _theme = widget.state.settings.theme;
  late double _scale = widget.state.settings.uiScale;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    final settings = widget.state.settings;
    if (settings.theme == _theme && settings.uiScale == _scale) return;
    setState(() {
      _theme = settings.theme;
      _scale = settings.uiScale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZON Download Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (_theme) {
        ThemePreference.dark => ThemeMode.dark,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.system => ThemeMode.system,
      },
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(_scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: ZonShell(state: widget.state),
    );
  }
}
