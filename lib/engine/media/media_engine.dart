import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/models/download.dart';
import '../../domain/models/media_format.dart';
import '../engine.dart';
import 'media_sites.dart';
import 'ytdlp.dart';

/// Downloads video/audio pages (YouTube, Reels, TikTok, ...) through yt-dlp.
///
/// Each transfer is one yt-dlp process. Pausing kills the process; yt-dlp's
/// `.part` files let the next run continue where it stopped.
class MediaEngine implements TransferEngine {
  MediaEngine({required this.tools});

  final MediaTools tools;
  TransferListener? _listener;
  final Map<String, _MediaTask> _tasks = {};

  /// Media ids learned per download, used to clean up on cancel.
  final Map<String, String> _mediaIds = {};

  @override
  set listener(TransferListener listener) => _listener = listener;

  @override
  bool isRunning(String id) => _tasks.containsKey(id);

  @override
  void start(DownloadItem item, TransferOptions options) {
    final listener = _listener;
    if (listener == null || _tasks.containsKey(item.id)) return;
    // Report setup problems asynchronously, like any other failure.
    void fail(String reason) =>
        scheduleMicrotask(() => listener.onFailed(item.id, reason));
    final binary = tools.ytDlpPath;
    if (binary == null) {
      fail('yt-dlp is not installed — install it from Settings › Media.');
      return;
    }
    final format = item.mediaFormat ?? MediaFormat.videoBest;
    if (format.needsFfmpeg && !tools.hasFfmpeg) {
      fail(
        '${format.label} needs ffmpeg. Install it (brew install ffmpeg / '
        'winget install ffmpeg) and retry.',
      );
      return;
    }
    final task = _MediaTask(
      item: item,
      binary: binary,
      args: buildArgs(item, options, format: format, ffmpeg: tools.ffmpegPath),
      listener: listener,
      onMediaId: (value) => _mediaIds[item.id] = value,
    );
    _tasks[item.id] = task;
    task.run().whenComplete(() {
      if (identical(_tasks[item.id], task)) _tasks.remove(item.id);
    });
  }

  @override
  Future<void> pause(String id) async {
    await _tasks.remove(id)?.stop();
  }

  @override
  Future<void> cancel(String id) async {
    final task = _tasks.remove(id);
    await task?.stop();
    final mediaId = _mediaIds.remove(id);
    final item = task?.item;
    if (mediaId == null || item == null) return;
    final dir = item.savePath;
    final stem = item.nameLocked ? _stem(item) : null;
    // Remove yt-dlp's leftovers: `Title [id].f137.mp4.part`, `.ytdl`, ...
    try {
      await for (final entity in Directory(dir).list()) {
        final name = entity.uri.pathSegments.last;
        final ours =
            name.contains('[$mediaId]') ||
            (stem != null && name.startsWith(stem));
        if (!ours) continue;
        if (name.endsWith('.part') ||
            name.endsWith('.ytdl') ||
            RegExp(r'\.f\d+[\w-]*\.\w+$').hasMatch(name) ||
            name.contains('.part-Frag')) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  @override
  void setSpeedLimit(String id, int? bytesPerSecond) {
    // yt-dlp reads its rate once; the new cap applies on the next resume.
  }

  @override
  Future<void> dispose() async {
    final tasks = _tasks.values.toList();
    _tasks.clear();
    await Future.wait(tasks.map((task) => task.stop()));
  }

  /// The yt-dlp command line for [item]. Public for tests.
  static List<String> buildArgs(
    DownloadItem item,
    TransferOptions options, {
    required MediaFormat format,
    String? ffmpeg,
  }) {
    final hasFfmpeg = ffmpeg != null;
    final height = format.maxHeight;
    final cap = height == null ? '' : '[height<=$height]';

    final formatArgs = switch (format) {
      MediaFormat.audioMp3 => [
        '-f', 'ba/b', //
        '-x', '--audio-format', 'mp3',
        '--audio-quality', options.audioQuality,
      ],
      MediaFormat.audioM4a when hasFfmpeg => [
        '-f', 'ba[ext=m4a]/ba/b', //
        '-x', '--audio-format', 'm4a',
      ],
      MediaFormat.audioM4a => ['-f', 'ba[ext=m4a]/b[ext=mp4]/b'],
      _ when hasFfmpeg => [
        '-f', 'bv*$cap+ba/b$cap/bv*+ba/b', //
        // Highest resolution first; within it prefer H.264/AAC so the file
        // plays everywhere (QuickTime, phones, TVs).
        '-S', 'res${height == null ? '' : ':$height'},vcodec:h264,acodec:aac',
        '--merge-output-format', 'mp4',
      ],
      // No ffmpeg: only pre-muxed streams can be used.
      _ => ['-f', 'b$cap[ext=mp4]/b$cap/b'],
    };

    final rate = options.speedLimit;
    return [
      '--newline',
      '--progress',
      '--no-colors',
      '--no-simulate',
      '--no-quiet',
      '--no-playlist',
      // Collections are expanded by AppState; never fetch a whole list here.
      if (looksLikePlaylist(item.url)) ...['--playlist-items', '1'],
      '--continue',
      '--no-mtime',
      '--no-warnings',
      if (Platform.isWindows) '--windows-filenames',
      '--concurrent-fragments',
      '${item.connections.clamp(1, 8)}',
      '--retries',
      '${options.retryCount}',
      '--fragment-retries',
      '${options.retryCount}',
      '--socket-timeout',
      '${options.connectionTimeout.inSeconds}',
      if (rate != null) ...['--limit-rate', '$rate'],
      if (options.proxy.trim().isNotEmpty) ...['--proxy', options.proxy.trim()],
      ...MediaTools.cookieArgs(options.cookiesBrowser),
      if (ffmpeg != null) ...['--ffmpeg-location', ffmpeg],
      if (options.embedMetadata) '--embed-metadata',
      if (options.embedMetadata && format.isAudio && hasFfmpeg)
        '--embed-thumbnail',
      ...formatArgs,
      '-P',
      item.savePath,
      '-o',
      item.nameLocked
          ? '${_stem(item)}.%(ext)s'
          : '%(title).150B [%(id)s].%(ext)s',
      '--progress-template',
      'download:ZONP|%(progress.status)s|%(progress.downloaded_bytes)s|'
          '%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|'
          '%(progress.speed)s',
      '--print',
      'before_dl:ZONS|%(id)s|%(filesize,filesize_approx|NA)s|'
          '%(thumbnail|)s|%(title)s',
      '--print',
      'after_move:ZONF|%(filepath)s',
      '--',
      item.url,
    ];
  }
}

/// The user's chosen name without extension, safe for yt-dlp's template.
String _stem(DownloadItem item) {
  var name = item.fileName.replaceAll(RegExp(r'[/\\<>:"|?*\x00-\x1F]'), '_');
  final dot = name.lastIndexOf('.');
  if (dot > 0 && name.length - dot <= 5) name = name.substring(0, dot);
  return name.replaceAll('%', '%%').trim();
}

class _MediaTask {
  _MediaTask({
    required this.item,
    required this.binary,
    required this.args,
    required this.listener,
    required this.onMediaId,
  });

  final DownloadItem item;
  final String binary;
  final List<String> args;
  final TransferListener listener;
  final void Function(String) onMediaId;

  Process? _process;
  bool _stopped = false;
  final Completer<void> _done = Completer<void>();

  String? _finalPath;
  String? _lastError;
  int _estimate = 0;
  int _finishedStreams = 0;
  int _streamBytes = 0;
  int _streamTotal = 0;

  Future<void> run() async {
    try {
      await Directory(item.savePath).create(recursive: true);
      final process = await Process.start(
        binary,
        args,
        environment: MediaTools.utf8Environment,
      );
      _process = process;
      if (_stopped) process.kill();

      final stdoutDone = process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .forEach(_onLine);
      final stderrDone = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .forEach(_onLine);
      final code = await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);

      if (_stopped) return;
      final path = _finalPath;
      if (code == 0 && path != null) {
        int? size;
        try {
          size = await File(path).length();
        } catch (_) {}
        if (size != null) listener.onProgress(item.id, size, 0, total: size);
        listener.onCompleted(item.id, path);
      } else {
        listener.onFailed(
          item.id,
          MediaTools.friendlyError(_lastError ?? 'yt-dlp exited with $code'),
        );
      }
    } on ProcessException catch (error) {
      if (!_stopped) {
        listener.onFailed(item.id, 'Could not run yt-dlp: ${error.message}');
      }
    } finally {
      if (!_done.isCompleted) _done.complete();
    }
  }

  Future<void> stop() async {
    _stopped = true;
    final process = _process;
    if (process == null) return;
    process.kill();
    await _done.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => process.kill(ProcessSignal.sigkill),
    );
  }

  void _onLine(String raw) {
    final line = raw.trim();
    if (line.isEmpty) return;

    if (line.startsWith('ZONP|')) {
      _onProgress(line.split('|'));
    } else if (line.startsWith('ZONS|')) {
      final parts = line.split('|');
      if (parts.length >= 5) {
        onMediaId(parts[1]);
        _estimate = int.tryParse(parts[2]) ?? _estimate;
        final thumbnail = parts[3].isEmpty ? null : parts[3];
        final format = item.mediaFormat ?? MediaFormat.videoBest;
        final title = parts.sublist(4).join('|');
        listener.onMeta(
          item.id,
          TransferMeta(
            fileName: item.nameLocked ? null : '$title.${format.extension}',
            sizeBytes: _estimate > 0 ? _estimate : null,
            thumbnailUrl: thumbnail,
            resumeSupported: true,
            contentType: format.isAudio
                ? 'audio/${format.extension == 'mp3' ? 'mpeg' : 'mp4'}'
                : 'video/mp4',
            server: 'yt-dlp',
            httpStatus: 200,
          ),
        );
      }
    } else if (line.startsWith('ZONF|')) {
      _finalPath = line.substring(5);
    } else if (line.startsWith('ERROR:')) {
      _lastError = line.substring(6).trim();
    } else if (line.startsWith('[Merger]')) {
      listener.onPhase(item.id, 'Merging audio & video');
    } else if (line.startsWith('[ExtractAudio]')) {
      final format = item.mediaFormat ?? MediaFormat.audioMp3;
      listener.onPhase(item.id, 'Converting to ${format.label}');
    } else if (line.startsWith('[EmbedThumbnail]')) {
      listener.onPhase(item.id, 'Embedding artwork');
    } else if (line.startsWith('[Metadata]')) {
      listener.onPhase(item.id, 'Writing tags');
    } else if (line.startsWith('[FixupM3u8]') ||
        line.startsWith('[FixupM4a]') ||
        line.startsWith('[VideoConvertor]')) {
      listener.onPhase(item.id, 'Finalising');
    }
  }

  void _onProgress(List<String> parts) {
    if (parts.length < 6) return;
    int? number(String value) => double.tryParse(value)?.round();
    final status = parts[1];
    final downloaded = number(parts[2]) ?? 0;
    final total = number(parts[3]) ?? number(parts[4]) ?? 0;
    final speed = double.tryParse(parts[5]) ?? 0;

    if (status == 'finished') {
      _finishedStreams += total > 0 ? total : downloaded;
      _streamBytes = 0;
      _streamTotal = 0;
    } else {
      _streamBytes = downloaded;
      _streamTotal = total;
    }

    final soFar = _finishedStreams + _streamBytes;
    var whole = _finishedStreams + _streamTotal;
    if (_estimate > whole) whole = _estimate;
    if (soFar > whole) whole = soFar;
    listener.onProgress(
      item.id,
      soFar,
      status == 'finished' ? 0 : speed,
      total: whole > 0 ? whole : null,
    );
  }
}
