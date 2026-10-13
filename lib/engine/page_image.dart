import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Looks up artwork for [url]; null when there is none. See [findPageImage].
typedef PageImageFinder = Future<String?> Function(
  String url, {
  String userAgent,
  String proxy,
});

const _imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'avif'};

/// Artwork for a download: image files are their own preview, anything else
/// borrows the share image (`og:image` / `twitter:image`) of its website.
///
/// Download links rarely point at a page, so this reads the homepage of the
/// file's host and then of its parent domains (`cdn.blender.org`, then
/// `blender.org`). Only the first [maxHtmlBytes] of each page are read.
Future<String?> findPageImage(
  String url, {
  String userAgent = 'ZON/1.0',
  String proxy = '',
  Duration timeout = const Duration(seconds: 8),
  int maxHtmlBytes = 256 * 1024,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.isScheme('http') && !uri.isScheme('https')) {
    return null;
  }
  final path = uri.path.toLowerCase();
  final ext = path.contains('.') ? path.split('.').last : '';
  if (_imageExtensions.contains(ext)) return url;

  final client = HttpClient()
    ..connectionTimeout = timeout
    ..userAgent = userAgent;
  final hostPort = proxy.trim().replaceFirst(RegExp(r'^\w+://'), '');
  if (hostPort.isNotEmpty) client.findProxy = (_) => 'PROXY $hostPort';
  try {
    // Ask every host at once, but let the most specific one win.
    final pages = homepagesFor(uri);
    final lookups = [
      for (final page in pages)
        _fetchHtml(client, page, maxHtmlBytes)
            .timeout(timeout)
            .then((html) => html == null ? null : shareImageIn(html, page))
            .catchError((_) => null),
    ];
    for (final lookup in lookups) {
      final image = await lookup;
      if (image != null) return image;
    }
    return null;
  } finally {
    client.close(force: true);
  }
}

/// `https://cdn.example.co.uk/a.zip` → the homepages of `cdn.example.co.uk`
/// and `example.co.uk`. Stops at two labels, or three for short second-level
/// labels like `co.uk`, so it never asks a bare TLD.
List<Uri> homepagesFor(Uri uri) {
  if (uri.host.isEmpty || InternetAddress.tryParse(uri.host) != null) {
    return const [];
  }
  final labels = uri.host.split('.');
  final suffix = labels.length >= 3 && labels[labels.length - 2].length <= 3
      ? 3
      : 2;
  return [
    for (var i = 0; labels.length - i >= suffix; i++)
      Uri(scheme: uri.scheme, host: labels.sublist(i).join('.'), path: '/'),
  ];
}

Future<String?> _fetchHtml(HttpClient client, Uri page, int maxBytes) async {
  final request = await client.getUrl(page);
  request.headers.set(HttpHeaders.acceptHeader, 'text/html');
  final response = await request.close();
  final type = response.headers.contentType?.mimeType ?? '';
  if (response.statusCode != 200 || !type.contains('html')) {
    unawaited(response.drain<void>().catchError((_) {}));
    return null;
  }
  final bytes = <int>[];
  await for (final chunk in response) {
    bytes.addAll(chunk);
    if (bytes.length >= maxBytes) break;
  }
  return utf8.decode(bytes, allowMalformed: true);
}

/// The first share image declared in [html], resolved against [page].
String? shareImageIn(String html, Uri page) {
  const keys = [
    'og:image:secure_url',
    'og:image',
    'og:image:url',
    'twitter:image',
    'twitter:image:src',
  ];
  final found = <String, String>{};
  for (final tag in RegExp(
    r'<meta\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html)) {
    final attributes = _attributes(tag.group(0)!);
    final key = (attributes['property'] ?? attributes['name'])?.toLowerCase();
    final content = attributes['content']?.trim();
    if (key == null || content == null || content.isEmpty) continue;
    found.putIfAbsent(key, () => content);
  }
  for (final key in keys) {
    final value = found[key];
    if (value == null) continue;
    final Uri resolved;
    try {
      resolved = page.resolve(_unescape(value));
    } on FormatException {
      continue; // data: URIs and other junk
    }
    if (resolved.isScheme('http') || resolved.isScheme('https')) {
      return resolved.toString();
    }
  }
  return null;
}

Map<String, String> _attributes(String tag) => {
  for (final match in RegExp(
    r'''([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''',
  ).allMatches(tag))
    match.group(1)!.toLowerCase():
        match.group(2) ?? match.group(3) ?? match.group(4) ?? '',
};

String _unescape(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&#x2F;', '/')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');
