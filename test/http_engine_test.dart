import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zon/domain/models/download.dart';
import 'package:zon/engine/engine.dart';
import 'package:zon/engine/http_engine.dart';

class _Recorder implements TransferListener {
  final metas = <TransferMeta>[];
  final completed = Completer<String>();
  final failed = Completer<String>();
  int lastBytes = 0;

  @override
  void onMeta(String id, TransferMeta meta) => metas.add(meta);

  @override
  void onProgress(String id, int downloaded, double speed, {int? total}) =>
      lastBytes = downloaded;

  @override
  void onPhase(String id, String phase) {}

  @override
  void onCompleted(String id, String filePath) => completed.complete(filePath);

  @override
  void onFailed(String id, String reason) => failed.complete(reason);
}

/// Serves [body] with optional range support and an optional throttle.
Future<HttpServer> _serve(
  Uint8List body, {
  bool ranges = true,
  String? disposition,
  Duration chunkDelay = Duration.zero,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final response = request.response;
    if (disposition != null) {
      response.headers.set('content-disposition', disposition);
    }
    var start = 0;
    var end = body.length - 1;
    final range = request.headers.value('range');
    if (ranges && range != null) {
      final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
      start = int.parse(match.group(1)!);
      if (match.group(2)!.isNotEmpty) end = int.parse(match.group(2)!);
      response.statusCode = 206;
      response.headers.set('content-range', 'bytes $start-$end/${body.length}');
      response.headers.set('accept-ranges', 'bytes');
    }
    response.contentLength = end - start + 1;
    try {
      for (var offset = start; offset <= end; offset += 64 * 1024) {
        response.add(body.sublist(offset, min(offset + 64 * 1024, end + 1)));
        if (chunkDelay > Duration.zero) {
          await response.flush();
          await Future<void>.delayed(chunkDelay);
        }
      }
      await response.close();
    } catch (_) {
      // Client hung up (pause).
    }
  });
  return server;
}

DownloadItem _item(String url, String dir, {int connections = 4}) {
  final now = DateTime.now();
  return DownloadItem(
    id: 'test-${now.microsecondsSinceEpoch}',
    fileName: 'payload.bin',
    url: url,
    source: 'localhost',
    sizeBytes: 0,
    downloadedBytes: 0,
    status: DownloadStatus.downloading,
    savePath: dir,
    addedAt: now,
    lastActivity: now,
    connections: connections,
  );
}

void main() {
  late Directory temp;
  late Uint8List body;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('zon_http_');
    final rnd = Random(42);
    body = Uint8List.fromList(
      List<int>.generate(5 * 1024 * 1024 + 123, (_) => rnd.nextInt(256)),
    );
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  const options = TransferOptions(retryDelay: Duration(milliseconds: 50));

  test('segmented download reassembles the exact bytes', () async {
    final server = await _serve(body);
    addTearDown(server.close);
    final engine = HttpEngine(stateDir: '${temp.path}/state');
    final recorder = _Recorder();
    engine.listener = recorder;

    engine.start(
      _item('http://127.0.0.1:${server.port}/payload.bin', temp.path),
      options,
    );
    final path = await recorder.completed.future.timeout(
      const Duration(seconds: 20),
    );

    expect(await File(path).readAsBytes(), body);
    expect(recorder.metas.any((m) => m.resumeSupported == true), isTrue);
    expect(recorder.metas.any((m) => m.connections == 4), isTrue);
    expect(File('$path.zonpart').existsSync(), isFalse);
  });

  test('pause keeps progress and resume finishes the file', () async {
    final server = await _serve(
      body,
      chunkDelay: const Duration(milliseconds: 80),
    );
    addTearDown(server.close);
    final engine = HttpEngine(stateDir: '${temp.path}/state');
    final item = _item(
      'http://127.0.0.1:${server.port}/payload.bin',
      temp.path,
    );

    final first = _Recorder();
    engine.listener = first;
    engine.start(item, options);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await engine.pause(item.id);
    expect(first.lastBytes, greaterThan(0));
    expect(first.completed.isCompleted, isFalse);

    final second = _Recorder();
    engine.listener = second;
    engine.start(item, options);
    final path = await second.completed.future.timeout(
      const Duration(seconds: 30),
    );
    expect(await File(path).readAsBytes(), body);
  });

  test('servers without range support download in one stream', () async {
    final server = await _serve(body, ranges: false);
    addTearDown(server.close);
    final engine = HttpEngine(stateDir: '${temp.path}/state');
    final recorder = _Recorder();
    engine.listener = recorder;

    engine.start(
      _item('http://127.0.0.1:${server.port}/payload.bin', temp.path),
      options,
    );
    final path = await recorder.completed.future.timeout(
      const Duration(seconds: 20),
    );
    expect(await File(path).readAsBytes(), body);
    expect(recorder.metas.any((m) => m.resumeSupported == false), isTrue);
  });

  test(
    'Content-Disposition names the file and collisions get a suffix',
    () async {
      final server = await _serve(
        body,
        disposition: "attachment; filename*=UTF-8''r%C3%A9sum%C3%A9.pdf",
      );
      addTearDown(server.close);
      File('${temp.path}/résumé.pdf').writeAsStringSync('existing');
      final engine = HttpEngine(stateDir: '${temp.path}/state');
      final recorder = _Recorder();
      engine.listener = recorder;

      engine.start(
        _item('http://127.0.0.1:${server.port}/download?id=1', temp.path),
        options,
      );
      final path = await recorder.completed.future.timeout(
        const Duration(seconds: 20),
      );
      expect(path.endsWith('résumé (1).pdf'), isTrue);
    },
  );

  test('HTTP errors fail without retrying forever', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) {
      request.response.statusCode = 404;
      request.response.close();
    });
    final engine = HttpEngine(stateDir: '${temp.path}/state');
    final recorder = _Recorder();
    engine.listener = recorder;

    engine.start(
      _item('http://127.0.0.1:${server.port}/missing', temp.path),
      options,
    );
    final reason = await recorder.failed.future.timeout(
      const Duration(seconds: 10),
    );
    expect(reason, contains('404'));
  });

  test('429 Too Many Requests sheds connections instead of failing', () async {
    // Like many mirrors: at most 2 transfers per client, 429 beyond that.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    var open = 0;
    var peak = 0;
    var refused = 0;
    server.listen((request) async {
      final response = request.response;
      final range = request.headers.value('range')!;
      final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
      final start = int.parse(match.group(1)!);
      final end = match.group(2)!.isEmpty
          ? body.length - 1
          : int.parse(match.group(2)!);
      final isProbe = start == 0 && end == 0;
      if (!isProbe && open >= 2) {
        refused++;
        response.statusCode = 429;
        await response.close();
        return;
      }
      if (!isProbe) peak = max(peak, ++open);
      response.statusCode = 206;
      response.headers.set('content-range', 'bytes $start-$end/${body.length}');
      response.contentLength = end - start + 1;
      try {
        for (var offset = start; offset <= end; offset += 64 * 1024) {
          response.add(body.sublist(offset, min(offset + 64 * 1024, end + 1)));
          await response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        await response.close();
      } catch (_) {
      } finally {
        if (!isProbe) open--;
      }
    });

    final engine = HttpEngine(stateDir: '${temp.path}/state');
    final recorder = _Recorder();
    engine.listener = recorder;
    engine.start(
      _item(
        'http://127.0.0.1:${server.port}/payload.bin',
        temp.path,
        connections: 8,
      ),
      options,
    );
    final path = await recorder.completed.future.timeout(
      const Duration(seconds: 30),
    );

    expect(await File(path).readAsBytes(), body);
    expect(refused, greaterThan(0));
    expect(peak, lessThanOrEqualTo(2));
    // The engine reports the reduced connection count.
    expect(recorder.metas.last.connections, lessThanOrEqualTo(2));
  });

  test('parseContentDisposition handles common header shapes', () {
    expect(
      parseContentDisposition('attachment; filename="a b.zip"'),
      'a b.zip',
    );
    expect(parseContentDisposition('attachment; filename=c.iso'), 'c.iso');
    expect(parseContentDisposition(null), isNull);
    expect(sanitizeFileName('../evil/na:me?.txt'), 'na_me_.txt');
  });
}
