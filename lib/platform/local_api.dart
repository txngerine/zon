import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/models/media_format.dart';

/// Tiny loopback HTTP server the browser bookmarklet talks to.
///
/// `GET /add?url=<link>[&format=audioMp3]` adds a download and returns a page
/// that closes itself. Only 127.0.0.1 is bound, so nothing outside this
/// machine can reach it.
class LocalApiServer {
  LocalApiServer({required this.onAdd, this.port = defaultPort});

  static const defaultPort = 6412;

  final void Function(String url, MediaFormat? format) onAdd;
  final int port;
  HttpServer? _server;

  bool get running => _server != null;

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
    response.headers.set('Access-Control-Allow-Origin', '*');
    try {
      switch (request.uri.path) {
        case '/ping':
          response.write('ZON');
        case '/add':
          final url = request.uri.queryParameters['url'] ?? '';
          final uri = Uri.tryParse(url);
          if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
            response.statusCode = HttpStatus.badRequest;
            response.write('Invalid url');
            break;
          }
          final format = request.uri.queryParameters['format'];
          onAdd(url, format == null ? null : MediaFormat.fromName(format));
          response.headers.contentType = ContentType.html;
          response.write(_sentPage(uri.host));
        default:
          response.statusCode = HttpStatus.notFound;
      }
    } finally {
      await response.close();
    }
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
  static String bookmarklet({MediaFormat? format, int port = defaultPort}) {
    final extra = format == null ? '' : '&format=${format.name}';
    return "javascript:(()=>{window.open('http://127.0.0.1:$port/add?url='"
        "+encodeURIComponent(location.href)+'$extra','zon',"
        "'width=360,height=120')})()";
  }
}
