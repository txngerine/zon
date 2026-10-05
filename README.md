# ZON — The Download Manager

A cross-platform (macOS, Windows, Linux) download manager built with Flutter.

## Features

- **Segmented HTTP engine** — splits files into up to 32 parallel byte ranges,
  resumes after pause, quit or crash, retries with backoff, and backs off
  automatically when a server answers `429 Too Many Requests`.
- **Video & audio** — YouTube (videos, Shorts, playlists, channels), Instagram
  Reels, TikTok, X, Facebook, Vimeo, SoundCloud, Twitch, Reddit and 1000+ more
  sites via [yt-dlp](https://github.com/yt-dlp/yt-dlp). Pick Best / 1080p /
  720p / 480p MP4, MP3 (128–320 kbps) or M4A. Playlists become one download per
  video.
- **Persistent library** — downloads, history and settings live in
  `library.json` in the app-support folder; interrupted transfers re-queue on
  launch.
- **Desktop integration** — tray icon with pause/resume, native notifications,
  launch at login, a "copied link" banner, drag & drop of links and
  `.txt`/`.webloc`/`.url` files, and a browser bookmarklet.
- Speed limits (global and per download), priorities, queue reordering.

## Requirements

| Tool | Needed for | Install |
| --- | --- | --- |
| yt-dlp | any video/audio site | **Settings › Media › Install** (one click), or `brew install yt-dlp` |
| ffmpeg | MP3, and video above 720p (merging streams) | `brew install ffmpeg` · `winget install ffmpeg` · `sudo apt install ffmpeg` |

ZON finds both on `PATH` and in the usual Homebrew/WinGet/Scoop locations.
Without ffmpeg, video falls back to pre-merged streams and MP3 is disabled.

Linux builds need `libgtk-3-dev libx11-dev libxi-dev` (tray icon).

## Browser button

**Settings › Integrations › Bookmarklet › Set up** copies a bookmarklet. Clicking it
on any page sends that page to ZON through a server bound to `127.0.0.1:6412`
only. A second bookmarklet sends straight to MP3.

## Instagram, private and age-restricted videos

These need a logged-in session. Choose your browser under
**Settings › Media › Browser cookies** and yt-dlp reads its cookies.

## Development

```sh
flutter pub get
flutter test          # unit, engine (real local HTTP server) and widget tests
flutter run -d macos
```

```
lib/
  engine/            HTTP engine, yt-dlp media engine, site detection
  data/              AppState (scheduler + actions), LibraryStore (JSON)
  platform/          tray/window, notifications, local API, OS helpers
  domain/models/     DownloadItem, AppSettings, MediaFormat
  presentation/      UI
```

The macOS App Sandbox is disabled because ZON runs yt-dlp/ffmpeg and writes
wherever you choose. Distribute it outside the Mac App Store.

## Legal

Only download content you have the right to download. Many sites' terms of
service restrict downloading, and copyright law still applies.
