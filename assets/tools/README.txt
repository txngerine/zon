Bundled tool archives
=====================

This directory holds the third-party binaries that ZON ships inside its own
installer, so requirements can be set up without a package manager:

  ffmpeg.gz      static ffmpeg for the build target   (eugeneware/ffmpeg-static b6.1.1)
  ffprobe.gz     static ffprobe for the build target  (eugeneware/ffmpeg-static b6.1.1)
  aria2c.gz      static aria2c                        (aria2 1.37.0; Windows: aria2/aria2,
                                                       Linux: abcfy2/aria2-static-build)
  ffmpeg.LICENSE license text shipped by ffmpeg-static

macOS builds ship no aria2c.gz: ZON asks for `brew install aria2` there.

Files are downloaded and checksum-verified by:

  dart run tool/bundle_tools.dart

Run it before `flutter build macos|linux|windows` (add --force to refresh).
They are gitignored; a bare checkout simply falls back to PATH lookups and
the in-app downloaders for yt-dlp and aria2.
