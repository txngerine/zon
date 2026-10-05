/// Lifecycle states a download can be in.
enum DownloadStatus {
  downloading,
  paused,
  queued,
  completed,
  failed,
  verifying,
  cancelled;

  static DownloadStatus fromName(String name) =>
      DownloadStatus.values.firstWhere(
        (value) => value.name == name,
        orElse: () => DownloadStatus.queued,
      );
}

/// Scheduling priority. Queued downloads are promoted in this order.
enum DownloadPriority {
  low,
  normal,
  high;

  String get label => switch (this) {
    DownloadPriority.low => 'Low',
    DownloadPriority.normal => 'Normal',
    DownloadPriority.high => 'High',
  };

  static DownloadPriority fromName(String name) =>
      DownloadPriority.values.firstWhere(
        (value) => value.name == name,
        orElse: () => DownloadPriority.normal,
      );
}

/// Immutable snapshot of a single download.
///
/// The real engine (Rust, phase 2+) will emit objects shaped exactly like
/// this, so the presentation layer never has to change.
class DownloadItem {
  const DownloadItem({
    required this.id,
    required this.fileName,
    required this.url,
    required this.source,
    required this.sizeBytes,
    required this.downloadedBytes,
    required this.status,
    required this.savePath,
    required this.addedAt,
    required this.lastActivity,
    required this.connections,
    this.speed = 0,
    this.baseSpeed = 0,
    this.priority = DownloadPriority.normal,
    this.failureReason,
    this.httpStatus = 200,
    this.server = 'cloudflare',
    this.contentType = 'application/octet-stream',
    this.resumeSupported = true,
    this.elapsedSeconds = 0,
    this.createdVia = 'Manual',
  });

  final String id;
  final String fileName;
  final String url;
  final String source;
  final int sizeBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final double speed;
  final double baseSpeed;
  final int connections;
  final String savePath;
  final DownloadPriority priority;
  final String? failureReason;
  final int httpStatus;
  final String server;
  final String contentType;
  final bool resumeSupported;
  final DateTime addedAt;
  final DateTime lastActivity;
  final int elapsedSeconds;
  final String createdVia;

  double get progress =>
      sizeBytes <= 0 ? 0 : (downloadedBytes / sizeBytes).clamp(0.0, 1.0);

  int get remainingBytes => (sizeBytes - downloadedBytes).clamp(0, sizeBytes);

  /// Seconds left at the current transfer rate; `null` when unknown.
  int? get etaSeconds {
    if (status != DownloadStatus.downloading || speed <= 0) return null;
    final seconds = remainingBytes / speed;
    if (seconds.isInfinite || seconds.isNaN) return null;
    return seconds.ceil();
  }

  String get host {
    final uri = Uri.tryParse(url);
    final value = uri?.host;
    if (value == null || value.isEmpty) return source;
    return value;
  }

  String get folder => savePath;

  bool get isActive => status == DownloadStatus.downloading;
  bool get canPause => status == DownloadStatus.downloading;
  bool get canResume =>
      status == DownloadStatus.paused || status == DownloadStatus.failed;
  bool get isTerminal =>
      status == DownloadStatus.completed || status == DownloadStatus.cancelled;

  DownloadItem copyWith({
    String? fileName,
    String? url,
    String? source,
    int? sizeBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    double? speed,
    double? baseSpeed,
    int? connections,
    String? savePath,
    DownloadPriority? priority,
    String? failureReason,
    bool clearFailure = false,
    int? httpStatus,
    String? server,
    String? contentType,
    bool? resumeSupported,
    DateTime? lastActivity,
    int? elapsedSeconds,
  }) {
    return DownloadItem(
      id: id,
      fileName: fileName ?? this.fileName,
      url: url ?? this.url,
      source: source ?? this.source,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      speed: speed ?? this.speed,
      baseSpeed: baseSpeed ?? this.baseSpeed,
      connections: connections ?? this.connections,
      savePath: savePath ?? this.savePath,
      priority: priority ?? this.priority,
      failureReason: clearFailure
          ? null
          : (failureReason ?? this.failureReason),
      httpStatus: httpStatus ?? this.httpStatus,
      server: server ?? this.server,
      contentType: contentType ?? this.contentType,
      resumeSupported: resumeSupported ?? this.resumeSupported,
      addedAt: addedAt,
      lastActivity: lastActivity ?? this.lastActivity,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      createdVia: createdVia,
    );
  }
}

/// A finished entry in the persistent history log.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.fileName,
    required this.url,
    required this.source,
    required this.status,
    required this.sizeBytes,
    required this.downloadedBytes,
    required this.date,
    required this.durationSeconds,
  });

  final String id;
  final String fileName;
  final String url;
  final String source;
  final DownloadStatus status;
  final int sizeBytes;
  final int downloadedBytes;
  final DateTime date;
  final int durationSeconds;

  static HistoryEntry fromDownload(
    DownloadItem item, {
    required int durationSeconds,
  }) {
    return HistoryEntry(
      id: item.id,
      fileName: item.fileName,
      url: item.url,
      source: item.source,
      status: item.status,
      sizeBytes: item.sizeBytes,
      downloadedBytes: item.downloadedBytes,
      date: DateTime.now(),
      durationSeconds: durationSeconds,
    );
  }
}
