// Renders the marketing screenshots for site/ from the real UI, seeded with
// a demo library instead of anyone's actual downloads.
//
//   flutter test tool/screenshots/site_screenshots_test.dart
//   python3 tool/screenshots/crop.py   # build/site_shots -> site/public/shots
//
// Runs on macOS only: it borrows the system San Francisco font so the shots
// look like the native app rather than the test font.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zon/app.dart';
import 'package:zon/data/app_state.dart';
import 'package:zon/domain/models/app_settings.dart';
import 'package:zon/domain/models/download.dart';
import 'package:zon/domain/models/media_format.dart';
import 'package:zon/domain/models/ui_state.dart';
import 'package:zon/engine/media/ytdlp.dart';
import 'package:zon/presentation/dialogs/add_download_dialog.dart';
import 'package:zon/presentation/shell/zon_shell.dart';

const _out = 'build/site_shots';
const _gb = 1024 * 1024 * 1024;
const _mb = 1024 * 1024;

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  const sf = '/System/Library/Fonts/SFNS.ttf';
  await _loadFont('Roboto', [sf]);
  await _loadFont('.AppleSystemUIFont', [sf]);
  await _loadFont('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

DownloadItem _item({
  required String id,
  required String fileName,
  required String url,
  required String source,
  required int size,
  required double progress,
  required DownloadStatus status,
  double speed = 0,
  int connections = 16,
  int minutesAgo = 0,
  DownloadKind kind = DownloadKind.file,
  MediaFormat? format,
  String server = 'cloudflare',
  String contentType = 'application/octet-stream',
  int elapsed = 0,
  int seeders = 0,
  double upload = 0,
  String? phase,
  String? failure,
  DownloadPriority priority = DownloadPriority.normal,
}) {
  final now = DateTime.now();
  return DownloadItem(
    id: id,
    fileName: fileName,
    url: url,
    source: source,
    sizeBytes: size,
    downloadedBytes: (size * progress).round(),
    status: status,
    speed: speed,
    baseSpeed: speed,
    connections: connections,
    savePath: '~/Downloads',
    filePath: status == DownloadStatus.completed
        ? '~/Downloads/$fileName'
        : null,
    addedAt: now.subtract(Duration(minutes: minutesAgo)),
    lastActivity: now,
    elapsedSeconds: elapsed,
    httpStatus: kind == DownloadKind.file ? 206 : 0,
    server: server,
    contentType: contentType,
    kind: kind,
    mediaFormat: format,
    seeders: seeders,
    uploadSpeed: upload,
    phase: phase,
    failureReason: failure,
    priority: priority,
  );
}

List<DownloadItem> _demoDownloads() => [
  _item(
    id: 'd1',
    fileName: 'ubuntu-24.04.3-desktop-amd64.iso',
    url: 'https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-desktop-amd64.iso',
    source: 'releases.ubuntu.com',
    size: (6.1 * _gb).round(),
    progress: 0.64,
    status: DownloadStatus.downloading,
    speed: 31.4 * _mb,
    connections: 32,
    minutesAgo: 1,
    server: 'Apache',
    contentType: 'application/x-iso9660-image',
    elapsed: 131,
  ),
  _item(
    id: 'd2',
    fileName: 'Big Buck Bunny 4K.mp4',
    url: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
    source: 'YouTube',
    size: 1268 * _mb,
    progress: 0.41,
    status: DownloadStatus.downloading,
    speed: 11.8 * _mb,
    connections: 1,
    minutesAgo: 2,
    kind: DownloadKind.media,
    format: MediaFormat.video2160,
    server: 'googlevideo.com',
    contentType: 'video/mp4',
    elapsed: 44,
  ),
  _item(
    id: 'd3',
    fileName: 'archlinux-2026.10.01-x86_64.iso',
    url: 'magnet:?xt=urn:btih:6c2d7ff1c6e1e9b0a3a0ef4e2b1f4f9e2d1c0b9a&dn=archlinux-2026.10.01-x86_64.iso',
    source: 'BitTorrent',
    size: 1214 * _mb,
    progress: 0.83,
    status: DownloadStatus.downloading,
    speed: 7.6 * _mb,
    connections: 48,
    seeders: 212,
    upload: 940 * 1024,
    minutesAgo: 3,
    kind: DownloadKind.torrent,
    server: 'aria2',
    contentType: 'application/x-bittorrent',
    elapsed: 160,
  ),
  _item(
    id: 'd4',
    fileName: 'Lofi Study Mix.mp3',
    url: 'https://soundcloud.com/lofi-girl/study-mix',
    source: 'SoundCloud',
    size: 142 * _mb,
    progress: 1,
    status: DownloadStatus.verifying,
    connections: 1,
    minutesAgo: 4,
    kind: DownloadKind.media,
    format: MediaFormat.audioMp3,
    contentType: 'audio/mpeg',
    phase: 'Converting to MP3',
  ),
  _item(
    id: 'd5',
    fileName: 'Xcode_26.1.xip',
    url: 'https://download.developer.apple.com/Developer_Tools/Xcode_26.1/Xcode_26.1.xip',
    source: 'developer.apple.com',
    size: (3.4 * _gb).round(),
    progress: 0,
    status: DownloadStatus.queued,
    minutesAgo: 6,
    priority: DownloadPriority.high,
  ),
  _item(
    id: 'd6',
    fileName: 'blender-4.5.3-macos-arm64.dmg',
    url: 'https://download.blender.org/release/Blender4.5/blender-4.5.3-macos-arm64.dmg',
    source: 'download.blender.org',
    size: 412 * _mb,
    progress: 0.37,
    status: DownloadStatus.paused,
    minutesAgo: 18,
    server: 'nginx',
    contentType: 'application/x-apple-diskimage',
    elapsed: 39,
  ),
  _item(
    id: 'd7',
    fileName: 'Docker.dmg',
    url: 'https://desktop.docker.com/mac/main/arm64/Docker.dmg',
    source: 'desktop.docker.com',
    size: 560 * _mb,
    progress: 1,
    status: DownloadStatus.completed,
    minutesAgo: 26,
    server: 'AmazonS3',
    contentType: 'application/octet-stream',
    elapsed: 21,
  ),
  _item(
    id: 'd8',
    fileName: 'VSCode-darwin-arm64.zip',
    url: 'https://update.code.visualstudio.com/latest/darwin-arm64/stable',
    source: 'update.code.visualstudio.com',
    size: 303 * _mb,
    progress: 1,
    status: DownloadStatus.completed,
    minutesAgo: 41,
    server: 'Windows-Azure-Blob',
    contentType: 'application/zip',
    elapsed: 12,
  ),
];

List<HistoryEntry> _demoHistory() {
  final now = DateTime.now();
  HistoryEntry entry(
    String id,
    String name,
    String url,
    String source,
    DownloadStatus status,
    int size,
    Duration ago,
    int seconds, {
    DownloadKind kind = DownloadKind.file,
    MediaFormat? format,
  }) => HistoryEntry(
    id: id,
    fileName: name,
    url: url,
    source: source,
    status: status,
    sizeBytes: size,
    downloadedBytes: status == DownloadStatus.completed ? size : size ~/ 3,
    date: now.subtract(ago),
    durationSeconds: seconds,
    savePath: '~/Downloads',
    kind: kind,
    mediaFormat: format,
  );
  const done = DownloadStatus.completed;
  return [
    entry(
      'h1',
      'Docker.dmg',
      'https://desktop.docker.com/mac/main/arm64/Docker.dmg',
      'desktop.docker.com',
      done,
      560 * _mb,
      const Duration(minutes: 26),
      21,
    ),
    entry(
      'h2',
      'VSCode-darwin-arm64.zip',
      'https://update.code.visualstudio.com/latest/darwin-arm64/stable',
      'update.code.visualstudio.com',
      done,
      303 * _mb,
      const Duration(minutes: 41),
      12,
    ),
    entry(
      'h3',
      'Tears of Steel 1080p.mp4',
      'https://vimeo.com/1084537',
      'Vimeo',
      done,
      734 * _mb,
      const Duration(hours: 3),
      58,
      kind: DownloadKind.media,
      format: MediaFormat.video1080,
    ),
    entry(
      'h4',
      'debian-13.1.0-amd64-netinst.iso',
      'magnet:?xt=urn:btih:debian-13.1.0',
      'BitTorrent',
      done,
      754 * _mb,
      const Duration(hours: 5),
      96,
      kind: DownloadKind.torrent,
    ),
    entry(
      'h5',
      'Podcast Episode 212.m4a',
      'https://www.youtube.com/watch?v=pod212',
      'YouTube',
      done,
      61 * _mb,
      const Duration(hours: 9),
      7,
      kind: DownloadKind.media,
      format: MediaFormat.audioM4a,
    ),
    entry(
      'h6',
      'node-v24.10.0.pkg',
      'https://nodejs.org/dist/v24.10.0/node-v24.10.0.pkg',
      'nodejs.org',
      done,
      78 * _mb,
      const Duration(days: 1),
      5,
    ),
    entry(
      'h7',
      'unreal-engine-5.6-source.zip',
      'https://github.com/EpicGames/UnrealEngine/archive/5.6.zip',
      'github.com',
      DownloadStatus.failed,
      (2.8 * _gb).round(),
      const Duration(days: 1, hours: 2),
      310,
    ),
    entry(
      'h8',
      'Firefox 144.0.dmg',
      'https://download.mozilla.org/?product=firefox-latest&os=osx',
      'download.mozilla.org',
      done,
      142 * _mb,
      const Duration(days: 2),
      9,
    ),
    entry(
      'h9',
      'GIMP-3.0.6-arm64.dmg',
      'https://download.gimp.org/gimp/v3.0/macos/gimp-3.0.6-arm64.dmg',
      'download.gimp.org',
      done,
      351 * _mb,
      const Duration(days: 3),
      24,
    ),
    entry(
      'h10',
      'Synthwave Radio.mp3',
      'https://www.youtube.com/watch?v=synth',
      'YouTube',
      DownloadStatus.cancelled,
      48 * _mb,
      const Duration(days: 4),
      3,
      kind: DownloadKind.media,
      format: MediaFormat.audioMp3,
    ),
  ];
}

/// yt-dlp and ffmpeg "installed", answering probes with a canned video.
class _FakeTools implements MediaTools {
  @override
  bool get hasYtDlp => true;
  @override
  bool get hasFfmpeg => true;
  @override
  bool get hasAria2 => true;
  @override
  bool get resolved => true;
  @override
  String? get version => '2026.10.10';
  @override
  bool get isManaged => true;
  @override
  String get binDir => '~/Library/Application Support/zon/bin';
  @override
  String? get ytDlpPath => '$binDir/yt-dlp';
  @override
  String? get ffmpegPath => '$binDir/ffmpeg';
  @override
  String? get aria2Path => '/opt/homebrew/bin/aria2c';

  @override
  Future<MediaInfo> probe(
    String url, {
    String cookiesBrowser = 'None',
    String proxy = '',
  }) async => const MediaInfo(
    title: 'Big Buck Bunny 60fps 4K - Official Blender Foundation Short Film',
    site: 'YouTube',
    uploader: 'Blender',
    duration: Duration(minutes: 10, seconds: 34),
    sizeEstimate: 1268 * _mb,
    maxHeight: 2160,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Feeds the speed graph with a believable, wobbly history.
void _warmUp(AppState state) {
  final rng = Random(7);
  final active = state.downloads
      .where((d) => d.status == DownloadStatus.downloading)
      .toList();
  // Extra ticks push the graph's empty start out of the window.
  for (var t = 0; t < AppState.sampleWindow + 20; t++) {
    const ramp = 1.0;
    for (final item in active) {
      final wave = 0.82 + 0.18 * sin(t / 6 + item.id.hashCode % 5);
      final noise = 0.9 + rng.nextDouble() * 0.2;
      final speed = item.baseSpeed * ramp * wave * noise;
      final grown =
          item.downloadedBytes - ((AppState.sampleWindow - t) * 2 * _mb);
      state.onProgress(item.id, max(grown, 1), speed, total: item.sizeBytes);
    }
    // A test in all but location (it lives outside test/ so CI skips it).
    // ignore: invalid_use_of_visible_for_testing_member
    state.tick(dt: const Duration(milliseconds: 400));
  }
}

// Asset images decode off the fake clock, so wait for them for real.
Future<void> precacheImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pump();
}

void main() {
  final boundary = GlobalKey();

  setUpAll(_loadFonts);

  Future<AppState> pump(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
    ThemePreference theme = ThemePreference.dark,
    String? select,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final state = AppState(
      downloads: _demoDownloads(),
      history: _demoHistory(),
      settings: AppSettings.defaults.copyWith(theme: theme, maxSimultaneous: 3),
      mediaTools: _FakeTools(),
    );
    // Tests swap shadows for flat bands by default; draw the real ones.
    debugDisableShadows = false;
    addTearDown(state.dispose);
    _warmUp(state);
    if (select != null) state.select(select);

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ZonApp(state: state),
      ),
    );
    // Past the splash screen and every entrance animation.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(seconds: 2));
    await precacheImages(tester);
    return state;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await precacheImages(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_out/$name.png')..createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  // Desktop look (scrollbars, hover) rather than the default Android one.
  void shot(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(
        name,
        body,
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    debugDisableShadows = true;
  }

  shot('dashboard (dark)', (tester) async {
    await pump(tester, select: 'd1');
    await capture(tester, 'dashboard-dark');
    await finish(tester);
  });

  shot('dashboard (light)', (tester) async {
    await pump(tester, theme: ThemePreference.light, select: 'd1');
    await capture(tester, 'dashboard-light');
    await finish(tester);
  });

  shot('torrent details', (tester) async {
    await pump(tester, select: 'd3');
    await capture(tester, 'torrent');
    await finish(tester);
  });

  shot('media details', (tester) async {
    await pump(tester, select: 'd2');
    await capture(tester, 'media');
    await finish(tester);
  });

  shot('history', (tester) async {
    final state = await pump(tester);
    state.setSection(AppSection.history);
    await settle(tester);
    await capture(tester, 'history');
    await finish(tester);
  });

  shot('settings', (tester) async {
    final state = await pump(tester);
    state.setSection(AppSection.settings);
    await settle(tester);
    await capture(tester, 'settings');
    await finish(tester);
  });

  shot('media dialog', (tester) async {
    final state = await pump(tester, select: 'd2');
    unawaited(
      AddDownloadDialog.show(
        tester.element(find.byType(ZonShell)),
        state: state,
        mode: AddDownloadMode.media,
        initialUrl: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
      ),
    );
    await settle(tester);
    await capture(tester, 'media-dialog');
    await finish(tester);
  });
}
