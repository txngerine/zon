import 'package:flutter_test/flutter_test.dart';
import 'package:zon/domain/models/download.dart';
import 'package:zon/domain/models/media_format.dart';
import 'package:zon/engine/engine.dart';
import 'package:zon/engine/media/media_engine.dart';
import 'package:zon/engine/media/media_sites.dart';
import 'package:zon/engine/media/ytdlp.dart';
import 'package:zon/presentation/shell/zon_shell.dart';

DownloadItem _media(MediaFormat format, {bool locked = false}) {
  final now = DateTime.now();
  return DownloadItem(
    id: 'm',
    fileName: locked ? 'My Mix.mp3' : 'YouTube video',
    url: 'https://youtu.be/abc',
    source: 'YouTube',
    sizeBytes: 0,
    downloadedBytes: 0,
    status: DownloadStatus.queued,
    savePath: '/tmp/zon',
    addedAt: now,
    lastActivity: now,
    connections: 16,
    kind: DownloadKind.media,
    mediaFormat: format,
    nameLocked: locked,
  );
}

void main() {
  group('detectMediaSite', () {
    test('recognises popular video sites', () {
      expect(
        detectMediaSite('https://www.youtube.com/watch?v=x')?.name,
        'YouTube',
      );
      expect(detectMediaSite('https://youtu.be/x')?.name, 'YouTube');
      expect(
        detectMediaSite('https://www.youtube.com/shorts/x')?.name,
        'YouTube',
      );
      expect(
        detectMediaSite('https://music.youtube.com/watch?v=x')?.name,
        'YouTube Music',
      );
      expect(
        detectMediaSite('https://www.instagram.com/reel/abc/')?.name,
        'Instagram',
      );
      expect(
        detectMediaSite('https://www.instagram.com/reels/abc/')?.name,
        'Instagram',
      );
      expect(detectMediaSite('https://vm.tiktok.com/ZM123/')?.name, 'TikTok');
      expect(detectMediaSite('https://x.com/user/status/123')?.name, 'X');
      expect(
        detectMediaSite('https://cdn.example.com/live/index.m3u8')?.name,
        'Stream',
      );
    });

    test('leaves plain files and non-video pages alone', () {
      expect(detectMediaSite('https://example.com/file.iso'), isNull);
      expect(detectMediaSite('https://www.instagram.com/someone/'), isNull);
      expect(detectMediaSite('https://x.com/someone'), isNull);
      expect(detectMediaSite('https://notyoutube.com/watch'), isNull);
      expect(detectMediaSite('not a url'), isNull);
    });
  });

  test('looksLikePlaylist separates collections from single videos', () {
    expect(
      looksLikePlaylist('https://www.youtube.com/playlist?list=PL123'),
      isTrue,
    );
    expect(looksLikePlaylist('https://www.youtube.com/@channel'), isTrue);
    expect(
      looksLikePlaylist('https://www.youtube.com/watch?v=a&list=PL123'),
      isFalse,
    );
    expect(looksLikePlaylist('https://youtu.be/abc'), isFalse);
    expect(looksLikePlaylist('https://soundcloud.com/a/sets/b'), isTrue);
    expect(looksLikePlaylist('https://example.com/list?list=1'), isFalse);
  });

  group('MediaEngine.buildArgs', () {
    test('playlist links are capped to one item as a safety net', () {
      final now = DateTime.now();
      final item = DownloadItem(
        id: 'p',
        fileName: 'x',
        url: 'https://www.youtube.com/playlist?list=PL1',
        source: 'YouTube',
        sizeBytes: 0,
        downloadedBytes: 0,
        status: DownloadStatus.queued,
        savePath: '/tmp',
        addedAt: now,
        lastActivity: now,
        connections: 4,
        kind: DownloadKind.media,
      );
      final args = MediaEngine.buildArgs(
        item,
        const TransferOptions(),
        format: MediaFormat.videoBest,
      );
      expect(args, containsAllInOrder(['--playlist-items', '1']));
    });

    const options = TransferOptions(audioQuality: '192K');

    test('MP3 extracts audio at the chosen bitrate', () {
      final args = MediaEngine.buildArgs(
        _media(MediaFormat.audioMp3),
        options,
        format: MediaFormat.audioMp3,
        ffmpeg: '/usr/bin/ffmpeg',
      );
      expect(args, containsAllInOrder(['-x', '--audio-format', 'mp3']));
      expect(args, containsAllInOrder(['--audio-quality', '192K']));
      expect(
        args,
        containsAllInOrder(['--ffmpeg-location', '/usr/bin/ffmpeg']),
      );
      expect(args.last, 'https://youtu.be/abc');
      expect(args[args.length - 2], '--');
    });

    test('capped video merges best streams at or below the height', () {
      final args = MediaEngine.buildArgs(
        _media(MediaFormat.video720),
        options,
        format: MediaFormat.video720,
        ffmpeg: '/usr/bin/ffmpeg',
      );
      final selector = args[args.indexOf('-f') + 1];
      expect(selector, startsWith('bv*[height<=720]+ba'));
      expect(args, containsAllInOrder(['--merge-output-format', 'mp4']));
      expect(args, contains('--concurrent-fragments'));
      expect(args[args.indexOf('--concurrent-fragments') + 1], '8');
    });

    test('4K stops at 2160p and sorts closest to it', () {
      final args = MediaEngine.buildArgs(
        _media(MediaFormat.video2160),
        options,
        format: MediaFormat.video2160,
        ffmpeg: '/usr/bin/ffmpeg',
      );
      expect(
        args[args.indexOf('-f') + 1],
        'bv*[height<=2160]+ba/b[height<=2160]/bv*+ba/b',
      );
      expect(args[args.indexOf('-S') + 1], 'res:2160,vcodec:h264,acodec:aac');
      expect(args, containsAllInOrder(['--merge-output-format', 'mp4']));
    });

    test('best video leaves the height uncapped', () {
      final args = MediaEngine.buildArgs(
        _media(MediaFormat.videoBest),
        options,
        format: MediaFormat.videoBest,
        ffmpeg: '/usr/bin/ffmpeg',
      );
      expect(args[args.indexOf('-f') + 1], 'bv*+ba/b/bv*+ba/b');
      expect(args[args.indexOf('-S') + 1], 'res,vcodec:h264,acodec:aac');
      expect(MediaFormat.videoBest.maxHeight, isNull);
      expect(MediaFormat.video2160.maxHeight, 2160);
    });

    test('video above 720p only exists as streams to merge', () {
      expect(MediaFormat.video2160.needsFfmpeg, isTrue);
      expect(MediaFormat.video1080.needsFfmpeg, isTrue);
      expect(MediaFormat.video720.needsFfmpeg, isFalse);
      expect(MediaFormat.video480.needsFfmpeg, isFalse);
      expect(MediaFormat.videoBest.needsFfmpeg, isFalse);
      expect(MediaFormat.audioMp3.needsFfmpeg, isTrue);
      expect(MediaFormat.audioM4a.needsFfmpeg, isFalse);
    });

    test('a quality fits only when the link can supply it', () {
      expect(MediaFormat.video2160.fitsVideo(2160), isTrue);
      expect(MediaFormat.video2160.fitsVideo(1080), isFalse);
      expect(MediaFormat.video1080.fitsVideo(1440), isTrue);
      expect(MediaFormat.video1080.fitsVideo(720), isFalse);
      expect(MediaFormat.video1080.fitsVideo(null), isTrue);
      expect(MediaFormat.videoBest.fitsVideo(360), isTrue);
      expect(MediaFormat.audioMp3.fitsVideo(360), isTrue);
      expect(MediaFormat.audioM4a.fitsVideo(null), isTrue);
    });

    test('without ffmpeg only pre-muxed streams are requested', () {
      final args = MediaEngine.buildArgs(
        _media(MediaFormat.videoBest),
        options,
        format: MediaFormat.videoBest,
      );
      expect(args[args.indexOf('-f') + 1], 'b[ext=mp4]/b/b');
      expect(args, isNot(contains('--merge-output-format')));
    });

    test('a user-chosen name becomes the output template', () {
      final args = MediaEngine.buildArgs(
        _media(MediaFormat.audioMp3, locked: true),
        options,
        format: MediaFormat.audioMp3,
        ffmpeg: '/usr/bin/ffmpeg',
      );
      expect(args[args.indexOf('-o') + 1], 'My Mix.%(ext)s');
    });

    test('cookies and speed limits are passed through', () {
      final args = MediaEngine.buildArgs(
        _media(MediaFormat.videoBest),
        const TransferOptions(cookiesBrowser: 'Firefox', speedLimit: 1048576),
        format: MediaFormat.videoBest,
      );
      expect(args, containsAllInOrder(['--cookies-from-browser', 'firefox']));
      expect(args, containsAllInOrder(['--limit-rate', '1048576']));
    });
  });

  test('MediaInfo parses playlists and videos', () {
    final playlist = MediaInfo.fromJson({
      '_type': 'playlist',
      'title': 'Mix',
      'extractor_key': 'YoutubeTab',
      'entries': [
        {'id': 'a1', 'ie_key': 'Youtube', 'title': 'One', 'duration': 61},
        {'url': 'https://www.youtube.com/watch?v=b2', 'title': 'Two'},
      ],
    });
    expect(playlist.isPlaylist, isTrue);
    expect(playlist.entries.map((e) => e.url), [
      'https://www.youtube.com/watch?v=a1',
      'https://www.youtube.com/watch?v=b2',
    ]);

    final video = MediaInfo.fromJson({
      'title': 'Clip',
      'duration': 19.5,
      'thumbnails': [
        {'url': 'small.jpg'},
        {'url': 'big.jpg'},
      ],
      'formats': [
        {'height': 360},
        {'height': 1080},
        {'height': null},
      ],
    });
    expect(video.isPlaylist, isFalse);
    expect(video.thumbnail, 'big.jpg');
    expect(video.maxHeight, 1080);
    expect(video.duration, const Duration(milliseconds: 19500));
  });

  test('size estimate falls back to the highest stream', () {
    final info = MediaInfo.fromJson({
      'title': 'Clip',
      'formats': [
        {'height': 720, 'filesize_approx': 12000000},
        {'height': 2160, 'filesize_approx': 980000000},
        {'height': null},
      ],
    });
    expect(info.maxHeight, 2160);
    expect(info.sizeEstimate, 980000000);

    final top = MediaInfo.fromJson({
      'title': 'Clip',
      'filesize_approx': 42000000,
      'formats': [
        {'height': 2160, 'filesize_approx': 980000000},
      ],
    });
    expect(top.sizeEstimate, 42000000);
  });

  test('friendlyError points login walls at the cookie setting', () {
    expect(
      MediaTools.friendlyError(
        'Instagram sent an empty media response. use '
        '--cookies-from-browser',
      ),
      contains('Browser cookies'),
    );
    expect(
      MediaTools.friendlyError('Unsupported URL: https://x'),
      'This link is not a supported video or audio page.',
    );
  });

  test('extractLinks pulls links from text and shortcut files', () {
    expect(extractLinks('see https://a.com/x.zip, and http://b.org/y).'), [
      'https://a.com/x.zip',
      'http://b.org/y',
    ]);
    expect(
      extractLinks(
        '<plist><dict><key>URL</key>'
        '<string>https://youtu.be/q</string></dict></plist>',
      ),
      ['https://youtu.be/q'],
    );
    expect(extractLinks('[InternetShortcut]\nURL=https://c.net/z\n'), [
      'https://c.net/z',
    ]);
  });
}
