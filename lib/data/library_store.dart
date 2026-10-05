import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/models/app_settings.dart';
import '../domain/models/download.dart';

/// Everything ZON remembers between launches.
class LibrarySnapshot {
  const LibrarySnapshot({
    required this.downloads,
    required this.history,
    required this.settings,
    required this.queueOrder,
    this.queuePaused = false,
  });

  final List<DownloadItem> downloads;
  final List<HistoryEntry> history;
  final AppSettings settings;
  final List<String> queueOrder;
  final bool queuePaused;

  Map<String, Object?> toJson() => {
    'version': 1,
    'settings': settings.toJson(),
    'downloads': [for (final item in downloads) item.toJson()],
    'history': [for (final entry in history) entry.toJson()],
    'queueOrder': queueOrder,
    'queuePaused': queuePaused,
  };

  static LibrarySnapshot fromJson(Map<String, Object?> json) {
    List<Map<String, Object?>> maps(Object? raw) => [
      if (raw is List)
        for (final value in raw)
          if (value is Map) value.cast<String, Object?>(),
    ];
    final settings = json['settings'];
    return LibrarySnapshot(
      settings: settings is Map
          ? AppSettings.fromJson(settings.cast<String, Object?>())
          : AppSettings.defaults,
      downloads: [
        for (final map in maps(json['downloads'])) DownloadItem.fromJson(map),
      ],
      history: [
        for (final map in maps(json['history'])) HistoryEntry.fromJson(map),
      ],
      queueOrder: [
        for (final id in json['queueOrder'] as List? ?? const []) '$id',
      ],
      queuePaused: json['queuePaused'] as bool? ?? false,
    );
  }
}

/// JSON-file persistence with debounced, atomic writes.
class LibraryStore {
  LibraryStore(this.file);

  final File file;
  Timer? _debounce;
  LibrarySnapshot Function()? _pending;
  Future<void> _writing = Future.value();

  Future<LibrarySnapshot?> load() async {
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return LibrarySnapshot.fromJson((json as Map).cast<String, Object?>());
    } catch (_) {
      // Keep the unreadable file for inspection instead of overwriting it.
      try {
        await file.copy('${file.path}.corrupt');
      } catch (_) {}
      return null;
    }
  }

  /// Saves [snapshot] within [delay], coalescing bursts of changes into one
  /// write. A throttle, not a debounce: constant progress updates must not
  /// postpone the write forever.
  void scheduleSave(
    LibrarySnapshot Function() snapshot, {
    Duration delay = const Duration(milliseconds: 800),
  }) {
    _pending = snapshot;
    if (_debounce?.isActive ?? false) return;
    _debounce = Timer(delay, flush);
  }

  /// Writes any pending snapshot now.
  Future<void> flush() {
    _debounce?.cancel();
    final build = _pending;
    _pending = null;
    if (build == null) return _writing;
    final data = jsonEncode(build().toJson());
    return _writing = _writing.then((_) => _write(data));
  }

  Future<void> _write(String data) async {
    try {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(data, flush: true);
      await temp.rename(file.path);
    } catch (_) {
      // Disk full or read-only: the next change will try again.
    }
  }
}
