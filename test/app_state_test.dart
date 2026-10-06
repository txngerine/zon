import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zon/data/app_state.dart';
import 'package:zon/data/library_store.dart';
import 'package:zon/data/mock_data.dart';
import 'package:zon/domain/models/app_settings.dart';
import 'package:zon/domain/models/download.dart';
import 'package:zon/domain/models/media_format.dart';
import 'package:zon/domain/models/ui_state.dart';
import 'package:zon/engine/engine.dart';

/// Records what `AppState` asks of an engine; tests drive the callbacks.
class FakeEngine implements TransferEngine {
  TransferListener? listener_;
  final started = <String, TransferOptions>{};
  final paused = <String>[];
  final cancelled = <String>[];
  final limits = <String, int?>{};

  @override
  set listener(TransferListener listener) => listener_ = listener;

  @override
  void start(DownloadItem item, TransferOptions options) =>
      started[item.id] = options;

  @override
  Future<void> pause(String id) async => paused.add(id);

  @override
  Future<void> cancel(String id) async => cancelled.add(id);

  @override
  bool isRunning(String id) => started.containsKey(id);

  @override
  void setSpeedLimit(String id, int? bytesPerSecond) =>
      limits[id] = bytesPerSecond;

  @override
  Future<void> dispose() async {}
}

void main() {
  group('AppState', () {
    late FakeEngine http;
    late FakeEngine media;
    late AppState state;

    setUp(() {
      http = FakeEngine();
      media = FakeEngine();
      state = AppState(
        httpEngine: http,
        mediaEngine: media,
        downloads: MockData.downloads(),
        history: MockData.history(),
      );
    });

    tearDown(() {
      state.dispose();
    });

    DownloadItem byId(String id) =>
        state.downloads.firstWhere((item) => item.id == id);

    test('starts empty without seed data', () {
      final empty = AppState();
      addTearDown(empty.dispose);
      expect(empty.downloads, isEmpty);
      expect(empty.selected, isNull);
    });

    test('filters downloads by section', () {
      state.setSection(AppSection.active);
      expect(
        state.visibleDownloads.every(
          (item) =>
              item.status == DownloadStatus.downloading ||
              item.status == DownloadStatus.verifying,
        ),
        isTrue,
      );

      state.setSection(AppSection.queued);
      expect(
        state.visibleDownloads.every(
          (item) => item.status == DownloadStatus.queued,
        ),
        isTrue,
      );
    });

    test('sorts downloads by name and size', () {
      state.setSort(SortOption.name);
      final names = state.visibleDownloads.map(
        (item) => item.fileName.toLowerCase(),
      );
      expect(names, orderedEquals([...names]..sort()));

      state.setSort(SortOption.size);
      final sizes = state.visibleDownloads.map((item) => item.sizeBytes);
      expect(sizes, orderedEquals([...sizes]..sort((a, b) => b.compareTo(a))));
    });

    test('search narrows the visible list', () {
      final before = state.downloads.length;
      state.setDownloadQuery('windows');
      expect(state.visibleDownloads.length, lessThan(before));
      expect(state.visibleDownloads.first.fileName, contains('Windows'));
      state.setDownloadQuery('');
      expect(state.visibleDownloads.length, before);
    });

    test('tick hands active downloads to the engine and applies progress', () {
      state.tick(dt: const Duration(milliseconds: 400));
      final active = state.downloads
          .where((item) => item.status == DownloadStatus.downloading)
          .toList();
      expect(active, isNotEmpty);
      for (final item in active) {
        expect(http.started, contains(item.id));
      }

      final item = active.first;
      http.listener_!.onProgress(
        item.id,
        item.downloadedBytes + 1000,
        2048,
        total: item.sizeBytes,
      );
      state.tick(dt: const Duration(seconds: 1));

      expect(byId(item.id).downloadedBytes, item.downloadedBytes + 1000);
      expect(byId(item.id).speed, 2048);
      expect(state.totalSpeed, greaterThanOrEqualTo(2048));
      expect(state.speedSamples.length, AppState.sampleWindow);
    });

    test('queue promotes downloads while slots are free', () {
      state.pauseAll();
      expect(state.activeCount, 0);
      expect(http.paused, isNotEmpty);

      state.tick(dt: const Duration(milliseconds: 400));

      expect(state.activeCount, greaterThan(0));
      expect(
        state.activeCount,
        lessThanOrEqualTo(state.settings.maxSimultaneous),
      );
    });

    test('paused queue does not promote', () {
      state.pauseAll();
      state.pauseQueue();
      state.tick();
      expect(state.activeCount, 0);
    });

    test('completion records the file, history and leaves the engine', () {
      state.tick();
      final item = state.downloads.firstWhere(
        (item) => item.status == DownloadStatus.downloading,
      );
      http.listener_!.onCompleted(item.id, '/tmp/zon/${item.fileName}');

      final done = byId(item.id);
      expect(done.status, DownloadStatus.completed);
      expect(done.filePath, '/tmp/zon/${item.fileName}');
      expect(state.history.first.id, item.id);
      expect(state.history.first.status, DownloadStatus.completed);
      expect(state.toast, contains('Completed'));
    });

    test('failures keep the reason and can be retried', () {
      state.tick();
      final item = state.downloads.firstWhere(
        (item) => item.status == DownloadStatus.downloading,
      );
      http.listener_!.onFailed(item.id, 'Server responded 503');

      expect(byId(item.id).status, DownloadStatus.failed);
      expect(byId(item.id).failureReason, 'Server responded 503');

      http.started.clear();
      state.resumeDownload(item.id);
      expect(byId(item.id).status, DownloadStatus.downloading);
      expect(byId(item.id).failureReason, isNull);
      expect(http.started, contains(item.id));
    });

    test('late callbacks from a paused transfer are ignored', () {
      state.tick();
      final item = state.downloads.firstWhere(
        (item) => item.status == DownloadStatus.downloading,
      );
      state.pauseDownload(item.id);
      http.listener_!.onFailed(item.id, 'Connection reset');
      expect(byId(item.id).status, DownloadStatus.paused);
    });

    test('cancelled transfers are recorded in history', () {
      final historyBefore = state.history.length;
      final item = state.downloads.firstWhere(
        (item) => item.status == DownloadStatus.downloading,
      );

      state.cancelDownload(item.id);

      expect(http.cancelled, contains(item.id));
      expect(state.history.length, historyBefore + 1);
      expect(state.history.first.id, item.id);
      expect(state.history.first.status, DownloadStatus.cancelled);
    });

    test('pauseAll and resumeAll move downloads between states', () {
      state.pauseAll();
      expect(state.activeCount, 0);
      expect(state.pausedCount, greaterThan(0));

      state.resumeAll();
      expect(state.activeCount, greaterThan(0));
      expect(
        state.activeCount,
        lessThanOrEqualTo(state.settings.maxSimultaneous),
      );
    });

    test('Start now force-starts a queued download', () {
      final queued = state.queuedDownloads.first;
      state.resumeDownload(queued.id);
      expect(byId(queued.id).status, DownloadStatus.downloading);
      expect(http.started, contains(queued.id));
    });

    test('priority reorders the queue', () {
      final queued = state.queuedDownloads.first;
      state.setPriority(queued.id, DownloadPriority.high);
      expect(byId(queued.id).priority, DownloadPriority.high);
    });

    test('reorderQueue moves an item to a new position', () {
      final before = state.queuedDownloads.map((item) => item.id).toList();
      expect(before.length, greaterThanOrEqualTo(2));

      state.reorderQueue(0, 1);
      final after = state.queuedDownloads.map((item) => item.id).toList();

      expect(after, isNot(orderedEquals(before)));
      expect(after.toSet(), before.toSet());
    });

    test('createDownload routes files to the HTTP engine', () {
      final fresh = AppState(httpEngine: http, mediaEngine: media);
      addTearDown(fresh.dispose);
      final item = fresh.createDownload(
        url: 'https://example.com/large-file.iso',
        savePath: '/tmp/zon',
        connections: 24,
        speedLimit: '5 MB/s',
      );

      expect(item.fileName, 'large-file.iso');
      expect(item.kind, DownloadKind.file);
      expect(item.connections, 24);
      expect(item.status, DownloadStatus.downloading);
      expect(fresh.selected?.id, item.id);
      expect(http.started[item.id]?.speedLimit, 5 * 1024 * 1024);
      expect(media.started, isEmpty);
    });

    test('YouTube, Reels and TikTok links become media downloads', () {
      final fresh = AppState(httpEngine: http, mediaEngine: media);
      addTearDown(fresh.dispose);

      final video = fresh.createDownload(
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(video.kind, DownloadKind.media);
      expect(video.mediaFormat, MediaFormat.videoBest);
      expect(video.source, 'YouTube');

      final reel = fresh.createDownload(
        url: 'https://www.instagram.com/reel/C5Ffz3xLJ5S/',
        mediaFormat: MediaFormat.audioMp3,
        fileName: 'my song',
      );
      expect(reel.kind, DownloadKind.media);
      expect(reel.fileName, 'my song.mp3');
      expect(reel.nameLocked, isTrue);

      final tiktok = fresh.createDownload(
        url: 'https://www.tiktok.com/@user/video/123',
      );
      expect(tiktok.source, 'TikTok');
      expect(media.started.keys, containsAll([video.id, reel.id]));
    });

    test('global speed limit is shared between active downloads', () {
      final fresh = AppState(httpEngine: http, mediaEngine: media);
      addTearDown(fresh.dispose);
      final a = fresh.createDownload(url: 'https://example.com/a.zip');
      final b = fresh.createDownload(url: 'https://example.com/b.zip');

      fresh.setSpeedLimit('10 MB/s');

      expect(http.limits[a.id], 5 * 1024 * 1024);
      expect(http.limits[b.id], 5 * 1024 * 1024);
    });

    test('speed limit and settings updates are reflected', () {
      state.setSpeedLimit('5 MB/s');
      expect(state.settings.defaultSpeedLimit, '5 MB/s');

      state.updateSettings(state.settings.copyWith(maxSimultaneous: 6));
      expect(state.settings.maxSimultaneous, 6);

      state.resetSettings();
      expect(
        state.settings.maxSimultaneous,
        AppSettings.defaults.maxSimultaneous,
      );
      expect(state.settings.defaultSpeedLimit, 'No Limit');
    });

    test('clearing the queue removes queued downloads only', () {
      final queuedIds = state.queuedDownloads.map((item) => item.id).toSet();
      expect(queuedIds, isNotEmpty);

      state.clearQueue();

      expect(state.queuedCount, 0);
      expect(
        state.downloads.any((item) => queuedIds.contains(item.id)),
        isFalse,
      );
      expect(state.activeCount, greaterThan(0));
    });

    test('clipboard links are offered once', () {
      expect(state.takeClipboardLink('https://youtu.be/abc'), isNotNull);
      expect(state.takeClipboardLink('https://youtu.be/abc'), isNull);
      expect(state.takeClipboardLink('not a link'), isNull);
      expect(state.takeClipboardLink('https://a.com/x y'), isNull);
    });
  });

  group('LibraryStore', () {
    test('round-trips downloads, history and settings', () async {
      final dir = await Directory.systemTemp.createTemp('zon_store_');
      addTearDown(() => dir.delete(recursive: true));
      final store = LibraryStore(File('${dir.path}/library.json'));

      final downloads = MockData.downloads();
      final settings = AppSettings.defaults.copyWith(
        maxSimultaneous: 5,
        cookiesBrowser: 'Firefox',
        defaultMediaFormat: MediaFormat.audioMp3,
      );
      store.scheduleSave(
        () => LibrarySnapshot(
          downloads: downloads,
          history: MockData.history(),
          settings: settings,
          queueOrder: const ['z-004'],
          queuePaused: true,
        ),
      );
      await store.flush();

      final loaded = await LibraryStore(File('${dir.path}/library.json'))
          .load();
      expect(loaded, isNotNull);
      expect(loaded!.downloads.length, downloads.length);
      expect(loaded.downloads.first.fileName, downloads.first.fileName);
      expect(loaded.downloads.first.status, downloads.first.status);
      expect(loaded.settings.maxSimultaneous, 5);
      expect(loaded.settings.cookiesBrowser, 'Firefox');
      expect(loaded.settings.defaultMediaFormat, MediaFormat.audioMp3);
      expect(loaded.queueOrder, ['z-004']);
      expect(loaded.queuePaused, isTrue);
    });

    test(
      'constant updates still get written (throttle, not debounce)',
      () async {
        final dir = await Directory.systemTemp.createTemp('zon_store_');
        final file = File('${dir.path}/library.json');
        final store = LibraryStore(file);
        addTearDown(() async {
          await store.flush();
          await dir.delete(recursive: true);
        });
        LibrarySnapshot snapshot() => LibrarySnapshot(
          downloads: MockData.downloads(),
          history: const [],
          settings: AppSettings.defaults,
          queueOrder: const [],
        );

        // A save request every 100ms, like the scheduler during transfers.
        for (var i = 0; i < 12; i++) {
          store.scheduleSave(
            snapshot,
            delay: const Duration(milliseconds: 300),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(file.existsSync(), isTrue);
      },
    );

    test('a corrupt file loads as empty instead of crashing', () async {
      final dir = await Directory.systemTemp.createTemp('zon_store_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/library.json')..writeAsStringSync('{oops');
      expect(await LibraryStore(file).load(), isNull);
      expect(File('${file.path}.corrupt').existsSync(), isTrue);
    });
  });
}
