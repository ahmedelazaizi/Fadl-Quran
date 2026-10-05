/// Arabic-friendly formatting helpers.
const _eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// 123 → ١٢٣
String arNum(Object value) => value.toString().replaceAllMapped(
  RegExp(r'\d'),
  (m) => _eastern[int.parse(m[0]!)],
);

/// "14:05" → "02:05 م"
String hm12(String hm) {
  final parts = hm.split(':');
  var h = int.parse(parts[0]);
  final suffix = h < 12 ? 'ص' : 'م';
  h = h % 12 == 0 ? 12 : h % 12;
  return '${h.toString().padLeft(2, '0')}:${parts[1]} $suffix';
}

/// Seconds → "02:15:20"
String countdown(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
}

/// Duration → "03:41" or "1:02:15" for audio positions.
String mmss(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Today's date (device local) as YYYY-MM-DD.
String todayKey([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
