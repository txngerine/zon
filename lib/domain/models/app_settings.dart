/// All user configurable preferences.
///
/// Phase 6 will persist these to SQLite; for phase 1 they live in memory and
/// are mutated through `AppState`.
class AppSettings {
  const AppSettings({
    this.defaultLocation = '~/Downloads',
    this.startOnStartup = false,
    this.minimizeToTray = true,
    this.confirmBeforeRemoving = true,
    this.maxSimultaneous = 3,
    this.defaultConnections = 16,
    this.defaultSpeedLimit = 'No Limit',
    this.retryCount = 5,
    this.retryDelay = 3,
    this.proxy = '',
    this.userAgent = 'ZON/1.0',
    this.connectionTimeout = 30,
    this.requestTimeout = 60,
    this.autoStart = true,
    this.autoResumeFailed = true,
    this.autoOpenCompleted = false,
    this.theme = ThemePreference.dark,
    this.uiScale = 1.0,
    this.notifyCompleted = true,
    this.notifyFailed = true,
    this.notifyPaused = false,
  });

  final String defaultLocation;
  final bool startOnStartup;
  final bool minimizeToTray;
  final bool confirmBeforeRemoving;

  final int maxSimultaneous;
  final int defaultConnections;
  final String defaultSpeedLimit;
  final int retryCount;
  final int retryDelay;

  final String proxy;
  final String userAgent;
  final int connectionTimeout;
  final int requestTimeout;

  final bool autoStart;
  final bool autoResumeFailed;
  final bool autoOpenCompleted;

  final ThemePreference theme;
  final double uiScale;

  final bool notifyCompleted;
  final bool notifyFailed;
  final bool notifyPaused;

  static const defaults = AppSettings();

  static const speedLimits = [
    'No Limit',
    '1 MB/s',
    '5 MB/s',
    '10 MB/s',
    '50 MB/s',
    '100 MB/s',
  ];

  AppSettings copyWith({
    String? defaultLocation,
    bool? startOnStartup,
    bool? minimizeToTray,
    bool? confirmBeforeRemoving,
    int? maxSimultaneous,
    int? defaultConnections,
    String? defaultSpeedLimit,
    int? retryCount,
    int? retryDelay,
    String? proxy,
    String? userAgent,
    int? connectionTimeout,
    int? requestTimeout,
    bool? autoStart,
    bool? autoResumeFailed,
    bool? autoOpenCompleted,
    ThemePreference? theme,
    double? uiScale,
    bool? notifyCompleted,
    bool? notifyFailed,
    bool? notifyPaused,
  }) {
    return AppSettings(
      defaultLocation: defaultLocation ?? this.defaultLocation,
      startOnStartup: startOnStartup ?? this.startOnStartup,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      confirmBeforeRemoving:
          confirmBeforeRemoving ?? this.confirmBeforeRemoving,
      maxSimultaneous: maxSimultaneous ?? this.maxSimultaneous,
      defaultConnections: defaultConnections ?? this.defaultConnections,
      defaultSpeedLimit: defaultSpeedLimit ?? this.defaultSpeedLimit,
      retryCount: retryCount ?? this.retryCount,
      retryDelay: retryDelay ?? this.retryDelay,
      proxy: proxy ?? this.proxy,
      userAgent: userAgent ?? this.userAgent,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      autoStart: autoStart ?? this.autoStart,
      autoResumeFailed: autoResumeFailed ?? this.autoResumeFailed,
      autoOpenCompleted: autoOpenCompleted ?? this.autoOpenCompleted,
      theme: theme ?? this.theme,
      uiScale: uiScale ?? this.uiScale,
      notifyCompleted: notifyCompleted ?? this.notifyCompleted,
      notifyFailed: notifyFailed ?? this.notifyFailed,
      notifyPaused: notifyPaused ?? this.notifyPaused,
    );
  }
}

enum ThemePreference {
  dark,
  light,
  system;

  String get label => switch (this) {
    ThemePreference.dark => 'Dark',
    ThemePreference.light => 'Light',
    ThemePreference.system => 'System',
  };

  static ThemePreference fromLabel(String label) =>
      ThemePreference.values.firstWhere(
        (value) => value.label == label,
        orElse: () => ThemePreference.system,
      );
}
