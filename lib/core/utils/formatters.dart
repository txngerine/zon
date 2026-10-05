/// Human readable formatting helpers shared across the UI.
library;

/// Formats a byte count using binary units (KB, MB, GB, TB).
String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final precision = size >= 100 || unit == 0 ? 0 : decimals;
  return '${size.toStringAsFixed(precision)} ${units[unit]}';
}

/// Formats a transfer rate given in bytes per second.
String formatSpeed(double bytesPerSecond, {bool zeroAsIdle = true}) {
  if (zeroAsIdle && bytesPerSecond < 1) return '0 B/s';
  return '${formatBytes(bytesPerSecond.round(), decimals: 1)}/s';
}

/// Formats a duration in seconds as `38 seconds`, `4 minutes` or `1 h 05 m`.
String formatEta(int seconds) {
  if (seconds <= 0) return '—';
  if (seconds < 60) return '$seconds second${seconds == 1 ? '' : 's'}';
  if (seconds < 3600) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '$m minute${m == 1 ? '' : 's'}' : '$m min $s s';
  }
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return m == 0 ? '$h hour${h == 1 ? '' : 's'}' : '$h h $m m';
}

/// Compact duration used in history tables (`04:12`, `1:04:12`).
String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String formatPercent(double value) => '${(value * 100).toStringAsFixed(0)}%';

/// `Today, 2:34 PM` / `Sep 28, 4:12 PM`.
String formatDateTime(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(time.year, time.month, time.day);
  final clock = _clock(time);
  if (that == today) return 'Today, $clock';
  if (that == today.subtract(const Duration(days: 1))) {
    return 'Yesterday, $clock';
  }
  return '${_month(time.month)} ${time.day}, $clock';
}

/// `2:34 PM`.
String _clock(DateTime time) {
  var hour = time.hour % 12;
  if (hour == 0) hour = 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _month(int month) => _months[month - 1];

/// Trims a URL down to its host plus a short path for compact display.
String shortUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final path = uri.path.length > 28
      ? '${uri.path.substring(0, 28)}…'
      : uri.path;
  return '${uri.host}$path';
}

/// Infers a file name from a URL path, falling back to [fallback].
String fileNameFromUrl(String url, {String fallback = 'download.bin'}) {
  final uri = Uri.tryParse(url.trim());
  final segment = uri?.pathSegments.isNotEmpty == true
      ? uri!.pathSegments.last
      : '';
  if (segment.isEmpty || !segment.contains('.')) return fallback;
  return segment;
}
