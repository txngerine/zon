import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zon/data/app_state.dart';
import 'package:zon/domain/models/app_settings.dart';
import 'package:zon/domain/models/download.dart';
import 'package:zon/engine/engine.dart';
import 'package:zon/engine/torrent/torrent_engine.dart';
import 'package:zon/platform/local_api.dart';
import 'package:zon/presentation/shell/zon_shell.dart';

import 'app_state_test.dart' show FakeEngine;

const _magnet =
    'magnet:?xt=urn:btih:08ada5a7a6183aae1e09d831df6748d566095a10'
    '&dn=Sintel%20Movie&tr=udp%3A%2F%2Fexplodie.org%3A6969';

void main() {
  group('torrent links', () {
    test('isTorrentLink accepts magnets and .torrent files only', () {
      expect(isTorrentLink(_magnet), isTrue);
      expect(isTorrentLink('https://a.org/x/ubuntu.iso.torrent'), isTrue);
      expect(isTorrentLink('/Users/me/Downloads/file.torrent'), isTrue);
      expect(isTorrentLink('https://a.org/x/ubuntu.iso'), isFalse);
      expect(isTorrentLink('https://youtu.be/abc'), isFalse);
    });

    test('torrentDisplayName prefers dn, then file name, then hash', () {
      expect(torrentDisplayName(_magnet), 'Sintel Movie');
      expect(
        torrentDisplayName('magnet:?xt=urn:btih:ABCDEF1234567890'),
        'Torrent ABCDEF12',
      );
      expect(
        torrentDisplayName('https://a.org/dl/Big%20Buck%20Bunny.torrent'),
        'Big Buck Bunny',
      );
      expect(torrentDisplayName(r'C:\Users\me\debian.torrent'), 'debian');
    });

    test('extractLinks finds magnet links in pasted text', () {
      expect(extractLinks('grab this: $_magnet thanks'), [_magnet]);
    });
  });

  group('AppState torrents', () {
    late FakeEngine torrent;
    late AppState state;

    setUp(() {
      torrent = FakeEngine();
      state = AppState(
        httpEngine: FakeEngine(),
        mediaEngine: FakeEngine(),
        torrentEngine: torrent,
      );
    });

    tearDown(() => state.dispose());

    test('magnets go to the torrent engine with seeding options', () {
      state.updateSettings(
        state.settings.copyWith(seedAfterDownload: true, seedRatio: '2.0'),
      );
      final item = state.createDownload(url: _magnet, savePath: '/tmp/zon');
      expect(item.kind, DownloadKind.torrent);
      expect(item.fileName, 'Sintel Movie');
      expect(item.source, 'BitTorrent');
      expect(torrent.started[item.id]?.seedRatio, 2.0);
    });

    test('turning seeding off stops at 100%', () {
      state.updateSettings(state.settings.copyWith(seedAfterDownload: false));
      final item = state.createDownload(url: _magnet, savePath: '/tmp/zon');
      expect(torrent.started[item.id]?.seedRatio, isNull);
    });

    test('swarm stats from the engine land on the item', () {
      final item = state.createDownload(url: _magnet, savePath: '/tmp/zon');
      torrent.listener_!.onMeta(
        item.id,
        const TransferMeta(
          fileName: 'Sintel',
          connections: 12,
          seeders: 7,
          uploadSpeed: 2048,
        ),
      );
      final updated = state.downloads.firstWhere((d) => d.id == item.id);
      expect(updated.fileName, 'Sintel');
      expect(updated.connections, 12);
      expect(updated.seeders, 7);
      expect(updated.uploadSpeed, 2048);
    });

    test('a stalled torrent stops blocking the queue', () {
      state.updateSettings(state.settings.copyWith(maxSimultaneous: 1));
      final dead = state.createDownload(url: _magnet, savePath: '/tmp/zon');
      expect(dead.status, DownloadStatus.downloading);

      final file = state.createDownload(
        url: 'https://example.com/a.zip',
        savePath: '/tmp/zon',
      );
      expect(file.status, DownloadStatus.queued);

      // Nothing has arrived for longer than the stall window.
      state.stalledAfter = Duration.zero;
      state.tick();
      expect(
        state.downloads.firstWhere((d) => d.id == file.id).status,
        DownloadStatus.downloading,
      );
    });

    test('magnet links on the clipboard are offered', () {
      expect(state.takeClipboardLink(_magnet), _magnet);
    });

    test('reset keeps the bookmarklet key', () {
      state.updateSettings(state.settings.copyWith(apiToken: 'secret'));
      state.resetSettings();
      expect(state.settings.apiToken, 'secret');
      expect(state.settings.seedRatio, AppSettings.defaults.seedRatio);
    });
  });

  group('LocalApiServer', () {
    late LocalApiServer server;
    final added = <String>[];
    final files = <String>[];

    setUp(() async {
      added.clear();
      files.clear();
      server = LocalApiServer(
        port: 16412,
        token: () => 'k3y',
        onAdd: (url, _) => added.add(url),
        onAddFile: files.add,
      );
      expect(await server.start(), isTrue);
    });

    tearDown(() => server.stop());

    Future<int> get(String query) async {
      final client = HttpClient();
      try {
        final response = await (await client.getUrl(
          Uri.parse('http://127.0.0.1:16412/add?$query'),
        )).close();
        await response.drain<void>();
        return response.statusCode;
      } finally {
        client.close();
      }
    }

    test('requests without the key are refused', () async {
      expect(await get('url=https%3A%2F%2Fevil.example%2Fx.exe'), 403);
      expect(await get('t=wrong&url=https%3A%2F%2Fevil.example%2Fx.exe'), 403);
      expect(added, isEmpty);
    });

    test('keyed requests add links, magnets and .torrent files', () async {
      expect(await get('t=k3y&url=https%3A%2F%2Fa.org%2Ff.zip'), 200);
      expect(await get('t=k3y&url=${Uri.encodeQueryComponent(_magnet)}'), 200);
      expect(await get('t=k3y&url=file%3A%2F%2F%2Fetc%2Fpasswd'), 400);
      expect(await get('t=k3y&path=%2Ftmp%2Fa.torrent'), 200);
      expect(await get('t=k3y&path=%2Fetc%2Fpasswd'), 400);
      expect(added, ['https://a.org/f.zip', _magnet]);
      expect(files, ['/tmp/a.torrent']);
    });

    test('forward() hands links to a running instance', () async {
      expect(
        await LocalApiServer.forward(_magnet, token: 'k3y', port: 16412),
        isTrue,
      );
      expect(
        await LocalApiServer.forward(_magnet, token: 'nope', port: 16412),
        isFalse,
      );
      expect(added, [_magnet]);
    });

    test('bookmarklet embeds the key', () {
      expect(LocalApiServer.bookmarklet(token: 'k3y'), contains('t=k3y'));
    });
  });
}
