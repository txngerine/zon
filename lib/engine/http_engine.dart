import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../core/utils/formatters.dart';
import '../domain/models/download.dart';
import 'engine.dart';

/// Segmented, resumable HTTP(S) downloader.
///
/// Each download is split into up to `connections` byte ranges that are
/// fetched in parallel and written straight into `<name>.zonpart`. The range
/// plan is checkpointed to `<stateDir>/<id>.json`, so pausing, quitting or
/// crashing resumes from the last flushed byte.
class HttpEngine implements TransferEngine {
  HttpEngine({required this.stateDir});

  /// Directory for resume checkpoints.
  final String stateDir;

  TransferListener? _listener;
  final Map<String, _HttpTask> _tasks = {};

  @override
  set listener(TransferListener listener) => _listener = listener;

  @override
  bool isRunning(String id) => _tasks.containsKey(id);

  @override
  void start(DownloadItem item, TransferOptions options) {
    final listener = _listener;
    if (listener == null || _tasks.containsKey(item.id)) return;
    final task = _HttpTask(
      item: item,
      options: options,
      listener: listener,
      planFile: File('$stateDir${Platform.pathSeparator}${item.id}.json'),
    );
    _tasks[item.id] = task;
    task.run().whenComplete(() {
      if (identical(_tasks[item.id], task)) _tasks.remove(item.id);
    });
  }

  @override
  Future<void> pause(String id) async {
    final task = _tasks.remove(id);
    await task?.stop();
  }

  @override
  Future<void> cancel(String id) async {
    final task = _tasks.remove(id);
    if (task != null) {
      await task.stop();
      await task.discard();
      return;
    }
    await _HttpTask.discardPlan(
      File('$stateDir${Platform.pathSeparator}$id.json'),
    );
  }

  @override
  void setSpeedLimit(String id, int? bytesPerSecond) {
    _tasks[id]?.limiter.bytesPerSecond = bytesPerSecond;
  }

  @override
  Future<void> dispose() async {
    final tasks = _tasks.values.toList();
    _tasks.clear();
    await Future.wait(tasks.map((task) => task.stop()));
  }
}

/// Token bucket shared by every segment of one download.
class RateLimiter {
  RateLimiter(this.bytesPerSecond);

  int? bytesPerSecond;
  double _tokens = 0;
  DateTime _last = DateTime.now();

  Future<void> take(int bytes) async {
    final limit = bytesPerSecond;
    if (limit == null || limit <= 0) return;
    final now = DateTime.now();
    final elapsed = now.difference(_last).inMicroseconds / 1e6;
    _last = now;
    _tokens = min(limit.toDouble(), _tokens + elapsed * limit) - bytes;
    if (_tokens < 0) {
      final wait = (-_tokens / limit * 1e6).round();
      await Future<void>.delayed(Duration(microseconds: wait));
    }
  }
}

class _Segment {
  _Segment(this.start, this.end, this.position);

  final int start;

  /// Inclusive end byte, or -1 when the total size is unknown.
  final int end;
  int position;

  bool get done => end >= 0 && position > end;

  Map<String, int> toJson() => {'s': start, 'e': end, 'p': position};

  static _Segment fromJson(Map<String, Object?> json) => _Segment(
    (json['s'] as num).toInt(),
    (json['e'] as num).toInt(),
    (json['p'] as num).toInt(),
  );
}

class _Plan {
  _Plan({
    required this.url,
    required this.partPath,
    required this.fileName,
    required this.size,
    required this.resumable,
    required this.segments,
  });

  final String url;
  final String partPath;
  final String fileName;
  final int size;
  final bool resumable;
  final List<_Segment> segments;

  int get downloaded => segments.fold(
    0,
    (sum, segment) => sum + segment.position - segment.start,
  );

  Map<String, Object?> toJson() => {
    'url': url,
    'partPath': partPath,
    'fileName': fileName,
    'size': size,
    'resumable': resumable,
    'segments': [for (final segment in segments) segment.toJson()],
  };

  static _Plan fromJson(Map<String, Object?> json) => _Plan(
    url: json['url'] as String,
    partPath: json['partPath'] as String,
    fileName: json['fileName'] as String,
    size: (json['size'] as num).toInt(),
    resumable: json['resumable'] as bool,
    segments: [
      for (final raw in json['segments'] as List)
        _Segment.fromJson((raw as Map).cast<String, Object?>()),
    ],
  );
}

class _Probe {
  const _Probe({
    required this.status,
    required this.size,
    required this.resumable,
    this.fileName,
    this.contentType,
    this.server,
  });

  final int status;
  final int size;
  final bool resumable;
  final String? fileName;
  final String? contentType;
  final String? server;
}

class _StoppedException implements Exception {
  const _StoppedException();
}

class _HttpTask {
  _HttpTask({
    required this.item,
    required this.options,
    required this.listener,
    required this.planFile,
  }) : limiter = RateLimiter(options.speedLimit);

  /// Segments smaller than this are not worth an extra connection.
  static const int minSegmentBytes = 1024 * 1024;

  final DownloadItem item;
  final TransferOptions options;
  final TransferListener listener;
  final File planFile;
  final RateLimiter limiter;

  late final HttpClient _client = _buildClient();
  _Plan? _plan;
  bool _stopped = false;
  Object? _fatal;
  Timer? _reporter;
  final Completer<void> _finished = Completer<void>();

  int _lastBytes = 0;
  DateTime _lastSample = DateTime.now();
  double _speed = 0;
  int _ticks = 0;

  HttpClient _buildClient() {
    final client = HttpClient()
      ..connectionTimeout = options.connectionTimeout
      ..idleTimeout = const Duration(seconds: 15)
      ..autoUncompress = false
      ..userAgent = options.userAgent
      ..maxConnectionsPerHost = max(1, item.connections) + 1;
    final proxy = options.proxy.trim();
    if (proxy.isNotEmpty) {
      final hostPort = proxy.replaceFirst(RegExp(r'^\w+://'), '');
      client.findProxy = (_) => 'PROXY $hostPort';
    }
    return client;
  }

  Future<void> run() async {
    try {
      final plan = await _loadPlan() ?? await _createPlan();
      _plan = plan;
      if (_stopped) throw const _StoppedException();

      listener.onMeta(
        item.id,
        TransferMeta(
          fileName: plan.fileName,
          sizeBytes: plan.size > 0 ? plan.size : null,
          resumeSupported: plan.resumable,
          connections: plan.segments.length,
        ),
      );

      if (!plan.resumable) {
        // Without range support every attempt starts over.
        for (final segment in plan.segments) {
          segment.position = segment.start;
        }
        await File(plan.partPath).writeAsBytes(const [], flush: true);
      }

      _lastBytes = plan.downloaded;
      _reporter = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _report(),
      );

      await _runWorkers(plan);
      final fatal = _fatal;
      if (fatal != null) throw fatal;
      if (_stopped) throw const _StoppedException();

      if (plan.size > 0 && plan.downloaded != plan.size) {
        throw HttpException(
          'Transfer ended early (${formatBytes(plan.downloaded)} of '
          '${formatBytes(plan.size)})',
        );
      }

      _reporter?.cancel();
      final target = await _uniquePath(
        '${item.savePath}${Platform.pathSeparator}${plan.fileName}',
      );
      await File(plan.partPath).rename(target);
      await discardPlan(planFile);
      listener.onProgress(item.id, plan.downloaded, 0, total: plan.downloaded);
      listener.onCompleted(item.id, target);
    } on _StoppedException {
      await _savePlan();
    } catch (error) {
      await _savePlan();
      if (!_stopped) listener.onFailed(item.id, _describe(error));
    } finally {
      _reporter?.cancel();
      _client.close(force: true);
      if (!_finished.isCompleted) _finished.complete();
    }
  }

  Future<void> stop() async {
    if (_stopped) return _finished.future;
    _stopped = true;
    _client.close(force: true);
    return _finished.future;
  }

  /// Deletes the partial file and checkpoint.
  Future<void> discard() async {
    final plan = _plan ?? await _loadPlan();
    if (plan != null) {
      final part = File(plan.partPath);
      if (await part.exists()) await part.delete();
    }
    await discardPlan(planFile);
  }

  static Future<void> discardPlan(File file) async {
    if (await file.exists()) await file.delete();
  }

  // --------------------------------------------------------------------------

  Future<_Plan?> _loadPlan() async {
    try {
      if (!await planFile.exists()) return null;
      final json = jsonDecode(await planFile.readAsString());
      final plan = _Plan.fromJson((json as Map).cast<String, Object?>());
      if (plan.url != item.url) return null;
      if (!await File(plan.partPath).exists()) return null;
      return plan;
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePlan() async {
    final plan = _plan;
    if (plan == null) return;
    try {
      await planFile.parent.create(recursive: true);
      await planFile.writeAsString(jsonEncode(plan.toJson()), flush: true);
    } catch (_) {
      // A lost checkpoint only costs a restart from zero.
    }
  }

  Future<_Plan> _createPlan() async {
    final probe = await _probe();
    listener.onMeta(
      item.id,
      TransferMeta(
        httpStatus: probe.status,
        contentType: probe.contentType,
        server: probe.server,
      ),
    );

    final fileName = sanitizeFileName(
      item.nameLocked ? item.fileName : (probe.fileName ?? item.fileName),
    );
    await Directory(item.savePath).create(recursive: true);
    final partPath =
        '${item.savePath}${Platform.pathSeparator}$fileName.zonpart';
    await File(partPath).writeAsBytes(const [], flush: true);

    final segments = <_Segment>[];
    if (probe.resumable && probe.size > 0) {
      final count = max(
        1,
        min(item.connections, (probe.size / minSegmentBytes).ceil()),
      );
      final chunk = (probe.size / count).ceil();
      for (var start = 0; start < probe.size; start += chunk) {
        final end = min(start + chunk, probe.size) - 1;
        segments.add(_Segment(start, end, start));
      }
    } else {
      segments.add(_Segment(0, probe.size > 0 ? probe.size - 1 : -1, 0));
    }

    final plan = _Plan(
      url: item.url,
      partPath: partPath,
      fileName: fileName,
      size: probe.size,
      resumable: probe.resumable,
      segments: segments,
    );
    _plan = plan;
    await _savePlan();
    return plan;
  }

  Future<_Probe> _probe() async {
    final request = await _client
        .getUrl(Uri.parse(item.url))
        .timeout(options.requestTimeout);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
    final response = await request.close().timeout(options.requestTimeout);
    try {
      if (response.statusCode >= 400) {
        throw HttpException('Server responded ${response.statusCode}');
      }
      final headers = response.headers;
      var size = 0;
      var resumable = false;
      final range = headers.value(HttpHeaders.contentRangeHeader);
      if (response.statusCode == 206 && range != null) {
        final total = RegExp(r'/(\d+)').firstMatch(range)?.group(1);
        size = int.tryParse(total ?? '') ?? 0;
        resumable = size > 0;
      } else {
        size = max(0, response.contentLength);
      }
      if (headers.value(HttpHeaders.contentEncodingHeader) case final enc?
          when enc != 'identity') {
        // Compressed bodies have no stable byte offsets.
        resumable = false;
        if (response.statusCode == 200) size = 0;
      }

      return _Probe(
        status: response.statusCode,
        size: size,
        resumable: resumable,
        fileName: parseContentDisposition(headers.value('content-disposition')),
        contentType: headers.contentType?.mimeType,
        server: headers.value('server'),
      );
    } finally {
      // Only headers were needed; cancelling drops the connection and body.
      unawaited(response.listen((_) {}).cancel());
    }
  }

  /// Runs up to `connections` workers over a shared queue of segments.
  ///
  /// When the server pushes back (429/503) a worker hands its segment back to
  /// the queue and retires, so the download settles at whatever concurrency
  /// the server tolerates instead of failing.
  Future<void> _runWorkers(_Plan plan) async {
    final queue = Queue<_Segment>.of(
      plan.segments.where((segment) => !segment.done),
    );
    if (queue.isEmpty) return;
    var alive = max(1, min(item.connections, queue.length));
    var throttledAttempts = 0;

    Future<void> worker() async {
      while (!_stopped && _fatal == null && queue.isNotEmpty) {
        final segment = queue.removeFirst();
        try {
          await _runSegment(plan, segment);
          throttledAttempts = 0;
        } on _Throttled catch (throttle) {
          queue.addFirst(segment);
          if (alive > 1) {
            alive--;
            listener.onMeta(item.id, TransferMeta(connections: alive));
            return;
          }
          // Last connection standing: back off and try again.
          if (++throttledAttempts > options.retryCount) {
            _abort(
              _FatalHttp(
                'Server keeps refusing connections (${throttle.status})',
              ),
            );
            return;
          }
          await Future<void>.delayed(
            throttle.retryAfter ?? options.retryDelay * throttledAttempts,
          );
        } catch (error) {
          _abort(error);
          return;
        }
      }
    }

    await Future.wait([for (var i = 0; i < alive; i++) worker()]);
  }

  /// Fails the whole download and unblocks every other worker.
  void _abort(Object error) {
    if (_fatal != null || _stopped) return;
    _fatal = error;
    _client.close(force: true);
  }

  Future<void> _runSegment(_Plan plan, _Segment segment) async {
    var attempts = 0;
    while (!segment.done && !_stopped && _fatal == null) {
      if (!plan.resumable && segment.position > segment.start) {
        // No ranges: a retry has to start the file over.
        segment.position = segment.start;
        await File(plan.partPath).writeAsBytes(const [], flush: true);
      }
      final before = segment.position;
      try {
        await _transfer(plan, segment);
        if (segment.end < 0 || segment.done) return;
        throw const HttpException('Connection closed early');
      } on _Throttled {
        rethrow;
      } catch (error) {
        if (_stopped || _fatal != null) return;
        if (error is _FatalHttp) rethrow;
        if (segment.position > before) attempts = 0;
        attempts++;
        if (attempts > options.retryCount) rethrow;
        await Future<void>.delayed(options.retryDelay * attempts);
      }
    }
  }

  Future<void> _transfer(_Plan plan, _Segment segment) async {
    final request = await _client
        .getUrl(Uri.parse(plan.url))
        .timeout(options.requestTimeout);
    if (plan.resumable) {
      final end = segment.end >= 0 ? '${segment.end}' : '';
      request.headers.set(
        HttpHeaders.rangeHeader,
        'bytes=${segment.position}-$end',
      );
    }
    final response = await request.close().timeout(options.requestTimeout);
    final status = response.statusCode;
    if (status == 429 || status == 503) {
      final seconds = int.tryParse(
        response.headers.value(HttpHeaders.retryAfterHeader) ?? '',
      );
      await response.drain<void>().catchError((_) {});
      throw _Throttled(
        status,
        seconds == null ? null : Duration(seconds: seconds.clamp(1, 120)),
      );
    }
    if (response.statusCode >= 400) {
      final fatal = response.statusCode >= 400 && response.statusCode < 500;
      await response.drain<void>().catchError((_) {});
      final message = 'Server responded ${response.statusCode}';
      throw fatal ? _FatalHttp(message) : HttpException(message);
    }
    if (plan.resumable && response.statusCode != 206) {
      await response.drain<void>().catchError((_) {});
      throw const _FatalHttp('Server stopped honouring byte ranges');
    }

    final file = await File(plan.partPath).open(mode: FileMode.append);
    try {
      await file.setPosition(segment.position);
      await for (final chunk in response.timeout(options.requestTimeout)) {
        if (_stopped) throw const _StoppedException();
        var bytes = chunk;
        if (segment.end >= 0) {
          final room = segment.end - segment.position + 1;
          if (room <= 0) break;
          if (bytes.length > room) bytes = bytes.sublist(0, room);
        }
        await limiter.take(bytes.length);
        await file.writeFrom(bytes);
        segment.position += bytes.length;
        if (segment.done) break;
      }
      await file.flush();
    } finally {
      await file.close();
    }
  }

  void _report() {
    final plan = _plan;
    if (plan == null || _stopped) return;
    final now = DateTime.now();
    final bytes = plan.downloaded;
    final seconds = now.difference(_lastSample).inMicroseconds / 1e6;
    if (seconds > 0) {
      final instant = (bytes - _lastBytes) / seconds;
      _speed = _speed == 0 ? instant : _speed * 0.6 + instant * 0.4;
    }
    _lastBytes = bytes;
    _lastSample = now;
    listener.onProgress(
      item.id,
      bytes,
      _speed,
      total: plan.size > 0 ? plan.size : null,
    );
    if (++_ticks % 4 == 0) unawaited(_savePlan());
  }

  String _describe(Object error) {
    if (error is _FatalHttp) return error.message;
    if (error is SocketException) {
      return 'Network error: ${error.osError?.message ?? error.message}';
    }
    if (error is TimeoutException) return 'Connection timed out';
    if (error is HttpException) return error.message;
    if (error is FileSystemException) {
      return 'Disk error: ${error.osError?.message ?? error.message}';
    }
    if (error is HandshakeException) return 'TLS handshake failed';
    return error.toString();
  }
}

/// The server asked us to slow down (429 Too Many Requests / 503).
class _Throttled implements Exception {
  const _Throttled(this.status, this.retryAfter);
  final int status;
  final Duration? retryAfter;
}

class _FatalHttp implements Exception {
  const _FatalHttp(this.message);
  final String message;
}

/// Extracts the file name from a `Content-Disposition` header.
String? parseContentDisposition(String? header) {
  if (header == null) return null;
  final extended = RegExp(
    r"filename\*\s*=\s*([^']*)'[^']*'([^;]+)",
    caseSensitive: false,
  ).firstMatch(header);
  if (extended != null) {
    try {
      return Uri.decodeComponent(extended.group(2)!.trim());
    } catch (_) {}
  }
  final plain = RegExp(
    r'filename\s*=\s*("([^"]*)"|[^;]+)',
    caseSensitive: false,
  ).firstMatch(header);
  final value = (plain?.group(2) ?? plain?.group(1))?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

/// Removes characters that are illegal in file names on any desktop OS.
String sanitizeFileName(String name) {
  final cleaned = name
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_')
      .trim();
  return cleaned.isEmpty ? 'download' : cleaned;
}

/// Returns [path], or `name (n).ext` if something already lives there.
Future<String> _uniquePath(String path) async {
  if (!await File(path).exists()) return path;
  final separator = path.lastIndexOf(Platform.pathSeparator);
  final dir = path.substring(0, separator + 1);
  final name = path.substring(separator + 1);
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  for (var n = 1; ; n++) {
    final candidate = '$dir$stem ($n)$ext';
    if (!await File(candidate).exists()) return candidate;
  }
}
