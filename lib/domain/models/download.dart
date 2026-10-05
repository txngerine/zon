import 'media_format.dart';

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

/// Which engine transfers a download.
enum DownloadKind {
  /// Plain HTTP(S) file, transferred by the segmented HTTP engine.
  file,

  /// Video/audio page (YouTube, Reels, ...), transferred through yt-dlp.
  media,

  /// BitTorrent (magnet link or .torrent), transferred through aria2.
  torrent;

  static DownloadKind fromName(String? name) => DownloadKind.values.firstWhere(
    (value) => value.name == name,
    orElse: () => DownloadKind.file,
  );
}

/// Immutable snapshot of a single download.
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
    this.httpStatus = 0,
    this.server = '',
    this.contentType = 'application/octet-stream',
    this.resumeSupported = true,
    this.elapsedSeconds = 0,
    this.createdVia = 'Manual',
    this.kind = DownloadKind.file,
    this.mediaFormat,
    this.filePath,
    this.thumbnailUrl,
    this.speedLimit = 'No Limit',
    this.nameLocked = false,
    this.phase,
    this.seeders = 0,
    this.uploadSpeed = 0,
  });

  final String id;
  final String fileName;
  final String url;
  final String source;

  /// Total size in bytes; `0` while unknown.
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
  final DownloadKind kind;
  final MediaFormat? mediaFormat;

  /// Absolute path of the finished file, once known.
  final String? filePath;
  final String? thumbnailUrl;

  /// Per-download speed cap, one of `AppSettings.speedLimits`.
  final String speedLimit;

  /// True when the user picked the file name, so server metadata must not
  /// overwrite it.
  final bool nameLocked;

  /// Post-processing step shown while [status] is `verifying`
  /// (e.g. "Merging", "Converting to MP3").
  final String? phase;

  /// Torrent swarm stats (live only, not persisted). Peers use [connections].
  final int seeders;
  final double uploadSpeed;

  bool get isTorrent => kind == DownloadKind.torrent;

  bool get isMedia => kind == DownloadKind.media;

  double get progress =>
      sizeBytes <= 0 ? 0 : (downloadedBytes / sizeBytes).clamp(0.0, 1.0);

  int get remainingBytes =>
      sizeBytes <= 0 ? 0 : (sizeBytes - downloadedBytes).clamp(0, sizeBytes);

  /// Seconds left at the current transfer rate; `null` when unknown.
  int? get etaSeconds {
    if (status != DownloadStatus.downloading || speed <= 0) return null;
    if (sizeBytes <= 0) return null;
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
    MediaFormat? mediaFormat,
    String? filePath,
    String? thumbnailUrl,
    String? speedLimit,
    bool? nameLocked,
    String? phase,
    bool clearPhase = false,
    int? seeders,
    double? uploadSpeed,
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
      kind: kind,
      mediaFormat: mediaFormat ?? this.mediaFormat,
      filePath: filePath ?? this.filePath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      speedLimit: speedLimit ?? this.speedLimit,
      nameLocked: nameLocked ?? this.nameLocked,
      phase: clearPhase ? null : (phase ?? this.phase),
      seeders: seeders ?? this.seeders,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'fileName': fileName,
    'url': url,
    'source': source,
    'sizeBytes': sizeBytes,
    'downloadedBytes': downloadedBytes,
    'status': status.name,
    'connections': connections,
    'savePath': savePath,
    'priority': priority.name,
    'failureReason': failureReason,
    'httpStatus': httpStatus,
    'server': server,
    'contentType': contentType,
    'resumeSupported': resumeSupported,
    'addedAt': addedAt.toIso8601String(),
    'lastActivity': lastActivity.toIso8601String(),
    'elapsedSeconds': elapsedSeconds,
    'createdVia': createdVia,
    'kind': kind.name,
    'mediaFormat': mediaFormat?.name,
    'filePath': filePath,
    'thumbnailUrl': thumbnailUrl,
    'speedLimit': speedLimit,
    'nameLocked': nameLocked,
  };

  static DownloadItem fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    final format = json['mediaFormat'] as String?;
    return DownloadItem(
      id: json['id'] as String,
      fileName: json['fileName'] as String? ?? 'download',
      url: json['url'] as String? ?? '',
      source: json['source'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      status: DownloadStatus.fromName(json['status'] as String? ?? ''),
      connections: (json['connections'] as num?)?.toInt() ?? 8,
      savePath: json['savePath'] as String? ?? '',
      priority: DownloadPriority.fromName(json['priority'] as String? ?? ''),
      failureReason: json['failureReason'] as String?,
      httpStatus: (json['httpStatus'] as num?)?.toInt() ?? 0,
      server: json['server'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      resumeSupported: json['resumeSupported'] as bool? ?? true,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? now,
      lastActivity:
          DateTime.tryParse(json['lastActivity'] as String? ?? '') ?? now,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      createdVia: json['createdVia'] as String? ?? 'Manual',
      kind: DownloadKind.fromName(json['kind'] as String?),
      mediaFormat: format == null ? null : MediaFormat.fromName(format),
      filePath: json['filePath'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      speedLimit: json['speedLimit'] as String? ?? 'No Limit',
      nameLocked: json['nameLocked'] as bool? ?? false,
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
    this.savePath = '',
    this.filePath,
    this.kind = DownloadKind.file,
    this.mediaFormat,
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
  final String savePath;
  final String? filePath;
  final DownloadKind kind;
  final MediaFormat? mediaFormat;

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
      savePath: item.savePath,
      filePath: item.filePath,
      kind: item.kind,
      mediaFormat: item.mediaFormat,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'fileName': fileName,
    'url': url,
    'source': source,
    'status': status.name,
    'sizeBytes': sizeBytes,
    'downloadedBytes': downloadedBytes,
    'date': date.toIso8601String(),
    'durationSeconds': durationSeconds,
    'savePath': savePath,
    'filePath': filePath,
    'kind': kind.name,
    'mediaFormat': mediaFormat?.name,
  };

  static HistoryEntry fromJson(Map<String, Object?> json) {
    final format = json['mediaFormat'] as String?;
    return HistoryEntry(
      id: json['id'] as String,
      fileName: json['fileName'] as String? ?? 'download',
      url: json['url'] as String? ?? '',
      source: json['source'] as String? ?? '',
      status: DownloadStatus.fromName(json['status'] as String? ?? ''),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      savePath: json['savePath'] as String? ?? '',
      filePath: json['filePath'] as String?,
      kind: DownloadKind.fromName(json['kind'] as String?),
      mediaFormat: format == null ? null : MediaFormat.fromName(format),
    );
  }
}
