import 'dart:convert';
import 'dart:typed_data';

/// One file inside a torrent.
class TorrentFileEntry {
  const TorrentFileEntry({
    required this.index,
    required this.segments,
    required this.length,
    this.padding = false,
  });

  /// 1-based position in the torrent's file list, as aria2's `select-file`
  /// counts them.
  final int index;

  /// Path inside the torrent, split on folders.
  final List<String> segments;
  final int length;

  /// BEP 47 alignment filler: never shown, never downloaded.
  final bool padding;

  String get path => segments.join('/');
  String get name => segments.last;
}

/// What a torrent contains, read before anything is downloaded.
class TorrentManifest {
  const TorrentManifest({required this.name, required this.files});

  final String name;
  final List<TorrentFileEntry> files;

  /// Files the user can choose between (padding files hidden).
  Iterable<TorrentFileEntry> get visibleFiles =>
      files.where((file) => !file.padding);

  int get totalLength => visibleFiles.fold(0, (sum, file) => sum + file.length);

  /// Reads the `info` dictionary of a `.torrent` file.
  factory TorrentManifest.parse(List<int> bytes) {
    final root = _Bdecoder(Uint8List.fromList(bytes)).decode();
    if (root is! Map<String, Object?>) {
      throw const FormatException('Not a .torrent file');
    }
    final info = root['info'];
    if (info is! Map<String, Object?>) {
      throw const FormatException('The .torrent has no file list');
    }
    final name = _text(info['name.utf-8']) ?? _text(info['name']) ?? 'Torrent';

    final list = info['files'];
    if (list is List) {
      final files = <TorrentFileEntry>[];
      for (final raw in list) {
        if (raw is! Map<String, Object?>) continue;
        final parts = raw['path.utf-8'] ?? raw['path'];
        final segments = [
          if (parts is List)
            for (final part in parts) _text(part) ?? '',
        ].where((segment) => segment.isNotEmpty).toList();
        if (segments.isEmpty) segments.add('file ${files.length + 1}');
        final attr = _text(raw['attr']) ?? '';
        files.add(
          TorrentFileEntry(
            index: files.length + 1,
            segments: segments,
            length: _int(raw['length']),
            padding: attr.contains('p') || segments.first.startsWith('.pad'),
          ),
        );
      }
      return TorrentManifest(name: name, files: files);
    }

    if (info.containsKey('length')) {
      return TorrentManifest(
        name: name,
        files: [
          TorrentFileEntry(
            index: 1,
            segments: [name],
            length: _int(info['length']),
          ),
        ],
      );
    }
    throw const FormatException('Unsupported .torrent layout');
  }

  static String? _text(Object? value) => value is Uint8List
      ? utf8.decode(value, allowMalformed: true)
      : value is String
      ? value
      : null;

  static int _int(Object? value) => value is int ? value : 0;
}

/// Hex info hash of a magnet link (`xt=urn:btih:`), accepting the 40-char
/// hex and 32-char base32 forms. Null when the link carries no v1 hash.
String? magnetInfoHash(String magnet) {
  final match = RegExp(r'xt=urn:btih:([0-9a-zA-Z]+)').firstMatch(magnet);
  final raw = match?.group(1);
  if (raw == null) return null;
  if (raw.length == 40) return raw.toLowerCase();
  if (raw.length != 32) return null;
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  var bits = 0;
  var value = 0;
  final out = StringBuffer();
  for (final char in raw.toUpperCase().split('')) {
    final digit = alphabet.indexOf(char);
    if (digit < 0) return null;
    value = (value << 5) | digit;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.write(((value >> bits) & 0xff).toRadixString(16).padLeft(2, '0'));
    }
  }
  return out.toString();
}

/// aria2 `select-file` value: sorted 1-based indexes folded into ranges
/// ("1-40,42,50-60") so a pick of thousands of files stays short.
String selectFileOption(Iterable<int> indexes) {
  final sorted = indexes.toSet().toList()..sort();
  final parts = <String>[];
  for (var i = 0; i < sorted.length; i++) {
    final start = sorted[i];
    while (i + 1 < sorted.length && sorted[i + 1] == sorted[i] + 1) {
      i++;
    }
    parts.add(start == sorted[i] ? '$start' : '$start-${sorted[i]}');
  }
  return parts.join(',');
}

/// Bencode reader. Byte strings stay [Uint8List]; dictionary keys decode
/// as UTF-8.
class _Bdecoder {
  _Bdecoder(this._bytes);

  final Uint8List _bytes;
  int _pos = 0;

  Object? decode() {
    final value = _value(0);
    return value;
  }

  Object? _value(int depth) {
    if (depth > 64) throw const FormatException('Torrent nested too deeply');
    if (_pos >= _bytes.length) {
      throw const FormatException('Truncated .torrent file');
    }
    final byte = _bytes[_pos];
    switch (byte) {
      case 0x69: // i
        _pos++;
        final end = _indexOf(0x65);
        final number = int.parse(ascii.decode(_bytes.sublist(_pos, end)));
        _pos = end + 1;
        return number;
      case 0x6c: // l
        _pos++;
        final list = <Object?>[];
        while (_peek() != 0x65) {
          list.add(_value(depth + 1));
        }
        _pos++;
        return list;
      case 0x64: // d
        _pos++;
        final map = <String, Object?>{};
        while (_peek() != 0x65) {
          final key = utf8.decode(_string(), allowMalformed: true);
          map[key] = _value(depth + 1);
        }
        _pos++;
        return map;
      default:
        return _string();
    }
  }

  Uint8List _string() {
    final colon = _indexOf(0x3a);
    final length = int.parse(ascii.decode(_bytes.sublist(_pos, colon)));
    final start = colon + 1;
    if (length < 0 || start + length > _bytes.length) {
      throw const FormatException('Truncated .torrent file');
    }
    _pos = start + length;
    return Uint8List.sublistView(_bytes, start, start + length);
  }

  int _peek() {
    if (_pos >= _bytes.length) {
      throw const FormatException('Truncated .torrent file');
    }
    return _bytes[_pos];
  }

  int _indexOf(int byte) {
    for (var i = _pos; i < _bytes.length; i++) {
      if (_bytes[i] == byte) return i;
    }
    throw const FormatException('Truncated .torrent file');
  }
}
