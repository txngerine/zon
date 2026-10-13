import 'package:flutter_test/flutter_test.dart';
import 'package:zon/data/app_state.dart';
import 'package:zon/domain/models/download.dart';
import 'package:zon/engine/page_image.dart';

void main() {
  group('shareImageIn', () {
    final page = Uri.parse('https://www.blender.org/');

    test('prefers og:image and resolves relative paths', () {
      const html = '''
        <head>
          <meta name="twitter:image" content="https://cdn.example.com/t.png">
          <meta content="/wp-content/og.jpg?a=1&amp;b=2" property="og:image" />
        </head>''';
      expect(
        shareImageIn(html, page),
        'https://www.blender.org/wp-content/og.jpg?a=1&b=2',
      );
    });

    test('falls back to twitter:image with single quotes', () {
      const html = "<meta name='twitter:image' content='//img.site/x.webp'>";
      expect(shareImageIn(html, page), 'https://img.site/x.webp');
    });

    test('ignores pages without share images and non-web schemes', () {
      expect(shareImageIn('<title>Hi</title>', page), isNull);
      expect(
        shareImageIn('<meta property="og:image" content="data:x">', page),
        isNull,
      );
    });
  });

  test('homepagesFor walks up to the registrable domain', () {
    List<String> hosts(String url) => [
      for (final uri in homepagesFor(Uri.parse(url))) uri.toString(),
    ];
    expect(hosts('https://cdn.blender.org/a/b.dmg'), [
      'https://cdn.blender.org/',
      'https://blender.org/',
    ]);
    expect(hosts('https://dl.files.example.co.uk/x.zip'), [
      'https://dl.files.example.co.uk/',
      'https://files.example.co.uk/',
      'https://example.co.uk/',
    ]);
    expect(hosts('http://192.168.1.4/file.iso'), isEmpty);
  });

  test('image files are their own artwork without a network call', () async {
    const url = 'https://example.com/photos/sunset.JPG';
    expect(await findPageImage(url), url);
  });

  group('AppState artwork', () {
    late List<String> asked;
    late AppState state;

    setUp(() {
      asked = [];
      state = AppState(
        pageImageFinder: (url, {userAgent = '', proxy = ''}) async {
          asked.add(url);
          return 'https://img.example/$userAgent.png';
        },
      );
    });

    tearDown(() => state.dispose());

    test('file downloads get artwork once', () async {
      state.createDownload(
        url: 'https://cdn.example.org/tool.dmg',
        startImmediately: false,
        notify: false,
      );
      await Future<void>.delayed(Duration.zero);

      final item = state.downloads.single;
      expect(item.thumbnailUrl, 'https://img.example/ZON/1.0.png');
      state.select(null);
      state.select(item.id);
      expect(asked, ['https://cdn.example.org/tool.dmg']);
    });

    test('media and torrents keep their own artwork', () async {
      state.createDownload(
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        startImmediately: false,
        notify: false,
      );
      state.createDownload(
        url: 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
        startImmediately: false,
        notify: false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(asked, isEmpty);
      expect(
        state.downloads.every((item) => item.status == DownloadStatus.queued),
        isTrue,
      );
    });
  });
}
