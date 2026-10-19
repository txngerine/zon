import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zon/core/theme/app_theme.dart';
import 'package:zon/domain/models/download.dart';
import 'package:zon/engine/torrent/torrent_manifest.dart';
import 'package:zon/presentation/dialogs/torrent_file_picker.dart';

/// Minimal bencode writer for building test torrents.
List<int> bencode(Object value) {
  final out = BytesBuilder();
  void write(Object value) {
    switch (value) {
      case int():
        out.add(ascii.encode('i${value}e'));
      case String():
        final bytes = utf8.encode(value);
        out.add(ascii.encode('${bytes.length}:'));
        out.add(bytes);
      case List():
        out.addByte(0x6c);
        for (final item in value) {
          write(item as Object);
        }
        out.addByte(0x65);
      case Map():
        out.addByte(0x64);
        final keys = value.keys.cast<String>().toList()..sort();
        for (final key in keys) {
          write(key);
          write(value[key] as Object);
        }
        out.addByte(0x65);
    }
  }

  write(value);
  return out.takeBytes();
}

List<int> multiFileTorrent(int count) => bencode({
  'announce': 'udp://tracker.example:1337',
  'info': {
    'name': 'Big Pack',
    'piece length': 262144,
    'pieces': '',
    'files': [
      for (var i = 0; i < count; i++)
        {
          'length': 1000 + i,
          'path': ['Season ${i ~/ 100 + 1}', 'Episode $i.mkv'],
        },
    ],
  },
});

void main() {
  group('TorrentManifest', () {
    test('reads a single-file torrent', () {
      final manifest = TorrentManifest.parse(
        bencode({
          'info': {'name': 'ubuntu.iso', 'length': 6000, 'pieces': ''},
        }),
      );
      expect(manifest.name, 'ubuntu.iso');
      expect(manifest.files.single.index, 1);
      expect(manifest.files.single.length, 6000);
    });

    test('reads nested files in order with 1-based indexes', () {
      final manifest = TorrentManifest.parse(multiFileTorrent(250));
      expect(manifest.name, 'Big Pack');
      expect(manifest.files, hasLength(250));
      expect(manifest.files[0].index, 1);
      expect(manifest.files[0].path, 'Season 1/Episode 0.mkv');
      expect(manifest.files[249].path, 'Season 3/Episode 249.mkv');
      expect(manifest.totalLength, 250 * 1000 + (249 * 250) ~/ 2);
    });

    test('hides padding files but keeps their index slot', () {
      final manifest = TorrentManifest.parse(
        bencode({
          'info': {
            'name': 'Pack',
            'pieces': '',
            'files': [
              {
                'length': 10,
                'path': ['a.bin'],
              },
              {
                'length': 5,
                'attr': 'p',
                'path': ['.pad', '5'],
              },
              {
                'length': 20,
                'path': ['b.bin'],
              },
            ],
          },
        }),
      );
      expect(manifest.visibleFiles.map((f) => f.index), [1, 3]);
      expect(manifest.totalLength, 30);
    });

    test('prefers UTF-8 names', () {
      final manifest = TorrentManifest.parse(
        bencode({
          'info': {
            'name': 'x',
            'name.utf-8': 'Café Mix',
            'length': 1,
            'pieces': '',
          },
        }),
      );
      expect(manifest.name, 'Café Mix');
    });

    test('rejects garbage', () {
      expect(
        () => TorrentManifest.parse(utf8.encode('<html>')),
        throwsFormatException,
      );
      expect(
        () => TorrentManifest.parse(utf8.encode('d4:info')),
        throwsFormatException,
      );
    });
  });

  test('magnet info hashes in hex and base32', () {
    const hex = 'c12fe1c06bba254a9dc9f519b335aa7c1367a88a';
    expect(magnetInfoHash('magnet:?xt=urn:btih:${hex.toUpperCase()}'), hex);
    expect(
      magnetInfoHash('magnet:?xt=urn:btih:YEX6DQDLXISUVHOJ6UM3GNNKPQJWPKEK'),
      hex,
    );
    expect(magnetInfoHash('magnet:?dn=nohash'), isNull);
  });

  test('select-file ranges', () {
    expect(selectFileOption([5, 1, 2, 3, 9, 10, 7]), '1-3,5,7,9-10');
    expect(selectFileOption([4]), '4');
    expect(selectFileOption([for (var i = 1; i <= 5000; i++) i]), '1-5000');
  });

  test('file selection survives a save', () {
    final now = DateTime(2026);
    final item = DownloadItem(
      id: 'z',
      fileName: 'Pack',
      url: 'magnet:?xt=urn:btih:abc',
      source: 'BitTorrent',
      sizeBytes: 0,
      downloadedBytes: 0,
      status: DownloadStatus.queued,
      savePath: '/tmp',
      addedAt: now,
      lastActivity: now,
      connections: 1,
      kind: DownloadKind.torrent,
      selectedFiles: const [1, 4, 5],
    );
    final restored = DownloadItem.fromJson(
      jsonDecode(jsonEncode(item.toJson())) as Map<String, Object?>,
    );
    expect(restored.selectedFiles, [1, 4, 5]);
    expect(restored.copyWith(speed: 1).selectedFiles, [1, 4, 5]);
  });

  testWidgets('picker handles thousands of files', (tester) async {
    final manifest = TorrentManifest.parse(multiFileTorrent(5000));
    var selected = {for (final file in manifest.files) file.index};

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => TorrentFilePicker(
                manifest: manifest,
                selected: selected,
                onChanged: (next) => setState(() => selected = next),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('5000 of 5000'), findsOneWidget);
    // Big torrents start collapsed: 50 season folders, no episode rows.
    expect(find.text('Season 1'), findsOneWidget);
    expect(find.text('Episode 0.mkv'), findsNothing);

    await tester.tap(find.text('None'));
    await tester.pump();
    expect(selected, isEmpty);

    await tester.enterText(find.byType(TextField), 'Episode 42');
    await tester.pump();
    await tester.tap(find.text('Select matches'));
    await tester.pump();
    // Episode 42, 420–429 and 4200–4299.
    expect(selected, hasLength(111));
    expect(find.textContaining('111 of 5000'), findsOneWidget);

    // Opening a folder shows its files.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('Season 1'));
    await tester.pump();
    expect(find.text('Episode 0.mkv'), findsOneWidget);
  });
}
