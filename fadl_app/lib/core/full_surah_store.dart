import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'full_surah_reciters.dart';

class FullSurahDownloadCancelled implements Exception {
  const FullSurahDownloadCancelled();
}

/// Whole-surah recordings kept on the device for offline listening at
/// `{applicationSupport}/full_surah/{reciterId}_{editionId}/{NNN}.mp3`, next to
/// a `meta.json` describing the edition so the list works without the
/// online catalog. Files arrive through [download] or are written by the
/// player while the user listens ([cacheFile]).
class FullSurahStore extends ChangeNotifier {
  FullSurahStore({http.Client? client, Future<Directory> Function()? root})
    : _client = client ?? http.Client(),
      _rootProvider = root ?? getApplicationSupportDirectory;

  static final FullSurahStore instance = FullSurahStore();

  /// Whether the player saves surahs it streams (on unless turned off).
  static const saveWhileListeningKey = 'fadl.fullSurah.saveWhileListening';

  /// Upper bound per file; the longest surahs are about 150 MB.
  static const maxFileBytes = 400 * 1024 * 1024;

  final http.Client _client;
  final Future<Directory> Function() _rootProvider;
  Future<void>? _ready;
  Directory? _dir;
  final Map<String, FullSurahEdition> _editions = {};
  final Map<String, Set<int>> _files = {};
  final Map<String, ({int received, int? total})> _progress = {};
  final Map<String, StreamSubscription<List<int>>> _running = {};
  final Map<String, Completer<void>> _completers = {};

  static String _taskKey(FullSurahEdition edition, int surah) =>
      '${edition.key}/$surah';
  static String _fileName(int surah) =>
      '${surah.toString().padLeft(3, '0')}.mp3';

  Future<void> ready() => _ready ??= _scan().catchError((Object error) {
    _ready = null;
    throw error;
  });

  Future<void> _scan() async {
    final dir = Directory('${(await _rootProvider()).path}/full_surah');
    _dir = dir;
    _editions.clear();
    _files.clear();
    if (!await dir.exists()) return;
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final meta = File('${entry.path}/meta.json');
      if (!await meta.exists()) continue;
      FullSurahEdition? edition;
      try {
        edition = FullSurahEdition.fromJson(
          jsonDecode(await meta.readAsString()),
        );
      } on FormatException {
        continue;
      }
      if (edition == null ||
          entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty) !=
              edition.key) {
        continue;
      }
      final surahs = <int>{};
      await for (final file in entry.list()) {
        final name = file.uri.pathSegments.last;
        final match = RegExp(r'^(\d{3})\.mp3$').firstMatch(name);
        final surah = match == null ? null : int.parse(match.group(1)!);
        if (file is File && surah != null && edition.surahs.contains(surah)) {
          surahs.add(surah);
        }
      }
      if (surahs.isEmpty) continue;
      _editions[edition.key] = edition;
      _files[edition.key] = surahs;
    }
    notifyListeners();
  }

  /// Rescans the folder, e.g. after the player finished caching a surah.
  Future<void> refresh() {
    _ready = null;
    return ready();
  }

  Directory _editionDir(FullSurahEdition edition) =>
      Directory('${_dir!.path}/${edition.key}');

  Future<void> _writeMeta(FullSurahEdition edition) async {
    final dir = _editionDir(edition);
    await dir.create(recursive: true);
    await File(
      '${dir.path}/meta.json',
    ).writeAsString(jsonEncode(edition.toJson()));
  }

  bool isDownloaded(FullSurahEdition edition, int surah) =>
      _files[edition.key]?.contains(surah) ?? false;

  bool isDownloading(FullSurahEdition edition, int surah) =>
      _running.containsKey(_taskKey(edition, surah));

  /// Fraction received, or null while the size is unknown.
  double? progress(FullSurahEdition edition, int surah) {
    final task = _progress[_taskKey(edition, surah)];
    final total = task?.total;
    return task == null || total == null || total == 0
        ? null
        : task.received / total;
  }

  /// Editions with at least one saved surah, sorted by reciter name.
  List<FullSurahEdition> get downloadedEditions =>
      _editions.values.toList()..sort((a, b) => a.nameAr.compareTo(b.nameAr));

  List<int> downloadedSurahs(FullSurahEdition edition) =>
      (_files[edition.key]?.toList() ?? <int>[])..sort();

  /// The saved recording, or null when it is not on the device.
  File? localFile(FullSurahEdition edition, int surah) =>
      isDownloaded(edition, surah)
      ? File('${_editionDir(edition).path}/${_fileName(surah)}')
      : null;

  /// Where the player may cache [surah] while streaming it. The player writes
  /// `NNN.mp3.part` and renames it once the whole file has arrived.
  Future<File> cacheFile(FullSurahEdition edition, int surah) async {
    await ready();
    await _writeMeta(edition);
    return File('${_editionDir(edition).path}/${_fileName(surah)}');
  }

  Future<void> download(FullSurahEdition edition, int surah) async {
    await ready();
    final url = edition.urlForSurah(surah);
    if (url == null || !isMp3QuranServer(edition.server)) {
      throw StateError('Surah $surah is not in this edition');
    }
    final key = _taskKey(edition, surah);
    if (_running.containsKey(key) || isDownloaded(edition, surah)) return;
    await _writeMeta(edition);
    final target = File('${_editionDir(edition).path}/${_fileName(surah)}');
    // A different suffix from the player's `.part` cache, so both may run.
    final part = File('${target.path}.download');
    final completer = _completers[key] = Completer<void>();
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final total = response.contentLength;
      if (response.statusCode != 200 ||
          (total != null && total > maxFileBytes)) {
        throw const HttpException('Invalid recording response');
      }
      sink = part.openWrite();
      var received = 0;
      _progress[key] = (received: 0, total: total);
      notifyListeners();
      _running[key] = response.stream.listen(
        (chunk) {
          received += chunk.length;
          if (received > maxFileBytes) {
            _running[key]?.cancel();
            completer.completeError(const HttpException('Recording too large'));
            return;
          }
          sink!.add(chunk);
          _progress[key] = (received: received, total: total);
          notifyListeners();
        },
        onError: (Object error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
        onDone: () {
          if (completer.isCompleted) return;
          if (received == 0 || (total != null && received != total)) {
            completer.completeError(const HttpException('Truncated'));
          } else {
            completer.complete();
          }
        },
        cancelOnError: true,
      );
      await completer.future;
      await sink.flush();
      await sink.close();
      sink = null;
      await part.rename(target.path);
      _editions[edition.key] = edition;
      (_files[edition.key] ??= {}).add(surah);
    } finally {
      _running.remove(key);
      _completers.remove(key);
      _progress.remove(key);
      await sink?.close();
      if (await part.exists()) await part.delete();
      notifyListeners();
    }
  }

  /// Stops a running download; its future then fails with
  /// [FullSurahDownloadCancelled] and the partial file is removed.
  Future<void> cancel(FullSurahEdition edition, int surah) async {
    final key = _taskKey(edition, surah);
    await _running[key]?.cancel();
    // A cancelled subscription never calls onDone, so fail it here.
    final completer = _completers[key];
    if (completer != null && !completer.isCompleted) {
      completer.completeError(const FullSurahDownloadCancelled());
    }
  }

  Future<void> deleteSurah(FullSurahEdition edition, int surah) async {
    await ready();
    final dir = _editionDir(edition);
    for (final suffix in ['', '.part', '.mime', '.download']) {
      final file = File('${dir.path}/${_fileName(surah)}$suffix');
      if (await file.exists()) await file.delete();
    }
    _files[edition.key]?.remove(surah);
    if (_files[edition.key]?.isEmpty ?? false) {
      await deleteEdition(edition);
      return;
    }
    notifyListeners();
  }

  Future<void> deleteEdition(FullSurahEdition edition) async {
    await ready();
    final dir = _editionDir(edition);
    if (await dir.exists()) await dir.delete(recursive: true);
    _files.remove(edition.key);
    _editions.remove(edition.key);
    notifyListeners();
  }

  Future<void> deleteAll() async {
    await ready();
    for (final edition in downloadedEditions) {
      await deleteEdition(edition);
    }
  }

  Future<int> editionSize(FullSurahEdition edition) async {
    await ready();
    var total = 0;
    for (final surah in downloadedSurahs(edition)) {
      total += await localFile(edition, surah)!.length();
    }
    return total;
  }

  Future<int> totalSize() async {
    await ready();
    final dir = _dir!;
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entry in dir.list(recursive: true)) {
      if (entry is File && entry.path.endsWith('.mp3')) {
        total += await entry.length();
      }
    }
    return total;
  }

  static Future<bool> saveWhileListening() async =>
      (await SharedPreferences.getInstance()).getBool(saveWhileListeningKey) ??
      true;

  static Future<void> setSaveWhileListening(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(
        saveWhileListeningKey,
        value,
      );
}
