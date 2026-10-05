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

  group('MediaEngine.buildArgs', () {
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
