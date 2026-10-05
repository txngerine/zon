import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/utils/formatters.dart';
import '../domain/models/app_settings.dart';
import '../domain/models/download.dart';
import '../domain/models/ui_state.dart';
import 'mock_data.dart';
import 'mock_engine.dart';

/// Application state and the single source of truth for the mock engine.
///
/// Method names intentionally mirror the future Flutter <-> Rust bridge
/// (`createDownload`, `pauseDownload`, `setSpeedLimit`, ...) so swapping the
/// mock implementation for real FFI calls is a drop-in change.
class AppState extends ChangeNotifier {
  AppState({MockEngine? engine, bool startEngine = false})
    : _engine = engine ?? const MockEngine() {
    _downloads = MockData.downloads();
    _history = MockData.history();
    _queueOrder = [
      for (final item in _downloads)
        if (item.status == DownloadStatus.queued) item.id,
    ];
    _samples = MockEngine.seedSamples();
    _peakSpeed = _samples.reduce(max);
    _totalSpeed = totalSpeedOf(_downloads);
    _selectedId = 'z-001';
    if (startEngine) startTicking();
  }

  final MockEngine _engine;
  final Random _random = Random();

  late List<DownloadItem> _downloads;
  late List<HistoryEntry> _history;
  late List<String> _queueOrder;
  late List<double> _samples;

  Timer? _timer;
  DateTime _lastTick = DateTime.now();

  AppSettings _settings = AppSettings.defaults;
  AppSection _section = AppSection.all;
  SortOption _sort = SortOption.newest;
  ViewMode _viewMode = ViewMode.list;
  String _downloadQuery = '';
  String _historyQuery = '';
  HistoryFilter _historyFilter = HistoryFilter.all;
  String? _selectedId;
  bool _queuePaused = false;
  String? _toast;
  int _toastToken = 0;
  double _totalSpeed = 0;
  double _peakSpeed = 0;

  static const int sampleWindow = 90;
  static const Duration _tickInterval = Duration(milliseconds: 400);

  // --------------------------------------------------------------------------
  // Reads
  // --------------------------------------------------------------------------

  List<DownloadItem> get downloads => List.unmodifiable(_downloads);
  List<HistoryEntry> get history => List.unmodifiable(_history);
  AppSettings get settings => _settings;
  AppSection get section => _section;
  SortOption get sort => _sort;
  ViewMode get viewMode => _viewMode;
  String get downloadQuery => _downloadQuery;
  String get historyQuery => _historyQuery;
  HistoryFilter get historyFilter => _historyFilter;
  bool get queuePaused => _queuePaused;
  String? get toast => _toast;
  int get toastToken => _toastToken;
  double get totalSpeed => _totalSpeed;
  double get peakSpeed => _peakSpeed;
  List<double> get speedSamples => List.unmodifiable(_samples);
  bool get engineRunning => _timer != null;

  DownloadItem? get selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final item in _downloads) {
      if (item.id == id) return item;
    }
    return null;
  }

  int get activeCount => _downloads
      .where((item) => item.status == DownloadStatus.downloading)
      .length;

  int get verifyingCount => _downloads
      .where((item) => item.status == DownloadStatus.verifying)
      .length;

  int get queuedCount =>
      _downloads.where((item) => item.status == DownloadStatus.queued).length;

  int get completedCount =>
      _downloads
          .where((item) => item.status == DownloadStatus.completed)
          .length +
      _history
          .where((entry) => entry.status == DownloadStatus.completed)
          .length;

  int get failedCount =>
      _downloads
          .where(
            (item) =>
                item.status == DownloadStatus.failed ||
                item.status == DownloadStatus.cancelled,
          )
          .length +
      _history
          .where(
            (entry) =>
                entry.status == DownloadStatus.failed ||
                entry.status == DownloadStatus.cancelled,
          )
          .length;

  int get pausedCount =>
      _downloads.where((item) => item.status == DownloadStatus.paused).length;

  double get averageSpeed {
    if (_samples.isEmpty) return 0;
    final sum = _samples.fold<double>(0, (total, value) => total + value);
    return sum / _samples.length;
  }

  /// Downloads visible in the main list for the current section/query/sort.
  List<DownloadItem> get visibleDownloads {
    final filter = _section.filter ?? DownloadFilter.all;
    final query = _downloadQuery.trim().toLowerCase();

    final items = _downloads.where((item) {
      if (!filter.matches(item.status)) return false;
      if (query.isEmpty) return true;
      return item.fileName.toLowerCase().contains(query) ||
          item.source.toLowerCase().contains(query) ||
          item.url.toLowerCase().contains(query);
    }).toList();

    return _sortItems(items);
  }

  /// Queued downloads in queue order (used by drag & drop).
  List<DownloadItem> get queuedDownloads {
    final items = _downloads
        .where((item) => item.status == DownloadStatus.queued)
        .toList();
    if (_sort != SortOption.newest) return items;
    final rank = {
      for (var i = 0; i < _queueOrder.length; i++) _queueOrder[i]: i,
    };
    items.sort(
      (a, b) => (rank[a.id] ?? 1 << 20).compareTo(rank[b.id] ?? 1 << 20),
    );
    return items;
  }

  List<HistoryEntry> get visibleHistory {
    final query = _historyQuery.trim().toLowerCase();
    final entries = _history.where((entry) {
      if (!_historyFilter.matches(entry.status)) return false;
      if (query.isEmpty) return true;
      return entry.fileName.toLowerCase().contains(query) ||
          entry.source.toLowerCase().contains(query);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  List<DownloadItem> _sortItems(List<DownloadItem> items) {
    switch (_sort) {
      case SortOption.newest:
        items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case SortOption.oldest:
        items.sort((a, b) => a.addedAt.compareTo(b.addedAt));
      case SortOption.name:
        items.sort(
          (a, b) =>
              a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
        );
      case SortOption.size:
        items.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    }
    return items;
  }

  // --------------------------------------------------------------------------
  // Navigation / list preferences
  // --------------------------------------------------------------------------

  void setSection(AppSection section) {
    if (_section == section) return;
    _section = section;
    notifyListeners();
  }

  void setSort(SortOption sort) {
    if (_sort == sort) return;
    _sort = sort;
    notifyListeners();
  }

  void setViewMode(ViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    notifyListeners();
  }

  void setDownloadQuery(String query) {
    if (_downloadQuery == query) return;
    _downloadQuery = query;
    notifyListeners();
  }

  void setHistoryQuery(String query) {
    if (_historyQuery == query) return;
    _historyQuery = query;
    notifyListeners();
  }

  void setHistoryFilter(HistoryFilter filter) {
    if (_historyFilter == filter) return;
    _historyFilter = filter;
    notifyListeners();
  }

  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedId == null) return;
    _selectedId = null;
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Bridge API — the surface Flutter will eventually call over FFI
  // --------------------------------------------------------------------------

  DownloadItem createDownload({
    required String url,
    String? fileName,
    String? savePath,
    int? connections,
    DownloadPriority priority = DownloadPriority.normal,
    bool startImmediately = true,
    bool createSubfolder = false,
  }) {
    final name = (fileName == null || fileName.trim().isEmpty)
        ? fileNameFromUrl(url, fallback: 'download.bin')
        : fileName.trim();
    var path = (savePath == null || savePath.trim().isEmpty)
        ? _settings.defaultLocation
        : savePath.trim();
    if (createSubfolder) {
      final folder = Uri.tryParse(url)?.host ?? 'downloads';
      path = '$path/$folder';
    }

    final now = DateTime.now();
    final canStart =
        startImmediately &&
        !_queuePaused &&
        activeCount < _settings.maxSimultaneous;

    final item = DownloadItem(
      id: 'z-${now.microsecondsSinceEpoch.toRadixString(36)}',
      fileName: name,
      url: url.trim(),
      source: Uri.tryParse(url)?.host ?? 'unknown',
      sizeBytes: _estimateSize(url, name),
      downloadedBytes: 0,
      status: canStart ? DownloadStatus.downloading : DownloadStatus.queued,
      speed: 0,
      baseSpeed: (7 + _random.nextDouble() * 18) * 1024 * 1024,
      connections: connections ?? _settings.defaultConnections,
      savePath: path,
      priority: priority,
      httpStatus: canStart ? 206 : 0,
      server: Uri.tryParse(url)?.host.split('.').first ?? 'cdn',
      contentType: _contentTypeFor(name),
      addedAt: now,
      lastActivity: now,
    );

    _downloads = [item, ..._downloads];
    _queueOrder = [..._queueOrder, item.id];
    _selectedId = item.id;
    notifyListeners();
    showToast(
      canStart ? 'Downloading ${item.fileName}' : 'Queued ${item.fileName}',
    );
    return item;
  }

  void pauseDownload(String id) {
    final item = _find(id);
    if (item == null || item.status != DownloadStatus.downloading) return;
    _update(
      id,
      (current) => current.copyWith(
        status: DownloadStatus.paused,
        speed: 0,
        lastActivity: DateTime.now(),
      ),
    );
    showToast('Paused ${item.fileName}');
  }

  void resumeDownload(String id) {
    final item = _find(id);
    if (item == null) return;
    final resumable =
        item.status == DownloadStatus.paused ||
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.cancelled;
    if (!resumable) return;
    _update(
      id,
      (current) => current.copyWith(
        status: DownloadStatus.downloading,
        speed: current.baseSpeed * 0.4,
        lastActivity: DateTime.now(),
        clearFailure: true,
        httpStatus: 206,
      ),
    );
    showToast('Resumed ${item.fileName}');
  }

  void cancelDownload(String id) {
    final item = _find(id);
    if (item == null || item.isTerminal) return;
    _update(
      id,
      (current) => current.copyWith(
        status: DownloadStatus.cancelled,
        speed: 0,
        lastActivity: DateTime.now(),
      ),
    );
    final cancelled = _find(id);
    if (cancelled != null) _logHistory(cancelled);
    showToast('Cancelled ${item.fileName}');
  }

  void removeDownload(String id) {
    final item = _find(id);
    if (item == null) return;
    _downloads = _downloads.where((d) => d.id != id).toList();
    _queueOrder = _queueOrder.where((qid) => qid != id).toList();
    if (_selectedId == id) {
      _selectedId = _downloads.isNotEmpty ? _downloads.first.id : null;
    }
    notifyListeners();
    showToast('Removed ${item.fileName}');
  }

  void pauseAll() {
    var changed = false;
    _downloads = [
      for (final item in _downloads)
        if (item.status == DownloadStatus.downloading)
          () {
            changed = true;
            return item.copyWith(status: DownloadStatus.paused, speed: 0);
          }()
        else
          item,
    ];
    if (!changed) return;
    notifyListeners();
    showToast('All downloads paused');
  }

  void resumeAll() {
    var slots = _settings.maxSimultaneous;
    var changed = false;
    _downloads = [
      for (final item in _downloads)
        if ((item.status == DownloadStatus.paused ||
                item.status == DownloadStatus.failed) &&
            slots > 0)
          () {
            slots--;
            changed = true;
            return item.copyWith(
              status: DownloadStatus.downloading,
              speed: item.baseSpeed * 0.4,
              clearFailure: true,
              httpStatus: 206,
            );
          }()
        else
          item,
    ];
    if (!changed) {
      showToast('Nothing to resume');
      return;
    }
    notifyListeners();
    showToast('Downloads resumed');
  }

  void setSpeedLimit(String limit) {
    if (_settings.defaultSpeedLimit == limit) return;
    _settings = _settings.copyWith(defaultSpeedLimit: limit);
    notifyListeners();
    showToast(limit == 'No Limit' ? 'Speed limit removed' : 'Limit: $limit');
  }

  void setPriority(String id, DownloadPriority priority) {
    final item = _find(id);
    if (item == null || item.priority == priority) return;
    _update(id, (current) => current.copyWith(priority: priority));
    showToast('${item.fileName} — ${priority.label} priority');
  }

  void updateSettings(AppSettings next) {
    _settings = next;
    notifyListeners();
  }

  void resetSettings() {
    _settings = AppSettings.defaults;
    notifyListeners();
    showToast('Settings restored to defaults');
  }

  // --------------------------------------------------------------------------
  // Queue control
  // --------------------------------------------------------------------------

  void toggleQueue() => _queuePaused ? resumeQueue() : pauseQueue();

  void pauseQueue() {
    if (_queuePaused) return;
    _queuePaused = true;
    notifyListeners();
    showToast('Queue paused');
  }

  void resumeQueue() {
    if (!_queuePaused) return;
    _queuePaused = false;
    notifyListeners();
    showToast('Queue resumed');
  }

  void clearQueue() {
    final count = queuedCount;
    if (count == 0) return;
    _downloads = _downloads
        .where((item) => item.status != DownloadStatus.queued)
        .toList();
    _queueOrder = [
      for (final id in _queueOrder)
        if (_downloads.any((item) => item.id == id)) id,
    ];
    notifyListeners();
    showToast('Queue cleared — $count removed');
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _queueOrder.length) return;
    if (newIndex < 0 || newIndex > _queueOrder.length - 1) return;
    final next = [..._queueOrder];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    _queueOrder = next;
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // History
  // --------------------------------------------------------------------------

  void removeHistory(String id) {
    final before = _history.length;
    _history = _history.where((entry) => entry.id != id).toList();
    if (_history.length == before) return;
    notifyListeners();
  }

  void clearHistory() {
    if (_history.isEmpty) return;
    _history = const [];
    notifyListeners();
    showToast('History cleared');
  }

  void redownload(HistoryEntry entry) {
    _section = AppSection.all;
    createDownload(url: entry.url, fileName: entry.fileName);
  }

  // --------------------------------------------------------------------------
  // Transient messaging
  // --------------------------------------------------------------------------

  void showToast(String message) {
    _toast = message;
    _toastToken++;
    notifyListeners();
  }

  void dismissToast() {
    if (_toast == null) return;
    _toast = null;
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // Mock engine loop
  // --------------------------------------------------------------------------

  void startTicking() {
    if (_timer != null) return;
    _lastTick = DateTime.now();
    _timer = Timer.periodic(_tickInterval, (_) {
      final now = DateTime.now();
      final dt = now.difference(_lastTick);
      _lastTick = now;
      tick(dt: dt);
    });
  }

  void stopTicking() {
    _timer?.cancel();
    _timer = null;
  }

  /// Advances the simulated engine by one step and notifies listeners.
  @visibleForTesting
  void tick({Duration? dt, DateTime? now}) {
    final stamp = now ?? DateTime.now();
    final outcome = _engine.advance(
      current: _downloads,
      maxSimultaneous: _settings.maxSimultaneous,
      queuePaused: _queuePaused,
      queueOrder: _queueOrder,
      dt: dt ?? _tickInterval,
      now: stamp,
      random: _random,
    );

    _downloads = outcome.downloads;

    for (final id in outcome.completed) {
      final item = _find(id);
      if (item == null) continue;
      _logHistory(item);
      if (_settings.notifyCompleted) {
        showToast('Completed ${item.fileName}');
      }
    }

    _totalSpeed = totalSpeedOf(_downloads);
    _samples = [..._samples, _totalSpeed];
    if (_samples.length > sampleWindow) {
      _samples = _samples.sublist(_samples.length - sampleWindow);
    }
    if (_totalSpeed > _peakSpeed) _peakSpeed = _totalSpeed;

    notifyListeners();
  }

  @override
  void dispose() {
    stopTicking();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Internals
  // --------------------------------------------------------------------------

  DownloadItem? _find(String id) {
    for (final item in _downloads) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _update(String id, DownloadItem Function(DownloadItem) transform) {
    final item = _find(id);
    if (item == null) return;
    final next = transform(item);
    if (identical(next, item)) return;
    _downloads = [
      for (final current in _downloads) current.id == id ? next : current,
    ];
    notifyListeners();
  }

  void _logHistory(DownloadItem item) {
    final alreadyLogged = _history.any((entry) => entry.id == item.id);
    if (alreadyLogged) return;
    _history = [
      HistoryEntry.fromDownload(item, durationSeconds: item.elapsedSeconds),
      ..._history,
    ];
  }

  int _estimateSize(String url, String name) {
    final seed = (url + name).hashCode.abs();
    final lower = name.toLowerCase();
    int bytes;
    if (lower.endsWith('.iso')) {
      bytes = (1200 + seed % 5000) * 1024 * 1024;
    } else if (lower.endsWith('.mkv') || lower.endsWith('.mp4')) {
      bytes = (700 + seed % 7600) * 1024 * 1024;
    } else if (lower.endsWith('.dmg') ||
        lower.endsWith('.pkg') ||
        lower.endsWith('.zip') ||
        lower.endsWith('.tar.gz') ||
        lower.endsWith('.xz')) {
      bytes = (80 + seed % 900) * 1024 * 1024;
    } else {
      bytes = (12 + seed % 380) * 1024 * 1024;
    }
    return bytes;
  }

  String _contentTypeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.iso')) return 'application/x-iso9660-image';
    if (lower.endsWith('.dmg')) return 'application/x-apple-diskimage';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.pkg')) return 'application/octet-stream';
    return 'application/octet-stream';
  }
}
