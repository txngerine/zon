import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zon/platform/local_api.dart';

void main() {
  const port = 16413;
  late LocalApiServer server;
  late List<String> added;

  setUp(() async {
    added = [];
    server = LocalApiServer(
      port: port,
      token: () => 'k3y',
      onAdd: (url, _) => added.add(url),
      onAddFile: (_) {},
    );
    expect(await server.start(), isTrue);
  });

  tearDown(() => server.stop());

  Future<HttpClientResponse> get(
    String path, {
    String? origin,
    String method = 'GET',
  }) async {
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:$port$path'),
    );
    if (origin != null) request.headers.set('origin', origin);
    final response = await request.close();
    await response.drain<void>();
    return response;
  }

  test('extension pages may read answers; websites may not', () async {
    const chrome = 'chrome-extension://liaielcekemcibgmibiccpaigdaacfeg';
    const firefox = 'moz-extension://0d0c4a6e-2f5b-4c6b-9a43-5e0f2a7d9b11';
    for (final origin in [chrome, firefox]) {
      final response = await get('/hello?t=k3y', origin: origin);
      expect(response.statusCode, 200);
      expect(response.headers.value('access-control-allow-origin'), origin);
    }
    final web = await get('/hello?t=k3y', origin: 'https://evil.example');
    expect(web.headers.value('access-control-allow-origin'), isNull);
  });

  test('a send from an extension origin is added and readable', () async {
    final response = await get(
      '/add?t=k3y&url=${Uri.encodeQueryComponent('https://example.com/a.zip')}',
      origin: 'moz-extension://abc',
    );
    expect(response.statusCode, 200);
    expect(response.headers.value('access-control-allow-origin'), isNotNull);
    expect(added, ['https://example.com/a.zip']);
  });

  test('the key is still required from extension origins', () async {
    final response = await get(
      '/add?t=wrong&url=https://example.com/a.zip',
      origin: 'chrome-extension://abc',
    );
    expect(response.statusCode, 403);
    expect(added, isEmpty);
  });

  test('preflight requests are answered', () async {
    final response = await get(
      '/add',
      origin: 'chrome-extension://abc',
      method: 'OPTIONS',
    );
    expect(response.statusCode, 204);
  });

  test('a second ZON on the same port explains itself', () async {
    final second = LocalApiServer(
      port: port,
      token: () => 'k3y',
      onAdd: (_, _) {},
      onAddFile: (_) {},
    );
    final results = await Future.wait([second.start(), second.start()]);
    expect(results, [false, false]);
    expect(second.problem, contains('Another copy of ZON'));
  });

  test('another app on the port is reported as such', () async {
    await server.stop();
    final squatter = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    addTearDown(() => squatter.close(force: true));
    squatter.listen((request) {
      request.response.write('not zon');
      request.response.close();
    });
    final blocked = LocalApiServer(
      port: port,
      token: () => 'k3y',
      onAdd: (_, _) {},
      onAddFile: (_) {},
    );
    expect(await blocked.start(), isFalse);
    expect(blocked.problem, contains('taken by another app'));
  });
}
