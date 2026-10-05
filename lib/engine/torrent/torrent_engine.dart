import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../domain/models/download.dart';
import '../engine.dart';
import '../media/ytdlp.dart';

/// True for magnet links and `.torrent` files (remote or local).
bool isTorrentLink(String url) {
  final value = url.trim();
  if (value.toLowerCase().startsWith('magnet:?')) return true;
  final uri = Uri.tryParse(value);
  final path = (uri?.path ?? value).toLowerCase();
  return path.endsWith('.torrent');
}

/// A readable name before metadata arrives: the magnet's `dn`, the
/// `.torrent` file name, or the info hash.
String torrentDisplayName(String url) {
  final value = url.trim();
  if (value.toLowerCase().startsWith('magnet:?')) {
    final query = value.substring(value.indexOf('?') + 1);
    String? hash;
    for (final pair in query.split('&')) {
      final eq = pair.indexOf('=');
      if (eq < 0) continue;
      final key = pair.substring(0, eq);
      final raw = pair.substring(eq + 1).replaceAll('+', ' ');
      String decoded;
      try {
        decoded = Uri.decodeComponent(raw);
      } catch (_) {
        decoded = raw;
      }
      if (key == 'dn' && decoded.trim().isNotEmpty) return decoded.trim();
      if (key == 'xt') hash = decoded.split(':').last;
    }
    return hash == null
        ? 'Torrent'
        : 'Torrent ${hash.substring(0, min(8, hash.length))}';
  }
  final name = value.split(RegExp(r'[/\\]')).last.split('?').first;
  final decoded = Uri.decodeComponent(name);
  return decoded.toLowerCase().endsWith('.torrent')
      ? decoded.substring(0, decoded.length - 8)
      : (decoded.isEmpty ? 'Torrent' : decoded);
}

/// Minimal aria2 JSON-RPC client.
class Aria2Rpc {
  Aria2Rpc({required this.port, required this.secret});

  final int port;
  final String secret;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);
  int _id = 0;

  Future<Object?> call(String method, [List<Object?> params = const []]) async {
    final request = await _client.postUrl(
      Uri.parse('http://127.0.0.1:$port/jsonrpc'),
    );
    final body = utf8.encode(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': '${_id++}',
        'method': method,
        'params': ['token:$secret', ...params],
      }),
    );
    // aria2's HTTP server cannot read chunked bodies; send a fixed length.
    request.headers.contentType = ContentType.json;
    request.contentLength = body.length;
    request.add(body);
    final response = await request.close().timeout(const Duration(seconds: 15));
    final reply = await response.transform(utf8.decoder).join();
    final json = jsonDecode(reply) as Map<String, Object?>;
    final error = json['error'];
    if (error is Map) {
      throw Aria2Exception('${error['message'] ?? 'aria2 error'}');
    }
    return json['result'];
  }

  void close() => _client.close(force: true);
}

class Aria2Exception implements Exception {
  const Aria2Exception(this.message);
  final String message;

  @override
  String toString() => message;
}

class _TorrentTask {
  _TorrentTask(this.item);

  final DownloadItem item;
  String? gid;
  String? name;
  List<String> files = const [];
  String? dir;
  bool stopped = false;
  Map<String, String> options = const {};
  int requeued = 0;

  /// Finished and handed back to AppState; aria2 may still be seeding.
  bool reported = false;
}

/// BitTorrent through a private aria2 daemon controlled over JSON-RPC.
///
/// One `aria2c` process serves every torrent. It is bound to 127.0.0.1 with a
/// random secret and exits on its own if ZON dies (`--stop-with-process`).
/// Pausing removes a torrent from aria2 but keeps its files and `.aria2`
/// control file, so starting it again resumes after a piece check.
class TorrentEngine implements TransferEngine {
  TorrentEngine({required this.tools, required this.stateDir});

  final MediaTools tools;
  final String stateDir;

  TransferListener? _listener;
  final Map<String, _TorrentTask> _tasks = {};
  Process? _process;
  Aria2Rpc? _rpc;
  Future<Aria2Rpc>? _starting;
  Timer? _poll;
  bool _polling = false;

  static const _statusKeys = [
    'gid',
    'status',
    'totalLength',
    'completedLength',
    'downloadSpeed',
    'uploadSpeed',
    'connections',
    'numSeeders',
    'followedBy',
    'errorMessage',
    'bittorrent',
    'dir',
    'files',
    'seeder',
  ];

  @override
  set listener(TransferListener listener) => _listener = listener;

  @override
  bool isRunning(String id) => _tasks[id]?.reported == false;

  @override
  void start(DownloadItem item, TransferOptions options) {
    final listener = _listener;
    if (listener == null) return;
    final existing = _tasks[item.id];
    if (existing != null && !existing.reported) return;
    final task = _TorrentTask(item);
    _tasks[item.id] = task;
    unawaited(_add(task, options, listener));
  }

  Future<void> _add(
    _TorrentTask task,
    TransferOptions options,
    TransferListener listener,
  ) async {
    final item = task.item;
    try {
      if (tools.aria2Path == null) {
        throw const Aria2Exception(
          'aria2 is not installed — set it up in Settings › Torrents.',
        );
      }
      await Directory(item.savePath).create(recursive: true);
      final rpc = await _daemon();
      final ratio = options.seedRatio;
      final limit = options.speedLimit;
      final addOptions = <String, String>{
        'dir': item.savePath,
        'max-download-limit': '${limit ?? 0}',
        if (ratio == null) 'seed-time': '0' else 'seed-ratio': '$ratio',
      };

      task.options = addOptions;
      final gid = await _submit(rpc, item.url.trim(), addOptions);
      if (task.stopped) {
        await _remove(rpc, gid);
        return;
      }
      task.gid = gid;
      listener.onMeta(
        item.id,
        const TransferMeta(
          resumeSupported: true,
          contentType: 'application/x-bittorrent',
          server: 'aria2',
        ),
      );
      _poll ??= Timer.periodic(const Duration(seconds: 1), (_) => _pollAll());
    } catch (error) {
      _tasks.remove(item.id);
      if (!task.stopped) listener.onFailed(item.id, _describe(error));
    }
  }

  /// Hands the torrent to aria2. `.torrent` files (local or remote) are read
  /// here and uploaded, so no stray `.torrent` lands in the download folder.
  Future<String> _submit(
    Aria2Rpc rpc,
    String url,
    Map<String, String> options,
  ) async {
    Future<Object?> add() async {
      if (url.toLowerCase().startsWith('magnet:')) {
        return rpc.call('aria2.addUri', [
          [url],
          options,
        ]);
      }
      return rpc.call('aria2.addTorrent', [
        base64Encode(await _torrentBytes(url)),
        <String>[],
        options,
      ]);
    }

    for (var attempt = 0; ; attempt++) {
      try {
        return '${await add()}';
      } on Aria2Exception catch (error) {
        // Still registered (seeding, or finishing up): drop it and retry
        // while aria2 tears the old session down (it tells trackers first).
        final hash = RegExp(r'InfoHash ([0-9a-fA-F]{40}) is already registered')
            .firstMatch(error.message)
            ?.group(1);
        if (hash == null || attempt >= 20) rethrow;
        if (attempt == 0) await _removeByHash(rpc, hash.toLowerCase());
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<List<int>> _torrentBytes(String url) async {
    if (!url.contains('://')) {
      final file = File(url);
      if (!await file.exists()) {
        throw Aria2Exception('Torrent file not found: $url');
      }
      return file.readAsBytes();
    }
    final client = HttpClient()..userAgent = 'ZON/1.0';
    try {
      final response = await (await client.getUrl(Uri.parse(url)))
          .close()
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Aria2Exception(
          'Could not fetch the .torrent (HTTP ${response.statusCode})',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 20 * 1024 * 1024) {
          throw const Aria2Exception('That .torrent file is too large');
        }
      }
      if (bytes.isEmpty || bytes.first != 0x64 /* 'd' */ ) {
        throw const Aria2Exception('That link is not a valid .torrent file');
      }
      return bytes;
    } finally {
      client.close(force: true);
    }
  }

  static String? _registeredHash(String message) =>
      RegExp(r'InfoHash ([0-9a-fA-F]{40}) is already registered')
          .firstMatch(message)
          ?.group(1)
          ?.toLowerCase();

  Future<void> _requeue(_TorrentTask task, String hash, String? stale) async {
    final rpc = _rpc;
    if (rpc == null) return;
    try {
      if (stale != null) {
        await rpc
            .call('aria2.removeDownloadResult', [stale])
            .catchError((_) => null);
      }
      await _removeByHash(rpc, hash);
      await Future<void>.delayed(const Duration(seconds: 1));
      if (task.stopped) return;
      task.gid = await _submit(rpc, task.item.url.trim(), task.options);
    } catch (error) {
      if (_tasks.remove(task.item.id) != null && !task.stopped) {
        _listener?.onFailed(task.item.id, _describe(error));
      }
    }
  }

  Future<void> _removeByHash(Aria2Rpc rpc, String hash) async {
    const keys = ['gid', 'infoHash'];
    final lists = await Future.wait([
      rpc.call('aria2.tellActive', [keys]),
      rpc.call('aria2.tellWaiting', [0, 1000, keys]),
    ]);
    for (final list in lists) {
      if (list is! List) continue;
      for (final entry in list) {
        if (entry is Map && '${entry['infoHash']}'.toLowerCase() == hash) {
          await _remove(rpc, '${entry['gid']}');
        }
      }
    }
  }

  Future<Aria2Rpc> _daemon() {
    final rpc = _rpc;
    if (rpc != null) return Future.value(rpc);
    return _starting ??= _launch().whenComplete(() => _starting = null);
  }

  Future<Aria2Rpc> _launch() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final random = Random.secure();
    final secret = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    await Directory(stateDir).create(recursive: true);
    final sep = Platform.pathSeparator;
    final process = await Process.start(tools.aria2Path!, [
      '--enable-rpc=true',
      '--rpc-listen-all=false',
      '--rpc-listen-port=$port',
      '--rpc-secret=$secret',
      '--stop-with-process=$pid',
      '--continue=true',
      '--check-integrity=true',
      // Keep .torrent copies out of the user's download folder.
      '--bt-save-metadata=false',
      '--rpc-save-upload-metadata=false',
      '--follow-torrent=true',
      '--enable-dht=true',
      '--dht-file-path=$stateDir${sep}dht.dat',
      // aria2 ships no DHT bootstrap nodes; without one, magnets that
      // rely on DHT (most of them) never find peers on a fresh install.
      '--dht-entry-point=router.bittorrent.com:6881',
      '--enable-peer-exchange=true',
      '--bt-enable-lpd=true',
      '--bt-max-peers=80',
      '--bt-detach-seed-only=true',
      '--max-concurrent-downloads=100',
      '--file-allocation=none',
      '--auto-file-renaming=false',
      '--console-log-level=warn',
      '--summary-interval=0',
      '--quiet=true',
    ]);
    _process = process;
    // Drain output so the pipe never fills up.
    process.stdout.drain<void>().ignore();
    process.stderr.drain<void>().ignore();
    unawaited(
      process.exitCode.then((_) {
        if (identical(_process, process)) {
          _process = null;
          _rpc?.close();
          _rpc = null;
          _failAll('aria2 stopped unexpectedly');
        }
      }),
    );

    final rpc = Aria2Rpc(port: port, secret: secret);
    for (var attempt = 0; attempt < 50; attempt++) {
      try {
        await rpc.call('aria2.getVersion');
        _rpc = rpc;
        return rpc;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    process.kill();
    rpc.close();
    throw const Aria2Exception('aria2 did not start');
  }

  void _failAll(String reason) {
    final listener = _listener;
    for (final entry in _tasks.entries.toList()) {
      if (entry.value.reported) continue;
      _tasks.remove(entry.key);
      listener?.onFailed(entry.key, reason);
    }
  }

  Future<void> _pollAll() async {
    final rpc = _rpc;
    final listener = _listener;
    if (rpc == null || listener == null || _polling) return;
    _polling = true;
    try {
      for (final entry in _tasks.entries.toList()) {
        final task = entry.value;
        final gid = task.gid;
        if (gid == null || task.reported || task.stopped) continue;
        try {
          final status = await rpc.call('aria2.tellStatus', [gid, _statusKeys]);
          if (status is Map) _apply(entry.key, task, status, listener);
        } catch (_) {
          // Transient RPC hiccup; try again next tick.
        }
      }
    } finally {
      _polling = false;
    }
  }

  void _apply(
    String id,
    _TorrentTask task,
    Map<dynamic, dynamic> status,
    TransferListener listener,
  ) {
    int number(String key) => int.tryParse('${status[key] ?? 0}') ?? 0;

    final followedBy = status['followedBy'];
    if (followedBy is List && followedBy.isNotEmpty) {
      // Magnet metadata finished; the real download has a new gid.
      task.gid = '${followedBy.first}';
      return;
    }

    task.dir = status['dir']?.toString() ?? task.dir;
    final files = status['files'];
    if (files is List) {
      task.files = [
        for (final file in files)
          if (file is Map && '${file['path'] ?? ''}'.isNotEmpty)
            '${file['path']}',
      ];
    }
    final bittorrent = status['bittorrent'];
    final info = bittorrent is Map ? bittorrent['info'] : null;
    final name = info is Map ? info['name']?.toString() : null;
    final fetchingMetadata =
        task.files.isNotEmpty && task.files.first.startsWith('[METADATA]');

    if (name != null && name.isNotEmpty && name != task.name) {
      task.name = name;
      listener.onMeta(id, TransferMeta(fileName: name));
    }

    switch (status['status']) {
      case 'error':
        final message =
            status['errorMessage']?.toString() ?? 'aria2 reported an error';
        final hash = _registeredHash(message);
        if (hash != null && task.requeued < 3) {
          // aria2 accepted the add, then found the same torrent still
          // registered (seeding / finishing). Clear it and submit again.
          task.requeued++;
          final stale = task.gid;
          task.gid = null;
          unawaited(_requeue(task, hash, stale));
          return;
        }
        _tasks.remove(id);
        listener.onFailed(id, message);
        return;
      case 'removed':
        _tasks.remove(id);
        return;
    }

    final total = number('totalLength');
    final done = number('completedLength');
    final finished =
        !fetchingMetadata &&
        (status['status'] == 'complete' ||
            status['seeder'] == 'true' ||
            (total > 0 && done >= total));

    listener.onMeta(
      id,
      TransferMeta(
        connections: number('connections'),
        seeders: number('numSeeders'),
        uploadSpeed: number('uploadSpeed').toDouble(),
      ),
    );

    if (fetchingMetadata) {
      listener.onProgress(id, 0, 0);
      return;
    }
    listener.onProgress(
      id,
      done,
      number('downloadSpeed').toDouble(),
      total: total > 0 ? total : null,
    );

    if (finished) {
      task.reported = true;
      if (status['status'] == 'complete') _tasks.remove(id);
      listener.onCompleted(id, _outputPath(task));
    }
  }

  String _outputPath(_TorrentTask task) {
    final sep = Platform.pathSeparator;
    final dir = task.dir ?? task.item.savePath;
    if (task.files.length == 1) return task.files.first;
    if (task.name != null) return '$dir$sep${task.name}';
    return dir;
  }

  Future<void> _remove(Aria2Rpc rpc, String gid) async {
    try {
      await rpc.call('aria2.forceRemove', [gid]);
    } catch (_) {}
    // Wait for aria2 to flush the .aria2 control file before it forgets.
    for (var i = 0; i < 20; i++) {
      try {
        final status = await rpc.call('aria2.tellStatus', [
          gid,
          ['status'],
        ]);
        if (status is Map && status['status'] == 'removed') break;
      } catch (_) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    try {
      await rpc.call('aria2.removeDownloadResult', [gid]);
    } catch (_) {}
  }

  @override
  Future<void> pause(String id) async {
    final task = _tasks.remove(id);
    if (task == null) return;
    task.stopped = true;
    final rpc = _rpc;
    final gid = task.gid;
    if (rpc != null && gid != null) await _remove(rpc, gid);
  }

  @override
  Future<void> cancel(String id) async {
    final task = _tasks[id];
    await pause(id);
    if (task == null) return;
    // Delete only what aria2 said belongs to this torrent.
    for (final path in task.files) {
      if (path.startsWith('[METADATA]')) continue;
      for (final candidate in [path, '$path.aria2']) {
        try {
          final file = File(candidate);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
    final name = task.name;
    final dir = task.dir;
    if (name != null && dir != null) {
      final sep = Platform.pathSeparator;
      try {
        final control = File('$dir$sep$name.aria2');
        if (await control.exists()) await control.delete();
        final folder = Directory('$dir$sep$name');
        // Remove the torrent's folder only if nothing else is left in it.
        if (task.files.length > 1 && await folder.exists()) {
          final leftovers = await folder
              .list(recursive: true)
              .where((entity) => entity is File)
              .isEmpty;
          if (leftovers) await folder.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  @override
  void setSpeedLimit(String id, int? bytesPerSecond) {
    final gid = _tasks[id]?.gid;
    final rpc = _rpc;
    if (gid == null || rpc == null) return;
    unawaited(
      rpc
          .call('aria2.changeOption', [
            gid,
            {'max-download-limit': '${bytesPerSecond ?? 0}'},
          ])
          .then((_) {}, onError: (_) {}),
    );
  }

  @override
  Future<void> dispose() async {
    _poll?.cancel();
    _poll = null;
    final rpc = _rpc;
    final process = _process;
    _rpc = null;
    _process = null;
    _tasks.clear();
    if (rpc != null) {
      try {
        // Saves control files so the next launch resumes cleanly.
        await rpc.call('aria2.shutdown').timeout(const Duration(seconds: 3));
      } catch (_) {}
      rpc.close();
    }
    if (process != null) {
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }
  }

  String _describe(Object error) {
    if (error is ProcessException) {
      return 'Could not run aria2: ${error.message}';
    }
    if (error is SocketException) return 'Could not reach aria2';
    return '$error';
  }
}
