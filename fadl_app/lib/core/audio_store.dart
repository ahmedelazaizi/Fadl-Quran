import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'format.dart';
import 'quran_data.dart';
import 'reciters.dart';

enum DownloadStatus { none, partial, complete }

/// Live progress of one surah download; [done] includes files already on disk.
class SurahDownload {
  SurahDownload(this.reciterId, this.surahId, this.total);
  final String reciterId;
  final int surahId;
  final int total;
  int done = 0;
  bool cancelled = false;

  double get fraction => total == 0 ? 0 : done / total;
}

class AudioDownloadException implements Exception {
  AudioDownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Verse-by-verse recitations saved for offline listening at
/// `{applicationSupport}/audio/{reciterId}/{globalAyah}.mp3`.
class AudioStore extends ChangeNotifier {
  AudioStore({
    http.Client? client,
    Future<Directory> Function()? root,
    this.concurrency = 3,
  }) : _client = client ?? http.Client(),
       _rootProvider = root ?? getApplicationSupportDirectory;

  static final AudioStore instance = AudioStore();

  final http.Client _client;
  final Future<Directory> Function() _rootProvider;
  final int concurrency;

  Future<void>? _ready;
  Directory? _audioDir;
  List<List<int>> _surahIds = const [];
  final Map<String, Set<int>> _files = {};
  final Map<String, SurahDownload> _tasks = {};
  final Map<String, Future<void>> _running = {};

  static String _taskKey(String reciterId, int surahId) =>
      '$reciterId/$surahId';

  /// Loads the mushaf index and scans the files already downloaded.
  Future<void> ready() => _ready ??= _load().catchError((Object error) {
    _ready = null;
    throw error;
  });

  Future<void> _load() async {
    final quran = await QuranData.load();
    _surahIds = [
      for (var id = 1; id <= 114; id++)
        [for (final ayah in quran.surahAyahs(id)) ayah['id'] as int],
    ];
    final dir = Directory('${(await _rootProvider()).path}/audio');
    _audioDir = dir;
    _files.clear();
    if (await dir.exists()) {
      await for (final entry in dir.list()) {
        if (entry is! Directory) continue;
        final reciterId = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        final ids = <int>{};
        await for (final file in entry.list()) {
          if (file is! File) continue;
          final name = file.uri.pathSegments.last;
          final match = RegExp(r'^(\d+)\.mp3$').firstMatch(name);
          if (match != null) ids.add(int.parse(match[1]!));
        }
        if (ids.isNotEmpty) _files[reciterId] = ids;
      }
    }
    notifyListeners();
  }

  File _file(String reciterId, int globalAyah) =>
      File('${_audioDir!.path}/$reciterId/$globalAyah.mp3');

  /// The downloaded file for an ayah, or null when it must be streamed.
  Future<File?> localFile(String reciterId, int globalAyah) async {
    await ready();
    final file = _file(reciterId, globalAyah);
    return await file.exists() ? file : null;
  }

  List<int> _ids(int surahId) => surahId >= 1 && surahId <= _surahIds.length
      ? _surahIds[surahId - 1]
      : const [];

  /// Requires [ready]; reports [DownloadStatus.none] until then.
  DownloadStatus status(String reciterId, int surahId) {
    final ids = _ids(surahId);
    final have = _files[reciterId];
    if (ids.isEmpty || have == null) return DownloadStatus.none;
    final count = ids.where(have.contains).length;
    if (count == 0) return DownloadStatus.none;
    return count == ids.length
        ? DownloadStatus.complete
        : DownloadStatus.partial;
  }

  SurahDownload? progress(String reciterId, int surahId) =>
      _tasks[_taskKey(reciterId, surahId)];

  bool get hasActiveDownloads => _tasks.isNotEmpty;

  /// Reciters with at least one downloaded ayah.
  List<String> get downloadedReciters => [
    for (final e in _files.entries)
      if (e.value.isNotEmpty) e.key,
  ];

  int completeSurahCount(String reciterId) => [
    for (var id = 1; id <= _surahIds.length; id++)
      if (status(reciterId, id) == DownloadStatus.complete) id,
  ].length;

  /// Downloads every missing ayah of a surah; existing files are skipped so a
  /// repeated call resumes an interrupted download.
  Future<void> downloadSurah(String reciterId, int surahId) {
    final key = _taskKey(reciterId, surahId);
    return _running[key] ??= _download(reciterId, surahId).whenComplete(() {
      _running.remove(key);
    });
  }

  Future<void> _download(String reciterId, int surahId) async {
    await ready();
    if (reciterById(reciterId) == null) {
      throw AudioDownloadException('القارئ غير متوفر');
    }
    final ids = _ids(surahId);
    if (ids.isEmpty) throw AudioDownloadException('السورة غير موجودة');
    final key = _taskKey(reciterId, surahId);
    final task = SurahDownload(reciterId, surahId, ids.length);
    _tasks[key] = task;
    final have = _files.putIfAbsent(reciterId, () => <int>{});
    final queue = <int>[];
    for (final id in ids) {
      if (await _file(reciterId, id).exists()) {
        have.add(id);
        task.done++;
      } else {
        have.remove(id);
        queue.add(id);
      }
    }
    notifyListeners();
    Object? failure;
    Future<void> worker() async {
      while (queue.isNotEmpty && failure == null && !task.cancelled) {
        final id = queue.removeAt(0);
        try {
          if (!await _fetch(reciterId, id, task)) return;
        } catch (error) {
          failure ??= error;
          return;
        }
        have.add(id);
        task.done++;
        notifyListeners();
      }
    }

    try {
      await Future.wait([
        for (var i = 0; i < math.min(concurrency, queue.length); i++) worker(),
      ]);
    } finally {
      _tasks.remove(key);
      notifyListeners();
    }
    if (failure != null && !task.cancelled) {
      throw AudioDownloadException(
        'تعذّر تنزيل السورة. تحقق من الاتصال بالإنترنت ثم أعد المحاولة لإكمال التنزيل.',
      );
    }
  }

  /// Writes to `.part` first so a partial file is never taken as complete.
  /// Returns false when the download was cancelled meanwhile.
  Future<bool> _fetch(
    String reciterId,
    int globalAyah,
    SurahDownload task,
  ) async {
    final response = await _client
        .get(Uri.parse(ayahAudioUrl(reciterId, globalAyah)))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    if (task.cancelled) return false;
    final target = _file(reciterId, globalAyah);
    await target.parent.create(recursive: true);
    final part = File('${target.path}.part');
    await part.writeAsBytes(response.bodyBytes, flush: true);
    if (task.cancelled) {
      await part.delete();
      return false;
    }
    await part.rename(target.path);
    return true;
  }

  /// Stops a running download; finished ayahs are kept for resuming.
  Future<void> cancel(String reciterId, int surahId) async {
    final key = _taskKey(reciterId, surahId);
    _tasks[key]?.cancelled = true;
    await _running[key];
  }

  Future<void> _cancelWhere(bool Function(SurahDownload task) test) async {
    final tasks = _tasks.values.where(test).toList();
    for (final task in tasks) {
      task.cancelled = true;
    }
    await Future.wait([
      for (final task in tasks)
        ?_running[_taskKey(task.reciterId, task.surahId)],
    ]);
  }

  Future<void> deleteSurah(String reciterId, int surahId) async {
    await ready();
    await cancel(reciterId, surahId);
    for (final id in _ids(surahId)) {
      final file = _file(reciterId, id);
      for (final path in [file.path, '${file.path}.part']) {
        final entry = File(path);
        if (await entry.exists()) await entry.delete();
      }
      _files[reciterId]?.remove(id);
    }
    if (_files[reciterId]?.isEmpty ?? false) _files.remove(reciterId);
    notifyListeners();
  }

  Future<void> deleteReciter(String reciterId) async {
    await ready();
    await _cancelWhere((task) => task.reciterId == reciterId);
    final dir = Directory('${_audioDir!.path}/$reciterId');
    if (await dir.exists()) await dir.delete(recursive: true);
    _files.remove(reciterId);
    notifyListeners();
  }

  Future<void> deleteAll() async {
    await ready();
    await _cancelWhere((_) => true);
    final dir = _audioDir!;
    if (await dir.exists()) await dir.delete(recursive: true);
    _files.clear();
    notifyListeners();
  }

  /// Bytes on disk for one reciter.
  Future<int> reciterSize(String reciterId) async {
    await ready();
    return _sizeOf(Directory('${_audioDir!.path}/$reciterId'));
  }

  /// Bytes on disk for every reciter.
  Future<int> totalSize() async {
    await ready();
    return _sizeOf(_audioDir!);
  }

  static Future<int> _sizeOf(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entry in dir.list(recursive: true)) {
      if (entry is File) total += await entry.length();
    }
    return total;
  }
}

/// 1536 → "١٫٥ ك.ب"
String formatBytes(int bytes) {
  const units = ['بايت', 'ك.ب', 'م.ب', 'ج.ب'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit == 0 || value >= 100
      ? value.round().toString()
      : value.toStringAsFixed(1).replaceAll('.', '٫');
  return '${arNum(text)} ${units[unit]}';
}
