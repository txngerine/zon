import 'package:flutter_test/flutter_test.dart';
import 'package:zon/data/app_state.dart';
import 'package:zon/domain/models/download.dart';
import 'package:zon/domain/models/media_format.dart';
import 'package:zon/engine/media/pinterest.dart';
import 'package:zon/engine/media/ytdlp.dart';

import 'app_state_test.dart' show FakeEngine;

// Trimmed from real `pinterest-dl scrape --json` output (v1.3.0).
const _scrape = '''
{
  "command": "scrape",
  "results": [
    {
      "input": "https://www.pinterest.com/someone/recipes/",
      "items": [
        {
          "id": 3025924747341467,
          "src": "https://i.pinimg.com/736x/10/74/96/1074963.jpg",
          "alt": "28-Aug-2026 — Tasty Suji Recipe 🥰#viral #reels | Simple dish recipes",
          "origin": "https://www.pinterest.com/pin/3025924747341467/",
          "resolution": {"x": 720, "y": 1280},
          "media_stream": {"video": {
            "url": "https://v1.pinimg.com/videos/iht/hls/2d/c3/f9/2dc3f9.m3u8",
            "resolution": [720, 1280], "duration": 45967}}
        },
        {
          "id": "111",
          "src": "https://i.pinimg.com/originals/aa/bb/cc/photo.png",
          "alt": null,
          "origin": "https://www.pinterest.com/pin/111/",
          "resolution": {"x": 1080, "y": 1350}
        },
        {
          "id": "222",
          "src": "https://i.pinimg.com/originals/dd/ee/ff/cover.jpg",
          "alt": "Morning stretch",
          "origin": "https://www.pinterest.com/pin/222/",
          "resolution": {"x": 720, "y": 1280},
          "media_stream": {"video": {
            "url": "https://v1.pinimg.com/videos/mc/720p/aa/bb/clip.mp4",
            "resolution": [720, 1280], "duration": 12000}}
        }
      ]
    }
  ]
}''';

class _FakeTools extends MediaTools {
  _FakeTools() : super(binDir: '/nonexistent', environment: const {});

  final asked = <String>[];

  @override
  bool get hasPinterestDl => true;

  @override
  Future<List<PinterestPin>> resolvePinterest(
    String url, {
    int boardLimit = 100,
  }) async {
    asked.add(url);
    return PinterestPin.parseScrape(_scrape);
  }
}

void main() {
  group('Pinterest links', () {
    test('recognises pins, boards, regional domains and pin.it', () {
      expect(isPinterestUrl('https://www.pinterest.com/pin/123/'), isTrue);
      expect(isPinterestUrl('https://in.pinterest.com/user/board/'), isTrue);
      expect(isPinterestUrl('https://www.pinterest.co.uk/pin/1/'), isTrue);
      expect(isPinterestUrl('https://pinterest.com.au/pin/1/'), isTrue);
      expect(isPinterestUrl('https://pin.it/4bCdEf'), isTrue);
      expect(isPinterestUrl('https://notpinterest.com/pin/1/'), isFalse);
      expect(isPinterestUrl('https://i.pinimg.com/originals/a.jpg'), isFalse);
      expect(isPinterestPin('https://www.pinterest.com/pin/123/'), isTrue);
      expect(isPinterestPin('https://www.pinterest.com/user/board/'), isFalse);
    });

    test('parses pinterest-dl JSON', () {
      final pins = PinterestPin.parseScrape('log line\n$_scrape');
      expect(pins, hasLength(3));
      expect(pins[0].id, '3025924747341467');
      expect(pins[0].title, 'Tasty Suji Recipe 🥰');
      expect(pins[0].videoUrl, endsWith('.m3u8'));
      expect(pins[0].duration, const Duration(milliseconds: 45967));
      expect(pins[1].isVideo, isFalse);
      expect(pins[1].title, 'Pinterest 111');
      expect(PinterestPin.parseScrape('not json'), isEmpty);
    });

    test('cleans long alt text into a short title', () {
      final long = 'word ' * 40;
      expect(cleanPinTitle(long, '1').length, lessThanOrEqualTo(80));
      expect(cleanPinTitle('a/b: c?', '1'), 'a b c');
    });
  });

  group('AppState with pinterest-dl', () {
    late FakeEngine http;
    late FakeEngine media;
    late _FakeTools tools;
    late AppState state;

    setUp(() {
      http = FakeEngine();
      media = FakeEngine();
      tools = _FakeTools();
      state = AppState(httpEngine: http, mediaEngine: media, mediaTools: tools);
    });

    tearDown(() => state.dispose());

    test('a board becomes one download per pin', () async {
      final count = await state.addLink(
        'https://www.pinterest.com/someone/recipes/',
      );
      expect(count, 3);
      expect(tools.asked, ['https://www.pinterest.com/someone/recipes/']);

      DownloadItem named(String prefix) =>
          state.downloads.firstWhere((d) => d.fileName.startsWith(prefix));

      final hls = named('Tasty Suji Recipe');
      expect(hls.kind, DownloadKind.media);
      expect(hls.url, endsWith('.m3u8'));
      expect(hls.source, 'Pinterest');
      expect(hls.thumbnailUrl, contains('pinimg.com'));

      final image = named('Pinterest 111');
      expect(image.kind, DownloadKind.file);
      expect(image.fileName, 'Pinterest 111.png');

      final mp4 = named('Morning stretch');
      expect(mp4.kind, DownloadKind.file);
      expect(mp4.fileName, 'Morning stretch.mp4');
    });

    test('MP3 sends even plain mp4 pins through yt-dlp', () async {
      await state.addLink(
        'https://www.pinterest.com/pin/222/',
        mediaFormat: MediaFormat.audioMp3,
      );
      final mp4 = state.downloads.firstWhere((d) => d.url.endsWith('clip.mp4'));
      expect(mp4.kind, DownloadKind.media);
      expect(mp4.mediaFormat, MediaFormat.audioMp3);
    });
  });
}
