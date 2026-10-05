import 'dart:math';

import '../core/utils/formatters.dart';
import '../domain/models/download.dart';

/// Result of advancing the mock engine by one tick.
class TickOutcome {
  const TickOutcome({
    required this.downloads,
    required this.completed,
    required this.started,
  });

  final List<DownloadItem> downloads;

  /// Items that transitioned to `completed` during this tick.
  final List<String> completed;

  /// Queued items that were promoted to `downloading`.
  final List<String> started;
}

/// Simulated download engine.
///
/// Phase 1 stands in for the Rust engine: it advances byte counters, jitters
/// transfer rates, promotes queued downloads and finishes transfers so the UI
/// can be built against realistic, moving data. The public surface mirrors the
/// eventual FFI bridge (`tick` replaces the Rust event stream).
class MockEngine {
  const MockEngine();

  TickOutcome advance({
    required List<DownloadItem> current,
    required int maxSimultaneous,
    required bool queuePaused,
    required List<String> queueOrder,
    required Duration dt,
    required DateTime now,
    Random? random,
  }) {
    final rnd = random ?? Random();
    final seconds = dt.inMilliseconds / 1000.0;
    final completed = <String>[];
    final started = <String>[];

    final stepped = <DownloadItem>[];
    for (final item in current) {
      switch (item.status) {
        case DownloadStatus.downloading:
          stepped.add(_advanceActive(item, seconds, now, rnd));
        case DownloadStatus.verifying:
          if (now.difference(item.lastActivity).inMilliseconds > 1400) {
            completed.add(item.id);
            stepped.add(
              item.copyWith(
                status: DownloadStatus.completed,
                downloadedBytes: item.sizeBytes,
                speed: 0,
                lastActivity: now,
              ),
            );
          } else {
            stepped.add(item);
          }
        default:
          stepped.add(item);
      }
    }

    if (!queuePaused) {
      final promoted = _promoteQueued(
        stepped,
        maxSimultaneous: maxSimultaneous,
        queueOrder: queueOrder,
        now: now,
        random: rnd,
      );
      if (promoted.isNotEmpty) {
        started.addAll(promoted.map((item) => item.id));
        final byId = {for (final item in promoted) item.id: item};
        for (var i = 0; i < stepped.length; i++) {
          final replacement = byId[stepped[i].id];
          if (replacement != null) stepped[i] = replacement;
        }
      }
    }

    return TickOutcome(
      downloads: stepped,
      completed: completed,
      started: started,
    );
  }

  DownloadItem _advanceActive(
    DownloadItem item,
    double seconds,
    DateTime now,
    Random rnd,
  ) {
    final ceiling = item.baseSpeed > 0
        ? item.baseSpeed
        : (6 + rnd.nextDouble() * 18) * 1024 * 1024;
    final target = ceiling * (0.84 + rnd.nextDouble() * 0.34);
    final previous = item.speed > 0 ? item.speed : target * 0.55;
    final speed = previous + (target - previous) * 0.45;

    final advanced = (speed * seconds).round();
    final downloaded = (item.downloadedBytes + advanced).clamp(
      0,
      item.sizeBytes,
    );

    if (downloaded >= item.sizeBytes) {
      return item.copyWith(
        downloadedBytes: item.sizeBytes,
        status: DownloadStatus.completed,
        speed: 0,
        lastActivity: now,
        elapsedSeconds: item.elapsedSeconds + seconds.round(),
      );
    }

    return item.copyWith(
      downloadedBytes: downloaded,
      speed: speed,
      lastActivity: now,
      elapsedSeconds: item.elapsedSeconds + seconds.round(),
    );
  }

  List<DownloadItem> _promoteQueued(
    List<DownloadItem> downloads, {
    required int maxSimultaneous,
    required List<String> queueOrder,
    required DateTime now,
    required Random random,
  }) {
    final active = downloads
        .where((item) => item.status == DownloadStatus.downloading)
        .length;
    var slots = maxSimultaneous - active;
    if (slots <= 0) return const [];

    int rank(DownloadItem item) {
      final index = queueOrder.indexOf(item.id);
      return index < 0 ? 1 << 20 : index;
    }

    final queued =
        downloads.where((item) => item.status == DownloadStatus.queued).toList()
          ..sort((a, b) {
            final priority = b.priority.index.compareTo(a.priority.index);
            if (priority != 0) return priority;
            return rank(a).compareTo(rank(b));
          });

    final promoted = <DownloadItem>[];
    for (final item in queued) {
      if (slots == 0) break;
      final base = item.baseSpeed > 0
          ? item.baseSpeed
          : (7 + random.nextDouble() * 16) * 1024 * 1024;
      promoted.add(
        item.copyWith(
          status: DownloadStatus.downloading,
          baseSpeed: base,
          speed: base * 0.5,
          lastActivity: now,
        ),
      );
      slots--;
    }
    return promoted;
  }

  /// Seeds a plausible speed history so the analytics graph is never empty.
  static List<double> seedSamples({int count = 90, int seed = 7}) {
    final rnd = Random(seed);
    var value = 24 * 1024 * 1024.0;
    return List<double>.generate(count, (_) {
      final target = (16 + rnd.nextDouble() * 22) * 1024 * 1024;
      value += (target - value) * 0.35;
      return value;
    });
  }
}

/// Convenience: total transfer rate of every active download.
double totalSpeedOf(Iterable<DownloadItem> downloads) => downloads
    .where((item) => item.status == DownloadStatus.downloading)
    .fold<double>(0, (sum, item) => sum + item.speed);

/// Human readable aggregate used by the status bar.
String activeSummary(int active, int queued, int completed) {
  final parts = <String>[
    '$active active download${active == 1 ? '' : 's'}',
    '$queued queued',
    '$completed completed',
  ];
  return parts.join('  •  ');
}

/// Formats a byte rate for the analytics panel.
String speedLabel(double bytesPerSecond) => formatSpeed(bytesPerSecond);
