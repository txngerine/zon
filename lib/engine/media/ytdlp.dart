import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Metadata yt-dlp reports for a link before downloading.
class MediaInfo {
  const MediaInfo({
    required this.title,
    required this.site,
    this.id,
    this.uploader,
    this.thumbnail,
    this.duration,
    this.sizeEstimate,
    this.maxHeight,
    this.entries = const [],
    this.isPlaylist = false,
  });

  final String title;
  final String site;
  final String? id;
  final String? uploader;
  final String? thumbnail;
  final Duration? duration;
  final int? sizeEstimate;
  final int? maxHeight;
  final bool isPlaylist;

  /// Individual videos when [isPlaylist] is true.
  final List<MediaEntry> entries;

  static MediaInfo fromJson(Map<String, Object?> json) {
    final isPlaylist = json['_type'] == 'playlist';
    final rawEntries = json['entries'];
    final entries = <MediaEntry>[
      if (rawEntries is List)
        for (final raw in rawEntries)
          if (raw is Map) MediaEntry.fromJson(raw.cast<String, Object?>()),
    ].where((entry) => entry.url.isNotEmpty).toList();

    int? maxHeight;
    final formats = json['formats'];
    if (formats is List) {
      for (final format in formats) {
        if (format is! Map) continue;
        final height = (format['height'] as num?)?.toInt();
        if (height != null && (maxHeight == null || height > maxHeight)) {
          maxHeight = height;
        }
      }
    }

    final seconds = (json['duration'] as num?)?.toDouble();
    return MediaInfo(
      title: (json['title'] ?? json['id'] ?? 'Untitled').toString(),
      site: (json['extractor_key'] ?? json['extractor'] ?? 'Media').toString(),
      id: json['id']?.toString(),
      uploader: (json['uploader'] ?? json['channel'] ?? json['creator'])
          ?.toString(),
      thumbnail: _thumbnail(json),
      duration: seconds == null
          ? null
          : Duration(milliseconds: (seconds * 1000).round()),
      sizeEstimate: ((json['filesize'] ?? json['filesize_approx']) as num?)
          ?.toInt(),
      maxHeight: maxHeight,
      entries: entries,
      isPlaylist: isPlaylist,
    );
  }

  static String? _thumbnail(Map<String, Object?> json) {
    final direct = json['thumbnail'];
    if (direct is String && direct.isNotEmpty) return direct;
    final list = json['thumbnails'];
    if (list is List && list.isNotEmpty) {
      final last = list.last;
      if (last is Map && last['url'] is String) return last['url'] as String;
    }
    return null;
  }
}

class MediaEntry {
  const MediaEntry({required this.url, required this.title, this.duration});

  final String url;
  final String title;
  final Duration? duration;

  static MediaEntry fromJson(Map<String, Object?> json) {
    var url = (json['url'] ?? json['webpage_url'] ?? '').toString();
    final id = json['id']?.toString();
    final ie = json['ie_key']?.toString();
    if (!url.startsWith('http') && id != null && ie == 'Youtube') {
      url = 'https://www.youtube.com/watch?v=$id';
    }
    final seconds = (json['duration'] as num?)?.toDouble();
    return MediaEntry(
      url: url,
      title: (json['title'] ?? id ?? 'Untitled').toString(),
      duration: seconds == null ? null : Duration(seconds: seconds.round()),
    );
  }
}

class MediaToolException implements Exception {
  const MediaToolException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Finds, installs and queries the external tools media downloads need:
/// yt-dlp (extraction) and ffmpeg (merging HD streams, MP3 conversion).
class MediaTools {
  MediaTools({required this.binDir, Map<String, String>? environment})
    : _env = environment ?? Platform.environment;

  /// Where ZON keeps its own copy of yt-dlp.
  final String binDir;
  final Map<String, String> _env;

  String override = '';
  String? _ytDlp;
  String? _ffmpeg;
  String? _version;
  bool _resolved = false;

  String? get ytDlpPath => _ytDlp;
  String? get ffmpegPath => _ffmpeg;
  String? get version => _version;
  bool get hasYtDlp => _ytDlp != null;
  bool get hasFfmpeg => _ffmpeg != null;
  bool get resolved => _resolved;

  /// True when yt-dlp lives in [binDir], so ZON may update it itself.
  bool get isManaged => _ytDlp != null && _ytDlp!.startsWith(binDir);

  static String get _exe => Platform.isWindows ? '.exe' : '';

  List<String> get _searchDirs {
    final separator = Platform.isWindows ? ';' : ':';
    final home = _env['HOME'] ?? _env['USERPROFILE'] ?? '';
    final path = (_env['PATH'] ?? '')
        .split(separator)
        .where((dir) => dir.isNotEmpty);
    return [
      binDir,
      ...path,
      if (!Platform.isWindows) ...[
        // GUI apps on macOS do not inherit the shell's PATH.
        '/opt/homebrew/bin',
        '/usr/local/bin',
        '/usr/bin',
        '/opt/local/bin',
        '/snap/bin',
        if (home.isNotEmpty) '$home/.local/bin',
      ],
      if (Platform.isWindows) ...[
        if (_env['LOCALAPPDATA'] case final local?)
          '$local\\Microsoft\\WinGet\\Links',
        if (home.isNotEmpty) '$home\\scoop\\shims',
        'C:\\ProgramData\\chocolatey\\bin',
        'C:\\ffmpeg\\bin',
      ],
    ];
  }

  String? _find(String name) {
    for (final dir in _searchDirs) {
      final candidate = '$dir${Platform.pathSeparator}$name$_exe';
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  /// Re-scans for both tools and reads the yt-dlp version.
  Future<void> resolve() async {
    final explicit = override.trim();
    _ytDlp = explicit.isNotEmpty && File(explicit).existsSync()
        ? explicit
        : _find('yt-dlp');
    _ffmpeg = _find('ffmpeg');
    _version = null;
    if (_ytDlp != null) {
      try {
        final result = await Process.run(_ytDlp!, [
          '--version',
        ]).timeout(const Duration(seconds: 20));
        if (result.exitCode == 0) {
          _version = (result.stdout as String).trim();
        } else {
          _ytDlp = null;
        }
      } catch (_) {
        _ytDlp = null;
      }
    }
    _resolved = true;
  }

  String get _asset {
    if (Platform.isMacOS) return 'yt-dlp_macos';
    if (Platform.isWindows) return 'yt-dlp.exe';
    final arch = Process.runSync('uname', ['-m']).stdout.toString().trim();
    return arch == 'aarch64' || arch == 'arm64'
        ? 'yt-dlp_linux_aarch64'
        : 'yt-dlp_linux';
  }

  /// Downloads the official standalone yt-dlp build into [binDir].
  Future<void> install({void Function(double progress)? onProgress}) async {
    final url = Uri.parse(
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/$_asset',
    );
    final client = HttpClient()..userAgent = 'ZON/1.0';
    final target = File('$binDir${Platform.pathSeparator}yt-dlp$_exe');
    final temp = File('${target.path}.download');
    try {
      await Directory(binDir).create(recursive: true);
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw MediaToolException(
          'GitHub responded ${response.statusCode} while fetching yt-dlp',
        );
      }
      final total = response.contentLength;
      var received = 0;
      final sink = temp.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.close();
      if (await target.exists()) await target.delete();
      await temp.rename(target.path);
      if (!Platform.isWindows) {
        await Process.run('chmod', ['755', target.path]);
      }
      if (Platform.isMacOS) {
        await Process.run('xattr', ['-d', 'com.apple.quarantine', target.path]);
      }
    } on SocketException catch (error) {
      throw MediaToolException('Could not reach GitHub: ${error.message}');
    } finally {
      client.close(force: true);
      if (await temp.exists()) await temp.delete();
    }
    await resolve();
    if (!hasYtDlp) {
      throw const MediaToolException('yt-dlp was downloaded but will not run');
    }
  }

  /// Updates a ZON-managed yt-dlp in place. Returns the new version.
  Future<String> update() async {
    final path = _ytDlp;
    if (path == null) throw const MediaToolException('yt-dlp is not installed');
    if (!isManaged) {
      throw MediaToolException(
        'yt-dlp at $path is managed by your package manager — '
        'update it there (e.g. brew upgrade yt-dlp).',
      );
    }
    final result = await Process.run(path, [
      '-U',
    ]).timeout(const Duration(minutes: 3));
    await resolve();
    if (result.exitCode != 0) {
      throw MediaToolException(_lastError('${result.stderr}${result.stdout}'));
    }
    return _version ?? '';
  }

  /// Reads title, thumbnail, duration and playlist entries for [url].
  Future<MediaInfo> probe(
    String url, {
    String cookiesBrowser = 'None',
    String proxy = '',
  }) async {
    final path = _ytDlp;
    if (path == null) throw const MediaToolException('yt-dlp is not installed');
    final result = await Process.run(
      path,
      [
        '-J',
        '--flat-playlist',
        '--no-warnings',
        '--no-colors',
        ...cookieArgs(cookiesBrowser),
        if (proxy.trim().isNotEmpty) ...['--proxy', proxy.trim()],
        '--',
        url,
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      environment: utf8Environment,
    ).timeout(const Duration(seconds: 60));
    if (result.exitCode != 0) {
      throw MediaToolException(friendlyError(_lastError('${result.stderr}')));
    }
    final json = jsonDecode(result.stdout as String);
    return MediaInfo.fromJson((json as Map).cast<String, Object?>());
  }

  /// Clears yt-dlp's extractor cache (fixes some stale-signature failures).
  Future<void> clearCache() async {
    final path = _ytDlp;
    if (path == null) return;
    await Process.run(path, ['--rm-cache-dir']);
  }

  static const utf8Environment = {
    'PYTHONIOENCODING': 'utf-8',
    'PYTHONUTF8': '1',
  };

  static List<String> cookieArgs(String browser) {
    if (browser.isEmpty || browser == 'None') return const [];
    return ['--cookies-from-browser', browser.toLowerCase()];
  }

  static String _lastError(String output) {
    final lines = output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final error = lines.lastWhere(
      (line) => line.startsWith('ERROR:'),
      orElse: () => lines.isEmpty ? 'yt-dlp failed' : lines.last,
    );
    return error.replaceFirst('ERROR: ', '');
  }

  /// Rewrites yt-dlp's most common failures into actionable advice.
  static String friendlyError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('sign in to confirm') ||
        lower.contains('login required') ||
        lower.contains('log in') ||
        lower.contains('logged-in') ||
        lower.contains('cookies') ||
        lower.contains('rate-limit') ||
        lower.contains('private')) {
      return 'This site wants a logged-in session. Pick your browser under '
          'Settings › Media › Browser cookies, then retry.';
    }
    if (lower.contains('unsupported url')) {
      return 'This link is not a supported video or audio page.';
    }
    if (lower.contains('ffmpeg')) {
      return '$message — install ffmpeg to enable this format.';
    }
    return message;
  }
}
