import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const String _ffmpegRelease =
    'https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1';

const String _aria2Windows =
    'https://github.com/aria2/aria2/releases/download/release-1.37.0/'
    'aria2-1.37.0-win-64bit-build1.zip';

const String _aria2Linux =
    'https://github.com/abcfy2/aria2-static-build/releases/download/1.37.0/';

const Map<String, String> _checksums = {
  'ffmpeg-darwin-arm64.gz':
      '8923876afa8db5585022d7860ec7e589af192f441c56793971276d450ed3bbfa',
  'ffprobe-darwin-arm64.gz':
      'd986a8ec7b030899fe66a8a288ed809a3543338705a3ce178cfb85869c5d80be',
  'darwin-arm64.LICENSE':
      'cb48bf09a11f5fb576cddb0431c8f5ed0a60157a9ec942adffc13907cbe083f2',
  'ffmpeg-darwin-x64.gz':
      '929b375c1182d956c51f7ac25e0b2b0411fb01f6f407aa15c9758efeb4242106',
  'ffprobe-darwin-x64.gz':
      'd4da574d6e2e197bd259b47d69cf262df9e312af24ad960444f6d806d3d4c186',
  'darwin-x64.LICENSE':
      '2e1d16c72fd74e12063776371da757322f8b77589386532f4fd8634bde7de1af',
  'ffmpeg-linux-x64.gz':
      'bfe8a8fc511530457b528c48d77b5737527b504a3797a9bc4866aeca69c2dffa',
  'ffprobe-linux-x64.gz':
      '25d9b6ccb05e3d9de9e04e31e2506d8dd7f9f0418981965ac6df12e8d3afd067',
  'linux-x64.LICENSE':
      '8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903',
  'ffmpeg-linux-arm64.gz':
      '754a678672298bc68156adff58aa7385a592c2b30b1d0ae8750c45c915c4bac0',
  'ffprobe-linux-arm64.gz':
      '2ab6aba60ee84412dff9188720703376cb4e7aaf7e0b5e43aa8249f2acae5bf8',
  'linux-arm64.LICENSE':
      '8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903',
  'ffmpeg-win32-x64.gz':
      '8883a3dffbd0a16cf4ef95206ea05283f78908dbfb118f73c83f4951dcc06d77',
  'ffprobe-win32-x64.gz':
      'f309e6223ad89d2fe54bccd420a7709b66fd27540674e92309578ed491a43c8d',
  'win32-x64.LICENSE':
      '8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903',
  'aria2-1.37.0-win-64bit-build1.zip':
      '67d015301eef0b612191212d564c5bb0a14b5b9c4796b76454276a4d28d9b288',
  'aria2-x86_64-linux-musl_static.zip':
      'e0a09b12ef67f35f8a8e4fdddbec851d235b7c31da549d0578bff459032b499a',
  'aria2-aarch64-linux-musl_static.zip':
      '0c681a89a40e0f82d1f5137608e86257eb0af201459c002941ea098f2b8c26b6',
};

class _Job {
  const _Job(this.source, this.sourceName, this.output, [this.zipEntry]);

  final String source;
  final String sourceName;
  final String output;
  final String? zipEntry;
}

Future<void> main(List<String> arguments) async {
  final platform = _option(arguments, 'platform') ?? Platform.operatingSystem;
  final arch = _option(arguments, 'arch') ?? _hostArchitecture;
  final out = _option(arguments, 'out') ?? 'assets/tools';
  final force = arguments.contains('--force');

  if (!const {'macos', 'linux', 'windows'}.contains(platform)) {
    stderr.writeln('Unsupported platform: $platform');
    exitCode = 64;
    return;
  }

  final target = _targetName(platform, arch);
  if (target == null) {
    stderr.writeln('Unsupported architecture for $platform: $arch');
    exitCode = 64;
    return;
  }

  final jobs = _jobs(platform, target);
  final output = Directory(out);
  await output.create(recursive: true);
  final separator = Platform.pathSeparator;

  for (final job in jobs) {
    final file = File('${output.path}$separator${job.output}');
    if (file.existsSync() && !force) {
      stdout.writeln('kept    ${job.output}');
      continue;
    }
    final bytes = await _fetch(job.source);
    final digest = sha256.convert(bytes).toString();
    final expected = _checksums[job.sourceName];
    if (expected == null || digest != expected) {
      stderr.writeln('checksum mismatch for ${job.sourceName}');
      stderr.writeln('  expected ${expected ?? '<unpinned>'}');
      stderr.writeln('  actual   $digest');
      exitCode = 1;
      return;
    }
    final payload = switch (job.zipEntry) {
      final String entry => gzip.encode(_zipEntry(bytes, entry)),
      _ => bytes,
    };
    await file.writeAsBytes(payload, flush: true);
    stdout.writeln('wrote   ${job.output} (${payload.length} bytes)');
  }

  stdout.writeln('Bundled tools for $target are in $out');
}

String? _option(List<String> arguments, String name) {
  final flag = '--$name';
  final index = arguments.indexOf(flag);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}

String get _hostArchitecture {
  final host = RegExp(r'"([^"]+)"').firstMatch(Platform.version)?.group(1);
  if (host == null || !host.contains('_')) return 'x64';
  return host.split('_').last;
}

String? _targetName(String platform, String arch) {
  switch (platform) {
    case 'macos':
      return switch (arch) {
        'arm64' => 'darwin-arm64',
        'x64' => 'darwin-x64',
        _ => null,
      };
    case 'linux':
      return switch (arch) {
        'arm64' => 'linux-arm64',
        'x64' => 'linux-x64',
        _ => null,
      };
    default:
      return 'win32-x64';
  }
}

List<_Job> _jobs(String platform, String target) => [
  _Job('$_ffmpegRelease/ffmpeg-$target.gz', 'ffmpeg-$target.gz', 'ffmpeg.gz'),
  _Job(
    '$_ffmpegRelease/ffprobe-$target.gz',
    'ffprobe-$target.gz',
    'ffprobe.gz',
  ),
  _Job('$_ffmpegRelease/$target.LICENSE', '$target.LICENSE', 'ffmpeg.LICENSE'),
  if (platform == 'windows')
    _Job(
      _aria2Windows,
      'aria2-1.37.0-win-64bit-build1.zip',
      'aria2c.gz',
      'aria2-1.37.0-win-64bit-build1/aria2c.exe',
    )
  else if (platform == 'linux')
    _Job(
      '$_aria2Linux'
          'aria2-${target == 'linux-arm64' ? 'aarch64' : 'x86_64'}'
          '-linux-musl_static.zip',
      'aria2-${target == 'linux-arm64' ? 'aarch64' : 'x86_64'}'
          '-linux-musl_static.zip',
      'aria2c.gz',
      'aria2c',
    ),
];

Future<Uint8List> _fetch(String url) async {
  final client = HttpClient()..userAgent = 'ZON/1.0';
  try {
    stdout.writeln('fetch   $url');
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} for $url');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  } finally {
    client.close(force: true);
  }
}

List<int> _zipEntry(Uint8List zip, String name) {
  final view = ByteData.view(zip.buffer, zip.offsetInBytes, zip.lengthInBytes);
  final eocd = _findEocd(zip);
  final entries = view.getUint16(eocd + 10, Endian.little);
  var offset = view.getUint32(eocd + 16, Endian.little);
  for (var i = 0; i < entries; i++) {
    if (view.getUint32(offset, Endian.little) != 0x02014b50) {
      throw const FormatException('corrupt zip central directory');
    }
    final method = view.getUint16(offset + 10, Endian.little);
    final compressed = view.getUint32(offset + 20, Endian.little);
    final nameLength = view.getUint16(offset + 28, Endian.little);
    final extraLength = view.getUint16(offset + 30, Endian.little);
    final commentLength = view.getUint16(offset + 32, Endian.little);
    final local = view.getUint32(offset + 42, Endian.little);
    final entryName = String.fromCharCodes(
      zip.sublist(offset + 46, offset + 46 + nameLength),
    );
    if (entryName == name) {
      if (view.getUint32(local, Endian.little) != 0x04034b50) {
        throw const FormatException('corrupt zip local header');
      }
      final localNameLength = view.getUint16(local + 26, Endian.little);
      final localExtraLength = view.getUint16(local + 28, Endian.little);
      final start = local + 30 + localNameLength + localExtraLength;
      final data = zip.sublist(start, start + compressed);
      return switch (method) {
        0 => data,
        8 => ZLibDecoder(raw: true).convert(data),
        _ => throw FormatException('unsupported zip method $method'),
      };
    }
    offset += 46 + nameLength + extraLength + commentLength;
  }
  throw FormatException('missing zip entry: $name');
}

int _findEocd(Uint8List zip) {
  const signature = [0x50, 0x4b, 0x05, 0x06];
  final limit = zip.length - 22;
  for (var i = limit; i >= 0; i--) {
    var match = true;
    for (var j = 0; j < signature.length; j++) {
      if (zip[i + j] != signature[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  throw const FormatException('not a zip archive');
}
