/// Recognises links that should go through yt-dlp instead of plain HTTP.
library;

class MediaSite {
  const MediaSite(this.name, this.hosts, {this.path});

  final String name;
  final List<String> hosts;

  /// When set, only matching paths count as media on [hosts].
  final String? path;

  bool matches(Uri uri) {
    final host = uri.host.toLowerCase();
    final hostMatch = hosts.any(
      (candidate) => host == candidate || host.endsWith('.$candidate'),
    );
    if (!hostMatch) return false;
    final pattern = path;
    if (pattern == null) return true;
    return RegExp(pattern).hasMatch(uri.path.toLowerCase());
  }
}

const mediaSites = <MediaSite>[
  MediaSite('YouTube Music', ['music.youtube.com']),
  MediaSite('YouTube', ['youtube.com', 'youtu.be', 'youtube-nocookie.com']),
  MediaSite('Instagram', [
    'instagram.com',
  ], path: r'^/(reels?|p|tv|stories)/|^/[^/]+/(reels?|p)/'),
  MediaSite('TikTok', ['tiktok.com']),
  MediaSite('X', ['x.com', 'twitter.com'], path: r'/status(es)?/\d+'),
  MediaSite('Facebook', ['facebook.com', 'fb.watch', 'fb.com']),
  MediaSite('Vimeo', ['vimeo.com']),
  MediaSite('SoundCloud', ['soundcloud.com']),
  MediaSite('Reddit', ['v.redd.it']),
  MediaSite('Reddit', ['reddit.com'], path: r'/comments/'),
  MediaSite('Twitch', ['twitch.tv']),
  MediaSite('Dailymotion', ['dailymotion.com', 'dai.ly']),
  MediaSite('Bilibili', ['bilibili.com', 'b23.tv']),
  MediaSite('Pinterest', ['pinterest.com', 'pin.it'], path: r'^/pin/|^/\w+$'),
  MediaSite('Bandcamp', ['bandcamp.com'], path: r'^/(track|album)/'),
  MediaSite('Threads', ['threads.net', 'threads.com'], path: r'/post/'),
  MediaSite('Snapchat', ['snapchat.com'], path: r'^/(spotlight|t)/'),
  MediaSite('Rumble', ['rumble.com']),
  MediaSite('Kick', ['kick.com']),
  MediaSite('Streamable', ['streamable.com']),
];

/// The site [url] belongs to, or null when it is a plain file link.
///
/// HLS/DASH manifests are treated as media too: yt-dlp stitches their
/// fragments into a single file.
MediaSite? detectMediaSite(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  final path = uri.path.toLowerCase();
  if (path.endsWith('.m3u8') || path.endsWith('.mpd')) {
    return const MediaSite('Stream', []);
  }
  for (final site in mediaSites) {
    if (site.matches(uri)) return site;
  }
  return null;
}

bool isMediaUrl(String url) => detectMediaSite(url) != null;

/// True for links that name a whole collection (playlist, channel) rather
/// than one video. These are expanded into one download per entry.
bool looksLikePlaylist(String url) {
  final site = detectMediaSite(url);
  final uri = Uri.tryParse(url.trim());
  if (site == null || uri == null) return false;
  final query = uri.queryParameters;
  final path = uri.path.toLowerCase();
  if (site.name.startsWith('YouTube')) {
    if (path.startsWith('/playlist')) return true;
    if (query.containsKey('list') && !query.containsKey('v')) return true;
    return path.startsWith('/@') ||
        path.startsWith('/channel/') ||
        path.startsWith('/c/') ||
        path.startsWith('/user/');
  }
  if (site.name == 'SoundCloud') return path.contains('/sets/');
  if (site.name == 'Bandcamp') return path.startsWith('/album/');
  return false;
}
