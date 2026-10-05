import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../domain/models/media_format.dart';

/// Tiny loopback HTTP server for the browser bookmarklet and for handing
/// links from a second ZON process (magnet handler) to the running one.
///
/// `GET /add?t=<token>&url=<link>[&format=audioMp3]` adds a download and
/// returns a page that closes itself. `path=<file>` adds a local `.torrent`.
///
/// Only 127.0.0.1 is bound, but any web page can still make the browser
/// request a loopback URL, so every request must carry the per-install
/// [token] (baked into the user's bookmarklet). Without it the request is
/// refused; a malicious page cannot read or guess it.
class LocalApiServer {
  LocalApiServer({
    required this.onAdd,
    required this.onAddFile,
    required this.token,
    this.port = defaultPort,
  });

  static const defaultPort = 6412;

  final void Function(String url, MediaFormat? format) onAdd;
  final void Function(String path) onAddFile;

  /// Returns the current secret (read on every request so it can rotate).
  final String Function() token;
  final int port;
  HttpServer? _server;

  bool get running => _server != null;

  /// A fresh random secret for [token].
  static String newToken() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<bool> start() async {
    if (_server != null) return true;
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _server = server;
      server.listen(_handle, onError: (_) {});
      return true;
    } on SocketException {
      return false;
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final query = request.uri.queryParameters;
    try {
      if (request.uri.path == '/ping') {
        response.write('ZON');
        return;
      }
      if (request.uri.path != '/add') {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final expected = token();
      if (expected.isEmpty ||
          !_constantTimeEquals(query['t'] ?? '', expected)) {
        response.statusCode = HttpStatus.forbidden;
        response.write('Forbidden — copy a fresh bookmarklet from ZON.');
        return;
      }

      final path = query['path'];
      if (path != null) {
        if (!path.toLowerCase().endsWith('.torrent')) {
          response.statusCode = HttpStatus.badRequest;
          return;
        }
        onAddFile(path);
        response.write('OK');
        return;
      }

      final url = query['url'] ?? '';
      final uri = Uri.tryParse(url);
      final valid =
          uri != null &&
          (uri.scheme == 'http' ||
              uri.scheme == 'https' ||
              uri.scheme == 'magnet');
      if (!valid) {
        response.statusCode = HttpStatus.badRequest;
        response.write('Invalid url');
        return;
      }
      final format = query['format'];
      onAdd(url, format == null ? null : MediaFormat.fromName(format));
      response.headers.contentType = ContentType.html;
      response.write(_sentPage(uri.scheme == 'magnet' ? 'magnet' : uri.host));
    } finally {
      await response.close();
    }
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _sentPage(String host) {
    final safe = const HtmlEscape().convert(host);
    return '<!doctype html><meta charset="utf-8"><title>Sent to ZON</title>'
        '<body style="font:15px -apple-system,Segoe UI,sans-serif;'
        'background:#0b0b0c;color:#f4f4f5;display:grid;place-items:center;'
        'height:100vh;margin:0"><div>✓ Sent to ZON <span style="opacity:.5">'
        '— $safe</span></div><script>setTimeout(()=>window.close(),900)'
        '</script>';
  }

  /// Bookmarklet that sends the current page to ZON.
  static String bookmarklet({
    required String token,
    MediaFormat? format,
    int port = defaultPort,
  }) {
    final extra = format == null ? '' : '&format=${format.name}';
    return "javascript:(()=>{window.open('http://127.0.0.1:$port/add?t=$token"
        "$extra&url='+encodeURIComponent(location.href),'zon',"
        "'width=360,height=120')})()";
  }

  /// Hands [link] (URL, magnet or `.torrent` path) to an already running ZON.
  /// Returns false when none is listening.
  static Future<bool> forward(
    String link, {
    required String token,
    int port = defaultPort,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 800);
    try {
      final isFile = !link.contains(':') || File(link).existsSync();
      final uri = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: port,
        path: '/add',
        queryParameters: {
          't': token,
          if (isFile) 'path': File(link).absolute.path else 'url': link,
        },
      );
      final response = await (await client.getUrl(uri))
          .close()
          .timeout(const Duration(seconds: 3));
      await response.drain<void>();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
