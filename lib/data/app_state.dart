import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/utils/formatters.dart';
import '../domain/models/app_settings.dart';
import '../domain/models/download.dart';
import '../domain/models/media_format.dart';
import '../domain/models/ui_state.dart';
import '../engine/engine.dart';
import '../engine/http_engine.dart';
import '../engine/media/media_engine.dart';
import '../engine/media/media_sites.dart';
import '../engine/media/ytdlp.dart';
import '../platform/desktop_bridge.dart';
import 'library_store.dart';

/// Engine that never transfers anything; the default for widget tests.
class IdleEngine implements TransferEngine {
  @override
  set listener(TransferListener listener) {}

  @override
  void start(DownloadItem item, TransferOptions options) {}

  @override
  Future<void> pause(String id) async {}

  @override
  Future<void> cancel(String id) async {}

  @override
  bool isRunning(String id) => false;

  @override
  void setSpeedLimit(String id, int? bytesPerSecond) {}

  @override
  Future<void> dispose() async {}
}

class _Progress {
  _Progress(this.downloaded, this.speed, this.total);
  final int downloaded;
  final double speed;
  final int? total;
}

/// Application state: the download library, the scheduler that feeds the
/// engines, and every user-facing action.
class AppState extends ChangeNotifier implements TransferListener {
  AppState({
    TransferEngine? httpEngine,
    TransferEngine? mediaEngine,
    MediaTools? mediaTools,
    this._store,
    this._desktop = const DesktopBridge.noop(),
    List<DownloadItem>? downloads,
    List<HistoryEntry>? history,
    AppSettings? settings,
    List<String>? queueOrder,
    bool queuePaused = false,
    this.dataDir = '',
  }) : _http = httpEngine ?? IdleEngine(),
       _media = mediaEngine ?? IdleEngine(),
       _tools = mediaTools {
    _http.listener = this;
    _media.listener = this;
    _settings = settings ?? AppSettings.defaults;
    _downloads = downloads ?? const [];
    _history = history ?? const [];
    _queuePaused = queuePaused;
    _queueOrder =
        queueOrder ??
        [
          for (final item in _downloads)
            if (item.status == DownloadStatus.queued) item.id,
        ];
    _samples = List<double>.filled(sampleWindow, 0);
    _totalSpeed = 0;
    _selectedId = _downloads.isEmpty ? null : _downloads.first.id;
  }

  /// Builds the production state: real engines, the on-disk library and
  /// OS integration.
  static Future<AppState> bootstrap() async {
    final support = await getApplicationSupportDirectory();
    final sep = Platform.pathSeparator;
    final store = LibraryStore(File('${support.path}${sep}library.json'));
    final snapshot = await store.load();

    var settings = snapshot?.settings ?? AppSettings.defaults;
    if (snapshot == null) {
      final downloads = await _safeDownloadsDir();
      if (downloads != null) {
        settings = settings.copyWith(defaultLocation: downloads);
      }
    }

    final tools = MediaTools(binDir: '${support.path}${sep}bin')
      ..override = settings.ytDlpPath;
    final restored = [
      for (final item in snapshot?.downloads ?? const <DownloadItem>[])
        // Transfers interrupted by quitting go back to the queue.
        switch (item.status) {
          DownloadStatus.downloading || DownloadStatus.verifying =>
            item.copyWith(status: DownloadStatus.queued, speed: 0),
          DownloadStatus.failed when settings.autoResumeFailed => item.copyWith(
            status: DownloadStatus.queued,
            clearFailure: true,
          ),
          _ => item.copyWith(speed: 0),
        },
    ];
    final queueOrder = [
      ...?snapshot?.queueOrder,
      for (final item in restored)
        if (item.status == DownloadStatus.queued &&
            !(snapshot?.queueOrder.contains(item.id) ?? false))
          item.id,
    ];

    final state = AppState(
      httpEngine: HttpEngine(stateDir: '${support.path}${sep}parts'),
      mediaEngine: MediaEngine(tools: tools),
      mediaTools: tools,
      store: store,
      desktop: SystemBridge(),
      downloads: restored,
      history: snapshot?.history,
      settings: settings,
      queueOrder: queueOrder,
      queuePaused: snapshot?.queuePaused ?? false,
      dataDir: support.path,
    );
    // Media downloads wait until we know whether yt-dlp exists.
    state._toolsPending = true;
    unawaited(
      state.refreshMediaTools().whenComplete(() {
        state._toolsPending = false;
        if (!settings.autoStart) state._queuePaused = true;
      }),
    );
    return state;
  }

  static Future<String?> _safeDownloadsDir() async {
    try {
      return (await getDownloadsDirectory())?.path;
    } catch (_) {
      return null;
    }
  }

  final TransferEngine _http;
  final TransferEngine _media;
  final MediaTools? _tools;
  final LibraryStore? _store;
  final DesktopBridge _desktop;

  /// Application-support folder holding the library and yt-dlp.
  final String dataDir;

  late List<DownloadItem> _downloads;
  late List<HistoryEntry> _history;
  late List<String> _queueOrder;
  late List<double> _samples;

  /// Downloads currently handed to an engine.
  final Set<String> _running = {};
  final Map<String, _Progress> _pending = {};

  Timer? _timer;
  DateTime _lastTick = DateTime.now();
  double _elapsedCarry = 0;
  bool _toolsPending = false;
  bool _disposed = false;

  late AppSettings _settings;
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

  bool _toolsBusy = false;
  double? _installProgress;
  String? _lastClipboard;

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

  MediaTools? get mediaTools => _tools;
  bool get mediaToolsBusy => _toolsBusy;

  /// Progress of an in-flight yt-dlp install (0..1), or null.
  double? get installProgress => _installProgress;

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
          .where(
            (entry) =>
                entry.status == DownloadStatus.completed &&
                !_downloads.any((item) => item.id == entry.id),
          )
          .length;

  int get failedCount => _downloads
      .where(
        (item) =>
            item.status == DownloadStatus.failed ||
            item.status == DownloadStatus.cancelled,
      )
      .length;

  int get pausedCount =>
      _downloads.where((item) => item.status == DownloadStatus.paused).length;

  double get averageSpeed {
    final active = _samples.where((value) => value > 0);
    if (active.isEmpty) return 0;
    return active.fold<double>(0, (total, value) => total + value) /
        active.length;
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
  // Download actions
  // --------------------------------------------------------------------------

  /// Adds a download. Media pages (YouTube, Reels, ...) are detected from the
  /// URL unless [kind] is given.
  DownloadItem createDownload({
    required String url,
    String? fileName,
    String? savePath,
    int? connections,
    DownloadPriority priority = DownloadPriority.normal,
    bool startImmediately = true,
    bool createSubfolder = false,
    DownloadKind? kind,
    MediaFormat? mediaFormat,
    String? speedLimit,
    String? thumbnailUrl,
    String createdVia = 'Manual',
    bool notify = true,
    bool? lockName,
  }) {
    final link = url.trim();
    final site = detectMediaSite(link);
    final resolvedKind =
        kind ?? (site != null ? DownloadKind.media : DownloadKind.file);
    final isMedia = resolvedKind == DownloadKind.media;
    final format = isMedia
        ? (mediaFormat ?? _settings.defaultMediaFormat)
        : null;

    final typed = fileName?.trim() ?? '';
    final name = typed.isNotEmpty
        ? (isMedia ? _withExtension(typed, format!) : typed)
        : isMedia
        ? '${site?.name ?? 'Media'} ${format!.isAudio ? 'audio' : 'video'}'
        : fileNameFromUrl(link, fallback: 'download.bin');

    final uri = Uri.tryParse(link);
    final host = (uri?.host.isNotEmpty ?? false) ? uri!.host : 'unknown';
    var path = (savePath == null || savePath.trim().isEmpty)
        ? _settings.defaultLocation
        : savePath.trim();
    path = expandHome(path, environment: Platform.environment);
    if (createSubfolder) {
      path = '$path${Platform.pathSeparator}${site?.name ?? host}';
    }

    final now = DateTime.now();
    final canStart =
        startImmediately &&
        !_queuePaused &&
        !(isMedia && _toolsPending) &&
        activeCount < _settings.maxSimultaneous;

    final item = DownloadItem(
      id: 'z-${now.microsecondsSinceEpoch.toRadixString(36)}',
      fileName: name,
      url: link,
      source: site?.name ?? host,
      sizeBytes: 0,
      downloadedBytes: 0,
      status: DownloadStatus.queued,
      connections: connections ?? _settings.defaultConnections,
      savePath: path,
      priority: priority,
      contentType: isMedia
          ? (format!.isAudio ? 'audio/*' : 'video/mp4')
          : _contentTypeFor(name),
      addedAt: now,
      lastActivity: now,
      kind: resolvedKind,
      mediaFormat: format,
      speedLimit: speedLimit ?? 'No Limit',
      nameLocked: lockName ?? typed.isNotEmpty,
      thumbnailUrl: thumbnailUrl,
      createdVia: createdVia,
    );

    _downloads = [item, ..._downloads];
    _queueOrder = [..._queueOrder, item.id];
    _selectedId = item.id;
    if (canStart) _start(item.id);
    _changed();
    if (notify) {
      showToast(
        canStart ? 'Downloading ${item.fileName}' : 'Queued ${item.fileName}',
      );
    }
    return _find(item.id) ?? item;
  }

  /// Queues every video of a playlist.
  int createMediaBatch(
    List<MediaEntry> entries, {
    required MediaFormat format,
    String? savePath,
    int? connections,
    DownloadPriority priority = DownloadPriority.normal,
    bool startImmediately = true,
    bool createSubfolder = false,
    String? speedLimit,
  }) {
    for (final entry in entries) {
      createDownload(
        url: entry.url,
        fileName: entry.title,
        savePath: savePath,
        connections: connections,
        priority: priority,
        startImmediately: startImmediately,
        createSubfolder: createSubfolder,
        kind: DownloadKind.media,
        mediaFormat: format,
        speedLimit: speedLimit,
        createdVia: 'Playlist',
        notify: false,
        lockName: false,
      );
    }
    showToast('Added ${entries.length} videos from playlist');
    return entries.length;
  }

  void pauseDownload(String id) {
    final item = _find(id);
    if (item == null) return;
    if (item.status != DownloadStatus.downloading &&
        item.status != DownloadStatus.verifying) {
      return;
    }
    _stop(item);
    _update(
      id,
      (current) => current.copyWith(
        status: DownloadStatus.paused,
        speed: 0,
        lastActivity: DateTime.now(),
        clearPhase: true,
      ),
    );
    showToast('Paused ${item.fileName}');
    if (_settings.notifyPaused) {
      unawaited(_desktop.notify('Download paused', item.fileName));
    }
  }

  /// Resumes a paused/failed/cancelled download, or force-starts a queued
  /// one ("Start now").
  void resumeDownload(String id) {
    final item = _find(id);
    if (item == null) return;
    final resumable =
        item.status == DownloadStatus.paused ||
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.cancelled ||
        item.status == DownloadStatus.queued;
    if (!resumable) return;
    final restart = item.status == DownloadStatus.cancelled;
    if (restart) {
      _update(id, (current) => current.copyWith(downloadedBytes: 0));
    }
    _start(id);
    _changed();
    showToast(
      '${item.status == DownloadStatus.queued ? 'Started' : 'Resumed'} '
      '${item.fileName}',
    );
  }

  void cancelDownload(String id) {
    final item = _find(id);
    if (item == null || item.isTerminal) return;
    _running.remove(id);
    _pending.remove(id);
    unawaited(_engineFor(item).cancel(id));
    _update(
      id,
      (current) => current.copyWith(
        status: DownloadStatus.cancelled,
        speed: 0,
        downloadedBytes: 0,
        lastActivity: DateTime.now(),
        clearPhase: true,
      ),
    );
    final cancelled = _find(id);
    if (cancelled != null) _logHistory(cancelled);
    _changed();
    showToast('Cancelled ${item.fileName}');
  }

  /// Removes [id] from the list. Unfinished partial data is deleted;
  /// completed files stay on disk.
  void removeDownload(String id) {
    final item = _find(id);
    if (item == null) return;
    _running.remove(id);
    _pending.remove(id);
    if (item.status != DownloadStatus.completed) {
      unawaited(_engineFor(item).cancel(id));
    }
    _downloads = _downloads.where((d) => d.id != id).toList();
    _queueOrder = _queueOrder.where((qid) => qid != id).toList();
    if (_selectedId == id) {
      _selectedId = _downloads.isNotEmpty ? _downloads.first.id : null;
    }
    _changed();
    showToast('Removed ${item.fileName}');
  }

  /// Removes every completed download from the list (files stay on disk).
  void clearCompleted() {
    final before = _downloads.length;
    _downloads = _downloads
        .where((item) => item.status != DownloadStatus.completed)
        .toList();
    if (_downloads.length == before) return;
    if (_find(_selectedId ?? '') == null) {
      _selectedId = _downloads.isEmpty ? null : _downloads.first.id;
    }
    _changed();
    showToast('Cleared ${before - _downloads.length} completed');
  }

  void pauseAll() {
    final active = _downloads
        .where(
          (item) =>
              item.status == DownloadStatus.downloading ||
              item.status == DownloadStatus.verifying,
        )
        .toList();
    if (active.isEmpty) return;
    for (final item in active) {
      _stop(item);
    }
    final ids = active.map((item) => item.id).toSet();
    _downloads = [
      for (final item in _downloads)
        ids.contains(item.id)
            ? item.copyWith(
                status: DownloadStatus.paused,
                speed: 0,
                clearPhase: true,
              )
            : item,
    ];
    _changed();
    showToast('All downloads paused');
  }

  void resumeAll() {
    var slots = _settings.maxSimultaneous - activeCount;
    final candidates = _downloads
        .where(
          (item) =>
              item.status == DownloadStatus.paused ||
              item.status == DownloadStatus.failed,
        )
        .toList();
    if (candidates.isEmpty) {
      showToast('Nothing to resume');
      return;
    }
    for (final item in candidates) {
      if (slots > 0) {
        _start(item.id);
        slots--;
      } else {
        // Over the limit: wait for a free slot.
        _update(
          item.id,
          (current) => current.copyWith(
            status: DownloadStatus.queued,
            clearFailure: true,
          ),
        );
        if (!_queueOrder.contains(item.id)) {
          _queueOrder = [..._queueOrder, item.id];
        }
      }
    }
    _changed();
    showToast('Downloads resumed');
  }

  /// Sets the global speed cap shared by all active downloads.
  void setSpeedLimit(String limit) {
    if (_settings.defaultSpeedLimit == limit) return;
    _settings = _settings.copyWith(defaultSpeedLimit: limit);
    _rebalanceLimits();
    _changed();
    showToast(limit == 'No Limit' ? 'Speed limit removed' : 'Limit: $limit');
  }

  void setPriority(String id, DownloadPriority priority) {
    final item = _find(id);
    if (item == null || item.priority == priority) return;
    _update(id, (current) => current.copyWith(priority: priority));
    _changed();
    showToast('${item.fileName} — ${priority.label} priority');
  }

  void updateSettings(AppSettings next) {
    final previous = _settings;
    _settings = next;
    if (next.startOnStartup != previous.startOnStartup) {
      unawaited(_desktop.setLaunchAtStartup(next.startOnStartup));
    }
    if (next.ytDlpPath != previous.ytDlpPath) {
      _tools?.override = next.ytDlpPath;
      unawaited(refreshMediaTools());
    }
    if (next.defaultSpeedLimit != previous.defaultSpeedLimit) {
      _rebalanceLimits();
    }
    _changed();
  }

  void resetSettings() {
    final location = _settings.defaultLocation;
    updateSettings(AppSettings.defaults.copyWith(defaultLocation: location));
    showToast('Settings restored to defaults');
  }

  // --------------------------------------------------------------------------
  // Files
  // --------------------------------------------------------------------------

  /// Shows a download in the file manager (the file once it exists, its
  /// folder before that).
  Future<void> revealDownload(DownloadItem item) async {
    final path = item.filePath;
    if (path != null && await File(path).exists()) {
      await _desktop.reveal(path);
      return;
    }
    if (await Directory(item.savePath).exists()) {
      await _desktop.open(item.savePath);
      return;
    }
    showToast('Folder not found: ${item.savePath}');
  }

  Future<void> openDownload(DownloadItem item) async {
    final path = item.filePath;
    if (path == null || !await File(path).exists()) {
      showToast('File is no longer on disk');
      return;
    }
    await _desktop.open(path);
  }

  Future<void> revealHistory(HistoryEntry entry) async {
    final path = entry.filePath;
    if (path != null && await File(path).exists()) {
      await _desktop.reveal(path);
    } else if (entry.savePath.isNotEmpty &&
        await Directory(entry.savePath).exists()) {
      await _desktop.open(entry.savePath);
    } else {
      showToast('File is no longer on disk');
    }
  }

  Future<void> openPath(String path) => _desktop.open(path);

  // --------------------------------------------------------------------------
  // Media tools (yt-dlp / ffmpeg)
  // --------------------------------------------------------------------------

  Future<void> refreshMediaTools() async {
    final tools = _tools;
    if (tools == null) return;
    _toolsBusy = true;
    notifyListeners();
    try {
      await tools.resolve();
    } finally {
      _toolsBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> installYtDlp() async {
    final tools = _tools;
    if (tools == null || _toolsBusy) return false;
    _toolsBusy = true;
    _installProgress = 0;
    notifyListeners();
    try {
      await tools.install(
        onProgress: (value) {
          _installProgress = value;
          notifyListeners();
        },
      );
      showToast('yt-dlp ${tools.version} installed');
      return true;
    } catch (error) {
      showToast('Install failed: $error');
      return false;
    } finally {
      _toolsBusy = false;
      _installProgress = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> updateYtDlp() async {
    final tools = _tools;
    if (tools == null || _toolsBusy) return;
    _toolsBusy = true;
    notifyListeners();
    try {
      final version = await tools.update();
      showToast('yt-dlp is up to date ($version)');
    } catch (error) {
      showToast('$error');
    } finally {
      _toolsBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> clearMediaCache() async {
    await _tools?.clearCache();
    showToast('yt-dlp cache cleared');
  }

  /// Fetches title/thumbnail/playlist info for a media link.
  Future<MediaInfo> probeMedia(String url) {
    final tools = _tools;
    if (tools == null || !tools.hasYtDlp) {
      return Future.error(const MediaToolException('yt-dlp is not installed'));
    }
    return tools.probe(
      url,
      cookiesBrowser: _settings.cookiesBrowser,
      proxy: _settings.proxy,
    );
  }

  // --------------------------------------------------------------------------
  // Clipboard / external sources
  // --------------------------------------------------------------------------

  /// Returns the link in [text] if it is new since the last check, so the
  /// shell can offer it once.
  String? takeClipboardLink(String? text) {
    final value = text?.trim() ?? '';
    if (value.isEmpty || value == _lastClipboard) return null;
    _lastClipboard = value;
    final uri = Uri.tryParse(value);
    final isLink =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.') &&
        !value.contains(RegExp(r'\s'));
    if (!isLink) return null;
    if (_downloads.any((item) => item.url == value)) return null;
    return value;
  }

  /// Marks [text] as seen so the clipboard watcher ignores it.
  void markClipboardSeen(String? text) => _lastClipboard = text?.trim();

  /// Entry point for links sent by the browser bookmarklet.
  Future<void> addFromBrowser(String url, {MediaFormat? format}) async {
    _section = AppSection.all;
    final count = await addLink(
      url,
      mediaFormat: format,
      createdVia: 'Browser',
    );
    unawaited(
      _desktop.notify(
        'Added to ZON',
        count == 1 ? (selected?.fileName ?? url) : '$count downloads',
      ),
    );
  }

  /// Adds [url], expanding playlists and channels into one download per
  /// video. Returns how many downloads were created.
  Future<int> addLink(
    String url, {
    MediaFormat? mediaFormat,
    String? savePath,
    int? connections,
    DownloadPriority priority = DownloadPriority.normal,
    bool startImmediately = true,
    bool createSubfolder = false,
    String? speedLimit,
    String createdVia = 'Manual',
  }) async {
    if (looksLikePlaylist(url) && (_tools?.hasYtDlp ?? false)) {
      showToast('Reading playlist…');
      try {
        final info = await probeMedia(url);
        if (info.isPlaylist && info.entries.isNotEmpty) {
          return createMediaBatch(
            info.entries,
            format: mediaFormat ?? _settings.defaultMediaFormat,
            savePath: savePath,
            connections: connections,
            priority: priority,
            startImmediately: startImmediately,
            createSubfolder: createSubfolder,
            speedLimit: speedLimit,
          );
        }
      } catch (_) {
        // Fall through: the engine downloads just the first entry.
      }
    }
    createDownload(
      url: url,
      mediaFormat: mediaFormat,
      savePath: savePath,
      connections: connections,
      priority: priority,
      startImmediately: startImmediately,
      createSubfolder: createSubfolder,
      speedLimit: speedLimit,
      createdVia: createdVia,
    );
    return 1;
  }

  // --------------------------------------------------------------------------
  // Queue control
  // --------------------------------------------------------------------------

  void toggleQueue() => _queuePaused ? resumeQueue() : pauseQueue();

  void pauseQueue() {
    if (_queuePaused) return;
    _queuePaused = true;
    _changed();
    showToast('Queue paused');
  }

  void resumeQueue() {
    if (!_queuePaused) return;
    _queuePaused = false;
    _changed();
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
    _changed();
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
    _changed();
  }

  // --------------------------------------------------------------------------
  // History
  // --------------------------------------------------------------------------

  void removeHistory(String id) {
    final before = _history.length;
    _history = _history.where((entry) => entry.id != id).toList();
    if (_history.length == before) return;
    _changed();
  }

  void clearHistory() {
    if (_history.isEmpty) return;
    _history = const [];
    _changed();
    showToast('History cleared');
  }

  void redownload(HistoryEntry entry) {
    _section = AppSection.all;
    createDownload(
      url: entry.url,
      fileName: entry.kind == DownloadKind.file ? entry.fileName : null,
      savePath: entry.savePath.isEmpty ? null : entry.savePath,
      kind: entry.kind,
      mediaFormat: entry.mediaFormat,
    );
  }

  // --------------------------------------------------------------------------
  // Transient messaging
  // --------------------------------------------------------------------------

  void showToast(String message) {
    if (_disposed) return;
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
  // TransferListener — called by the engines
  // --------------------------------------------------------------------------

  @override
  void onMeta(String id, TransferMeta meta) {
    if (!_running.contains(id)) return;
    _update(id, (item) {
      final name = meta.fileName;
      return item.copyWith(
        fileName: name != null && !item.nameLocked ? name : null,
        sizeBytes: meta.sizeBytes,
        resumeSupported: meta.resumeSupported,
        contentType: meta.contentType,
        server: meta.server,
        httpStatus: meta.httpStatus,
        thumbnailUrl: meta.thumbnailUrl,
        connections: meta.connections,
      );
    });
  }

  @override
  void onProgress(String id, int downloaded, double speed, {int? total}) {
    if (!_running.contains(id)) return;
    _pending[id] = _Progress(downloaded, speed, total);
  }

  @override
  void onPhase(String id, String phase) {
    if (!_running.contains(id)) return;
    _update(
      id,
      (item) => item.copyWith(
        status: DownloadStatus.verifying,
        phase: phase,
        speed: 0,
      ),
    );
  }

  @override
  void onCompleted(String id, String filePath) {
    if (!_running.remove(id)) return;
    final progress = _pending.remove(id);
    final name = filePath.split(RegExp(r'[/\\]')).last;
    _update(id, (item) {
      // Media keeps its clean title; files show the name actually written.
      final size = progress?.total ?? progress?.downloaded ?? item.sizeBytes;
      return item.copyWith(
        status: DownloadStatus.completed,
        filePath: filePath,
        fileName: item.isMedia ? null : name,
        sizeBytes: size,
        downloadedBytes: size,
        speed: 0,
        lastActivity: DateTime.now(),
        clearFailure: true,
        clearPhase: true,
      );
    });
    final item = _find(id);
    if (item == null) return;
    _logHistory(item);
    _changed();
    if (_settings.notifyCompleted) {
      showToast('Completed ${item.fileName}');
      unawaited(_desktop.notify('Download complete', item.fileName));
    }
    if (_settings.autoOpenCompleted) unawaited(_desktop.open(filePath));
  }

  @override
  void onFailed(String id, String reason) {
    if (!_running.remove(id)) return;
    final progress = _pending.remove(id);
    _update(
      id,
      (item) => item.copyWith(
        status: DownloadStatus.failed,
        failureReason: reason,
        downloadedBytes: progress?.downloaded,
        speed: 0,
        lastActivity: DateTime.now(),
        clearPhase: true,
      ),
    );
    final item = _find(id);
    if (item == null) return;
    _logHistory(item);
    _changed();
    if (_settings.notifyFailed) {
      showToast('Failed ${item.fileName}');
      unawaited(
        _desktop.notify('Download failed', '${item.fileName}\n$reason'),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Scheduler loop
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

  /// Applies engine progress, starts queued downloads, samples the speed.
  @visibleForTesting
  void tick({Duration? dt, DateTime? now}) {
    final stamp = now ?? DateTime.now();
    final step = (dt ?? _tickInterval).inMilliseconds / 1000.0;
    _elapsedCarry += step;
    final wholeSeconds = _elapsedCarry.floor();
    _elapsedCarry -= wholeSeconds;

    final pending = Map.of(_pending);
    _pending.clear();
    _downloads = [
      for (final item in _downloads)
        if (item.status == DownloadStatus.downloading)
          () {
            final progress = pending[item.id];
            return item.copyWith(
              downloadedBytes: progress?.downloaded,
              speed: progress?.speed,
              sizeBytes: progress?.total,
              lastActivity: progress == null ? null : stamp,
              elapsedSeconds: item.elapsedSeconds + wholeSeconds,
            );
          }()
        else
          item,
    ];

    // Downloads marked active but not handed to an engine (e.g. seeded).
    for (final item in _downloads) {
      if (item.status == DownloadStatus.downloading &&
          !_running.contains(item.id)) {
        _start(item.id);
      }
    }
    _promoteQueued();

    _totalSpeed = _downloads
        .where((item) => item.status == DownloadStatus.downloading)
        .fold<double>(0, (sum, item) => sum + item.speed);
    _samples = [..._samples, _totalSpeed];
    if (_samples.length > sampleWindow) {
      _samples = _samples.sublist(_samples.length - sampleWindow);
    }
    if (_totalSpeed > _peakSpeed) _peakSpeed = _totalSpeed;

    // Progress alone is cheap to lose; checkpoint it every few seconds.
    if (pending.isNotEmpty) _scheduleSave(delay: const Duration(seconds: 3));
    notifyListeners();
  }

  void _promoteQueued() {
    if (_queuePaused) return;
    var slots = _settings.maxSimultaneous - activeCount;
    if (slots <= 0) return;

    final rank = {
      for (var i = 0; i < _queueOrder.length; i++) _queueOrder[i]: i,
    };
    final queued =
        _downloads
            .where(
              (item) =>
                  item.status == DownloadStatus.queued &&
                  // Media waits until we know whether yt-dlp exists.
                  !(item.isMedia && _toolsPending),
            )
            .toList()
          ..sort((a, b) {
            final priority = b.priority.index.compareTo(a.priority.index);
            if (priority != 0) return priority;
            return (rank[a.id] ?? 1 << 20).compareTo(rank[b.id] ?? 1 << 20);
          });
    for (final item in queued) {
      if (slots-- <= 0) break;
      _start(item.id);
    }
  }

  /// Flushes the library to disk and stops every transfer (keeping partial
  /// data so the next launch resumes).
  Future<void> shutdown() async {
    stopTicking();
    _scheduleSave();
    await _store?.flush();
    await Future.wait([_http.dispose(), _media.dispose()]);
  }

  @override
  void dispose() {
    _disposed = true;
    stopTicking();
    unawaited(_store?.flush());
    unawaited(_http.dispose());
    unawaited(_media.dispose());
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Internals
  // --------------------------------------------------------------------------

  TransferEngine _engineFor(DownloadItem item) => item.isMedia ? _media : _http;

  void _start(String id) {
    final item = _find(id);
    if (item == null || _running.contains(id)) return;
    _running.add(id);
    _queueOrder = _queueOrder.where((qid) => qid != id).toList();
    _update(
      id,
      (current) => current.copyWith(
        status: DownloadStatus.downloading,
        lastActivity: DateTime.now(),
        clearFailure: true,
        clearPhase: true,
      ),
    );
    final started = _find(id)!;
    _engineFor(started).start(started, _optionsFor(started));
    _rebalanceLimits();
  }

  void _stop(DownloadItem item) {
    _running.remove(item.id);
    _pending.remove(item.id);
    unawaited(_engineFor(item).pause(item.id));
    _rebalanceLimits();
  }

  /// Effective cap: the download's own limit, or its share of the global one.
  int? _limitFor(DownloadItem item) {
    final own = AppSettings.speedLimitBytes(item.speedLimit);
    final global = AppSettings.speedLimitBytes(_settings.defaultSpeedLimit);
    final share = global == null ? null : global ~/ max(1, _running.length);
    if (own == null) return share;
    if (share == null) return own;
    return min(own, share);
  }

  void _rebalanceLimits() {
    for (final id in _running) {
      final item = _find(id);
      if (item == null) continue;
      _engineFor(item).setSpeedLimit(id, _limitFor(item));
    }
  }

  TransferOptions _optionsFor(DownloadItem item) => TransferOptions(
    userAgent: _settings.userAgent,
    proxy: _settings.proxy,
    connectionTimeout: Duration(seconds: _settings.connectionTimeout),
    requestTimeout: Duration(seconds: _settings.requestTimeout),
    retryCount: _settings.retryCount,
    retryDelay: Duration(seconds: _settings.retryDelay),
    speedLimit: _limitFor(item),
    cookiesBrowser: _settings.cookiesBrowser,
    audioQuality: _settings.audioQuality,
    embedMetadata: _settings.embedMetadata,
  );

  void _changed() {
    _scheduleSave();
    notifyListeners();
  }

  void _scheduleSave({Duration delay = const Duration(milliseconds: 800)}) {
    _store?.scheduleSave(
      delay: delay,
      () => LibrarySnapshot(
        downloads: _downloads,
        history: _history,
        settings: _settings,
        queueOrder: _queueOrder,
        queuePaused: _queuePaused,
      ),
    );
  }

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

  /// Records [item]'s outcome, replacing an earlier attempt's entry.
  void _logHistory(DownloadItem item) {
    _history = [
      HistoryEntry.fromDownload(item, durationSeconds: item.elapsedSeconds),
      for (final entry in _history)
        if (entry.id != item.id) entry,
    ];
  }

  static String _withExtension(String name, MediaFormat format) {
    final ext = '.${format.extension}';
    return name.toLowerCase().endsWith(ext) ? name : '$name$ext';
  }

  String _contentTypeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.iso')) return 'application/x-iso9660-image';
    if (lower.endsWith('.dmg')) return 'application/x-apple-diskimage';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }
}
