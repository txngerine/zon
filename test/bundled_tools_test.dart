import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zon/engine/media/ytdlp.dart';

void main() {
  final payload = 'ZON payload'.codeUnits;

  late Directory binDir;
  late MediaTools tools;

  setUp(() async {
    binDir = await Directory.systemTemp.createTemp('zon_tools');
    tools = MediaTools(binDir: binDir.path);
  });

  tearDown(() async {
    if (await binDir.exists()) await binDir.delete(recursive: true);
  });

  ByteData gzipOf(List<int> bytes) =>
      ByteData.view(Uint8List.fromList(gzip.encode(bytes)).buffer);

  String targetOf(String archive) =>
      '${binDir.path}${Platform.pathSeparator}'
      '${archive.substring(0, archive.length - 3)}'
      '${Platform.isWindows ? '.exe' : ''}';

  test('bundled archives cover ffmpeg everywhere and aria2 off macOS', () {
    expect(
      MediaTools.bundledArchives,
      containsAll(['ffmpeg.gz', 'ffprobe.gz']),
    );
    expect(MediaTools.bundledArchives.contains('aria2c.gz'), !Platform.isMacOS);
    expect(MediaTools.bundledAssetPrefix, 'assets/tools');
  });

  test('installBundled unpacks every shipped archive', () async {
    final seen = <String>[];
    final progress = <double>[];

    final unpacked = await tools.installBundled(
      loader: (asset) async {
        seen.add(asset);
        return gzipOf(payload);
      },
      onProgress: progress.add,
    );

    expect(unpacked, MediaTools.bundledArchives.length);
    expect(
      seen,
      containsAll([
        for (final archive in MediaTools.bundledArchives)
          'assets/tools/$archive',
      ]),
    );
    expect(
      File('${binDir.path}${Platform.pathSeparator}ffmpeg.LICENSE')
          .existsSync(),
      isTrue,
    );
    for (final archive in MediaTools.bundledArchives) {
      final file = File(targetOf(archive));
      expect(file.existsSync(), isTrue, reason: archive);
      expect(await file.readAsBytes(), payload);
    }
    expect(progress, isNotEmpty);
    expect(progress.last, 1.0);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
    }
  });

  test('installBundled leaves existing binaries alone', () async {
    final first = await tools.installBundled(
      loader: (_) async => gzipOf(payload),
    );
    expect(first, MediaTools.bundledArchives.length);

    final seen = <String>[];
    final second = await tools.installBundled(
      loader: (asset) async {
        seen.add(asset);
        return gzipOf(payload);
      },
    );
    expect(second, 0);
    expect(seen, isEmpty);
  });

  test(
    'installBundled does nothing when the build ships no archives',
    () async {
      final unpacked = await tools.installBundled(
        loader: (_) async => throw FlutterError('Unable to load asset'),
      );
      expect(unpacked, 0);
    },
  );

  test('bundled ffmpeg and ffprobe unpack into runnable binaries', () async {
    final unpacked = await tools.installBundled(
      loader: (asset) async {
        final file = File(asset);
        if (!file.existsSync()) {
          throw FlutterError('Unable to load asset');
        }
        final bytes = Uint8List.fromList(await file.readAsBytes());
        return ByteData.view(bytes.buffer);
      },
    );
    expect(unpacked, greaterThan(0));
    for (final archive in const ['ffmpeg.gz', 'ffprobe.gz']) {
      final run = await Process.run(targetOf(archive), ['-version']);
      expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
      expect(run.stdout, contains(archive.substring(0, archive.length - 3)));
    }
  }, skip: File('assets/tools/ffmpeg.gz').existsSync() ? false : 'no bundle');

  test('installBundled rejects a corrupt archive', () async {
    await expectLater(
      tools.installBundled(
        loader: (_) async => ByteData.sublistView(Uint8List.fromList([1, 2])),
      ),
      throwsA(isA<MediaToolException>()),
    );
  });
}
