/// What a media download (YouTube, Reels, TikTok, ...) should produce.
///
/// Media downloads run through yt-dlp; each value maps to a yt-dlp format
/// selection (see `MediaEngine`).
enum MediaFormat {
  videoBest('Best video', 'MP4'),
  video2160('4K', 'MP4'),
  video1080('1080p', 'MP4'),
  video720('720p', 'MP4'),
  video480('480p', 'MP4'),
  audioMp3('MP3', 'Audio'),
  audioM4a('M4A', 'Audio');

  const MediaFormat(this.label, this.caption);

  final String label;
  final String caption;

  bool get isAudio => this == audioMp3 || this == audioM4a;

  /// Maximum video height, or null for "no cap".
  int? get maxHeight => switch (this) {
    MediaFormat.video2160 => 2160,
    MediaFormat.video1080 => 1080,
    MediaFormat.video720 => 720,
    MediaFormat.video480 => 480,
    _ => null,
  };

  String get extension => switch (this) {
    MediaFormat.audioMp3 => 'mp3',
    MediaFormat.audioM4a => 'm4a',
    _ => 'mp4',
  };

  /// Formats that cannot be produced without ffmpeg: audio extraction, and
  /// any video above 720p, which only exists as separate streams to merge.
  bool get needsFfmpeg => this == audioMp3 || (maxHeight ?? 0) > 720;

  static MediaFormat fromName(String? name) => MediaFormat.values.firstWhere(
    (value) => value.name == name,
    orElse: () => MediaFormat.videoBest,
  );
}
