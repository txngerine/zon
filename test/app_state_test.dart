import 'package:flutter_test/flutter_test.dart';
import 'package:zon/data/app_state.dart';
import 'package:zon/domain/models/app_settings.dart';
import 'package:zon/domain/models/download.dart';
import 'package:zon/domain/models/ui_state.dart';

void main() {
  group('AppState', () {
    late AppState state;

    setUp(() {
      state = AppState();
    });

    tearDown(() {
      state.dispose();
    });

    test('seeds a realistic library covering every state', () {
      expect(state.downloads.length, greaterThanOrEqualTo(10));
      expect(state.activeCount, greaterThanOrEqualTo(1));
      expect(state.queuedCount, greaterThanOrEqualTo(1));
      expect(
        state.downloads.map((item) => item.status).toSet(),
        containsAll([
          DownloadStatus.downloading,
          DownloadStatus.queued,
          DownloadStatus.completed,
          DownloadStatus.failed,
          DownloadStatus.paused,
        ]),
      );
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

      state.setSection(AppSection.completed);
      expect(
        state.visibleDownloads.every(
          (item) => item.status == DownloadStatus.completed,
        ),
        isTrue,
      );
    });

    test('sorts downloads by name and size', () {
      state.setSort(SortOption.name);
      final names = state.visibleDownloads.map(
        (item) => item.fileName.toLowerCase(),
      );
      final sorted = [...names]..sort();
      expect(names, orderedEquals(sorted));

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

    test('tick advances active transfers and keeps totals consistent', () {
      final before = state.activeCount;
      final item = state.downloads.firstWhere(
        (item) => item.status == DownloadStatus.downloading,
      );
      final startBytes = item.downloadedBytes;

      state.tick(dt: const Duration(seconds: 1));

      final after = state.downloads.firstWhere((item) => item.id == item.id);
      expect(after.downloadedBytes, greaterThan(startBytes));
      expect(state.activeCount, before);
      expect(state.totalSpeed, greaterThan(0));
      expect(state.speedSamples.length, AppState.sampleWindow);
    });

    test('queue promotes downloads while slots are free', () {
      state.pauseAll();
      expect(state.activeCount, 0);

      state.tick(dt: const Duration(milliseconds: 400));

      expect(state.activeCount, greaterThan(0));
      expect(
        state.activeCount,
        lessThanOrEqualTo(state.settings.maxSimultaneous),
      );
    });

    test('cancelled transfers are recorded in history', () {
      final historyBefore = state.history.length;
      final item = state.downloads.firstWhere(
        (item) => item.status == DownloadStatus.downloading,
      );

      state.cancelDownload(item.id);

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

    test('priority reorders the queue', () {
      final queued = state.queuedDownloads.first;
      state.setPriority(queued.id, DownloadPriority.high);
      expect(
        state.downloads.firstWhere((item) => item.id == queued.id).priority,
        DownloadPriority.high,
      );
    });

    test('reorderQueue moves an item to a new position', () {
      final before = state.queuedDownloads.map((item) => item.id).toList();
      expect(before.length, greaterThanOrEqualTo(2));

      state.reorderQueue(0, 1);
      final after = state.queuedDownloads.map((item) => item.id).toList();

      expect(after.length, before.length);
      expect(after, isNot(orderedEquals(before)));
      expect(after.toSet(), before.toSet());
    });

    test('createDownload adds a selected, transferring download', () {
      final count = state.downloads.length;
      final item = state.createDownload(
        url: 'https://example.com/large-file.iso',
        connections: 24,
      );

      expect(state.downloads.length, count + 1);
      expect(item.fileName, 'large-file.iso');
      expect(item.connections, 24);
      expect(state.selected?.id, item.id);
      expect(
        item.status == DownloadStatus.downloading ||
            item.status == DownloadStatus.queued,
        isTrue,
      );
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
  });
}
