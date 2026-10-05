import '../domain/models/download.dart';

/// Network/runtime options a transfer needs from `AppSettings`.
class TransferOptions {
  const TransferOptions({
    this.userAgent = 'ZON/1.0',
    this.proxy = '',
    this.connectionTimeout = const Duration(seconds: 30),
    this.requestTimeout = const Duration(seconds: 60),
    this.retryCount = 5,
    this.retryDelay = const Duration(seconds: 3),
    this.speedLimit,
    this.cookiesBrowser = 'None',
    this.audioQuality = '320K',
    this.embedMetadata = true,
  });

  final String userAgent;
  final String proxy;
  final Duration connectionTimeout;
  final Duration requestTimeout;
  final int retryCount;
  final Duration retryDelay;

  /// Per-download cap in bytes per second; null for unlimited.
  final int? speedLimit;
  final String cookiesBrowser;
  final String audioQuality;
  final bool embedMetadata;
}

/// Facts a transfer learns about its download while running.
class TransferMeta {
  const TransferMeta({
    this.fileName,
    this.sizeBytes,
    this.resumeSupported,
    this.contentType,
    this.server,
    this.httpStatus,
    this.thumbnailUrl,
    this.connections,
  });

  final String? fileName;
  final int? sizeBytes;
  final bool? resumeSupported;
  final String? contentType;
  final String? server;
  final int? httpStatus;
  final String? thumbnailUrl;
  final int? connections;
}

/// Callbacks a running transfer reports through. `AppState` implements this.
abstract class TransferListener {
  void onMeta(String id, TransferMeta meta);

  /// Bytes on disk so far, the current rate, and the total when known.
  void onProgress(String id, int downloaded, double speed, {int? total});

  /// A post-processing step (merging streams, converting to MP3, ...).
  void onPhase(String id, String phase);
  void onCompleted(String id, String filePath);
  void onFailed(String id, String reason);
}

/// A transfer backend. Implementations are fire-and-forget: `start` returns
/// once work is scheduled and everything after that arrives through the
/// [TransferListener].
abstract class TransferEngine {
  set listener(TransferListener listener);

  /// Starts or resumes [item] from whatever is already on disk.
  void start(DownloadItem item, TransferOptions options);

  /// Stops [id] but keeps partial data so it can resume.
  Future<void> pause(String id);

  /// Stops [id] and discards partial data.
  Future<void> cancel(String id);

  bool isRunning(String id);

  /// Changes the cap of a running transfer.
  void setSpeedLimit(String id, int? bytesPerSecond);

  Future<void> dispose();
}

/// Expands a leading `~` to the user's home directory.
String expandHome(String path, {Map<String, String>? environment}) {
  if (!path.startsWith('~')) return path;
  final env = environment ?? const {};
  final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
  if (home.isEmpty) return path;
  return home + path.substring(1);
}
