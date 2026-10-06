# ZON — The Download Manager

[![CI](https://github.com/txngerine/zon/actions/workflows/ci.yml/badge.svg)](https://github.com/txngerine/zon/actions/workflows/ci.yml)

A cross-platform (macOS, Windows, Linux) download manager built with Flutter.

## Features

- **Segmented HTTP engine** — splits files into up to 32 parallel byte ranges,
  resumes after pause, quit or crash, retries with backoff, and backs off
  automatically when a server answers `429 Too Many Requests`.
- **Video & audio** — YouTube (videos, Shorts, playlists, channels), Instagram
  Reels, TikTok, X, Facebook, Vimeo, SoundCloud, Twitch, Reddit and 1000+ more
  sites via [yt-dlp](https://github.com/yt-dlp/yt-dlp). Pick Best / 4K /
  1080p / 720p / 480p MP4, MP3 (128–320 kbps) or M4A. Playlists become one
  download per video.
- **BitTorrent** — magnet links and `.torrent` files (URL, file picker,
  drag & drop, Finder "Open With") through a private aria2 daemon: live
  peers/seeds, pause/resume with piece verification, optional seeding to a
  ratio. Stalled torrents stop occupying download slots. ZON can be made the
  system handler for magnet links.
- **Persistent library** — downloads, history and settings live in
  `library.json` in the app-support folder; interrupted transfers re-queue on
  launch.
- **Desktop integration** — tray icon with pause/resume, native notifications,
  launch at login, a "copied link" banner, drag & drop of links and
  `.txt`/`.webloc`/`.url` files, and a browser bookmarklet.
- Speed limits (global and per download), priorities, queue reordering.

## Requirements

| Tool | Needed for | How ZON gets it |
| --- | --- | --- |
| yt-dlp | any video/audio site | **Settings › Media › Install** (one click), or `brew install yt-dlp` |
| ffmpeg + ffprobe | MP3, and video above 720p (merging streams) | **Bundled** — unpacked into the app-support `bin/` folder on first launch |
| aria2 | torrents and magnet links | **Bundled** on Windows and Linux; `brew install aria2` on macOS, or **Settings › Torrents › Install** |

Bundled tools are unpacked locally on first launch, so no download or package
manager is involved. ZON still prefers anything already on `PATH` and in the
usual Homebrew/WinGet/Scoop locations. Without ffmpeg, video falls back to
pre-merged streams and MP3 is disabled.

Linux builds need `libgtk-3-dev libx11-dev libxi-dev` (tray icon).

## Browser button

**Settings › Integrations › Bookmarklet › Set up** copies a bookmarklet. Clicking it
on any page sends that page to ZON through a server bound to `127.0.0.1:6412`
only. A second bookmarklet sends straight to MP3. Each install has its own
secret key inside the bookmarklet, so other websites cannot add downloads.

## Instagram, private and age-restricted videos

These need a logged-in session. Choose your browser under
**Settings › Media › Browser cookies** and yt-dlp reads its cookies.

## Development

```sh
flutter pub get
dart run tool/bundle_tools.dart   # fetch + checksum the bundled tool archives
flutter test          # unit, engine (real local HTTP server) and widget tests
flutter run -d macos
```

`.github/workflows/ci.yml` runs the formatter, analyzer and tests on Linux,
macOS and Windows, then packages a release build per platform (pushes to
`main`, tags and manual runs).

`tool/bundle_tools.dart` downloads pinned, sha256-verified archives for the
target platform (`--platform macos|linux|windows`, `--arch`, `--force`) into
`assets/tools/`, which is gitignored. A checkout without them builds fine:
ffmpeg/aria2 then come from `PATH` or the package manager instead.

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

## Third-party tools

ZON runs these as separate programs rather than linking them:

- **yt-dlp** — Unlicense, downloaded on demand.
- **ffmpeg / ffprobe** — GPLv3 static builds from
  [eugeneware/ffmpeg-static](https://github.com/eugeneware/ffmpeg-static)
  (release `b6.1.1`); the license text ships as `assets/tools/ffmpeg.LICENSE`
  and is copied next to the binaries on first launch.
- **aria2 1.37.0** — GPLv2+; Windows build from
  [aria2/aria2](https://github.com/aria2/aria2), Linux static build from
  [abcfy2/aria2-static-build](https://github.com/abcfy2/aria2-static-build).

## Legal

Only download content you have the right to download. Many sites' terms of
service restrict downloading, and copyright law still applies.
