/// Pinterest pins, boards and short links, resolved with pinterest-dl
/// (https://github.com/sean1832/pinterest-dl) when it is installed.
library;

import 'dart:convert';

final _pinterestHost = RegExp(
  r'(^|\.)pinterest\.(com|co\.[a-z]{2}|com\.[a-z]{2}|[a-z]{2})$',
);

/// True for any Pinterest page (pin, board, section, profile) or `pin.it`
/// short link, on every regional domain.
bool isPinterestUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return false;
  final host = uri.host.toLowerCase();
  return host == 'pin.it' || _pinterestHost.hasMatch(host);
}

bool isPinterestShortLink(String url) =>
    Uri.tryParse(url.trim())?.host.toLowerCase() == 'pin.it';

/// True for a single pin rather than a board or section.
bool isPinterestPin(String url) =>
    (Uri.tryParse(url.trim())?.path ?? '').contains('/pin/');

/// One pin as reported by `pinterest-dl scrape --json`.
class PinterestPin {
  const PinterestPin({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.videoUrl,
    this.duration,
  });

  final String id;
  final String title;

  /// Full-size image (the cover frame for video pins).
  final String imageUrl;

  /// Highest-resolution stream: an `.m3u8` playlist or a plain `.mp4`.
  final String? videoUrl;
  final Duration? duration;

  bool get isVideo => videoUrl != null;

  static PinterestPin? fromJson(Map<String, Object?> json) {
    final id = json['id']?.toString() ?? '';
    final src = json['src']?.toString() ?? '';
    if (id.isEmpty || src.isEmpty) return null;
    String? videoUrl;
    Duration? duration;
    final stream = json['media_stream'];
    if (stream is Map && stream['video'] is Map) {
      final video = stream['video'] as Map;
      final url = video['url']?.toString() ?? '';
      if (url.startsWith('http')) videoUrl = url;
      final ms = (video['duration'] as num?)?.toInt();
      if (ms != null && ms > 0) duration = Duration(milliseconds: ms);
    }
    return PinterestPin(
      id: id,
      title: cleanPinTitle(json['alt']?.toString(), id),
      imageUrl: src,
      videoUrl: videoUrl,
      duration: duration,
    );
  }

  /// Every pin in pinterest-dl's `--json` output.
  static List<PinterestPin> parseScrape(String stdout) {
    // Tolerate stray log lines before the JSON document.
    final start = stdout.indexOf('{');
    if (start < 0) return const [];
    final Object? json;
    try {
      json = jsonDecode(stdout.substring(start));
    } on FormatException {
      return const [];
    }
    if (json is! Map || json['results'] is! List) return const [];
    return [
      for (final result in json['results'] as List)
        if (result is Map && result['items'] is List)
          for (final item in result['items'] as List)
            if (item is Map)
              PinterestPin.fromJson(item.cast<String, Object?>()),
    ].whereType<PinterestPin>().toList();
  }
}

/// A short file-name-friendly title from a pin's alt text, which is often
/// "date — caption #tags | board keywords".
String cleanPinTitle(String? alt, String id) {
  var text = (alt ?? '').split(' | ').first;
  text = text.replaceFirst(RegExp(r'^\d{1,2}-\w{3}-\d{4}\s*[—-]\s*'), '');
  final hashtag = text.indexOf('#');
  if (hashtag >= 0) text = text.substring(0, hashtag);
  text = text.replaceAll(RegExp(r'[/\\<>:"|?*\x00-\x1F]'), ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length > 80) {
    final cut = text.lastIndexOf(' ', 80);
    text = text.substring(0, cut > 40 ? cut : 80).trim();
  }
  return text.isEmpty ? 'Pinterest $id' : text;
}
