import 'media_format.dart';

/// All user configurable preferences, persisted by `LibraryStore`.
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
    this.watchClipboard = true,
    this.localApi = true,
    this.ytDlpPath = '',
    this.cookiesBrowser = 'None',
    this.defaultMediaFormat = MediaFormat.videoBest,
    this.audioQuality = '320K',
    this.embedMetadata = true,
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

  /// Offer links found on the clipboard when the window gains focus.
  final bool watchClipboard;

  /// Accept links from the bookmarklet / browser on 127.0.0.1.
  final bool localApi;

  /// Explicit yt-dlp binary; empty means auto-detect.
  final String ytDlpPath;

  /// Browser yt-dlp reads cookies from (for Instagram, private videos, ...).
  final String cookiesBrowser;
  final MediaFormat defaultMediaFormat;

  /// MP3 bitrate, one of [audioQualities].
  final String audioQuality;

  /// Embed title/artist tags and the thumbnail into media files.
  final bool embedMetadata;

  static const defaults = AppSettings();

  static const speedLimits = [
    'No Limit',
    '1 MB/s',
    '5 MB/s',
    '10 MB/s',
    '50 MB/s',
    '100 MB/s',
  ];

  static const cookieBrowsers = [
    'None',
    'Chrome',
    'Firefox',
    'Safari',
    'Edge',
    'Brave',
    'Chromium',
    'Opera',
    'Vivaldi',
  ];

  static const audioQualities = ['320K', '256K', '192K', '128K'];

  /// Converts a [speedLimits] label to bytes per second; null for no limit.
  static int? speedLimitBytes(String label) {
    final match = RegExp(r'^(\d+)\s*MB/s$').firstMatch(label.trim());
    if (match == null) return null;
    return int.parse(match.group(1)!) * 1024 * 1024;
  }

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
    bool? watchClipboard,
    bool? localApi,
    String? ytDlpPath,
    String? cookiesBrowser,
    MediaFormat? defaultMediaFormat,
    String? audioQuality,
    bool? embedMetadata,
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
      watchClipboard: watchClipboard ?? this.watchClipboard,
      localApi: localApi ?? this.localApi,
      ytDlpPath: ytDlpPath ?? this.ytDlpPath,
      cookiesBrowser: cookiesBrowser ?? this.cookiesBrowser,
      defaultMediaFormat: defaultMediaFormat ?? this.defaultMediaFormat,
      audioQuality: audioQuality ?? this.audioQuality,
      embedMetadata: embedMetadata ?? this.embedMetadata,
    );
  }

  Map<String, Object?> toJson() => {
    'defaultLocation': defaultLocation,
    'startOnStartup': startOnStartup,
    'minimizeToTray': minimizeToTray,
    'confirmBeforeRemoving': confirmBeforeRemoving,
    'maxSimultaneous': maxSimultaneous,
    'defaultConnections': defaultConnections,
    'defaultSpeedLimit': defaultSpeedLimit,
    'retryCount': retryCount,
    'retryDelay': retryDelay,
    'proxy': proxy,
    'userAgent': userAgent,
    'connectionTimeout': connectionTimeout,
    'requestTimeout': requestTimeout,
    'autoStart': autoStart,
    'autoResumeFailed': autoResumeFailed,
    'autoOpenCompleted': autoOpenCompleted,
    'theme': theme.name,
    'uiScale': uiScale,
    'notifyCompleted': notifyCompleted,
    'notifyFailed': notifyFailed,
    'notifyPaused': notifyPaused,
    'watchClipboard': watchClipboard,
    'localApi': localApi,
    'ytDlpPath': ytDlpPath,
    'cookiesBrowser': cookiesBrowser,
    'defaultMediaFormat': defaultMediaFormat.name,
    'audioQuality': audioQuality,
    'embedMetadata': embedMetadata,
  };

  static AppSettings fromJson(Map<String, Object?> json) {
    const d = AppSettings.defaults;
    T read<T>(String key, T fallback) {
      final value = json[key];
      if (value is T) return value;
      if (fallback is double && value is num) return value.toDouble() as T;
      if (fallback is int && value is num) return value.toInt() as T;
      return fallback;
    }

    return AppSettings(
      defaultLocation: read('defaultLocation', d.defaultLocation),
      startOnStartup: read('startOnStartup', d.startOnStartup),
      minimizeToTray: read('minimizeToTray', d.minimizeToTray),
      confirmBeforeRemoving: read(
        'confirmBeforeRemoving',
        d.confirmBeforeRemoving,
      ),
      maxSimultaneous: read('maxSimultaneous', d.maxSimultaneous),
      defaultConnections: read('defaultConnections', d.defaultConnections),
      defaultSpeedLimit: read('defaultSpeedLimit', d.defaultSpeedLimit),
      retryCount: read('retryCount', d.retryCount),
      retryDelay: read('retryDelay', d.retryDelay),
      proxy: read('proxy', d.proxy),
      userAgent: read('userAgent', d.userAgent),
      connectionTimeout: read('connectionTimeout', d.connectionTimeout),
      requestTimeout: read('requestTimeout', d.requestTimeout),
      autoStart: read('autoStart', d.autoStart),
      autoResumeFailed: read('autoResumeFailed', d.autoResumeFailed),
      autoOpenCompleted: read('autoOpenCompleted', d.autoOpenCompleted),
      theme: ThemePreference.values.firstWhere(
        (value) => value.name == json['theme'],
        orElse: () => d.theme,
      ),
      uiScale: read('uiScale', d.uiScale),
      notifyCompleted: read('notifyCompleted', d.notifyCompleted),
      notifyFailed: read('notifyFailed', d.notifyFailed),
      notifyPaused: read('notifyPaused', d.notifyPaused),
      watchClipboard: read('watchClipboard', d.watchClipboard),
      localApi: read('localApi', d.localApi),
      ytDlpPath: read('ytDlpPath', d.ytDlpPath),
      cookiesBrowser: read('cookiesBrowser', d.cookiesBrowser),
      defaultMediaFormat: MediaFormat.fromName(
        json['defaultMediaFormat'] as String?,
      ),
      audioQuality: read('audioQuality', d.audioQuality),
      embedMetadata: read('embedMetadata', d.embedMetadata),
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
