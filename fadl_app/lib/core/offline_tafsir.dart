import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'download_updates.dart';

/// A tafsir edition that can be downloaded for offline reading.
class TafsirEdition {
  const TafsirEdition(this.slug, this.nameAr, this.approxBytes);
  final String slug;
  final String nameAr;

  /// Rough size on disk, shown before the user opts in to a download.
  final int approxBytes;
}

/// Editions served whole by alquran.cloud (`/v1/quran/{slug}`). Nothing is
/// bundled with the app: each one is downloaded only on the user's request.
const offlineTafsirEditions = <TafsirEdition>[
  TafsirEdition('ar.muyassar', 'التفسير الميسر', 3000000),
  TafsirEdition('ar.jalalayn', 'تفسير الجلالين', 2500000),
];

TafsirEdition? offlineTafsirEdition(String? slug) {
  for (final e in offlineTafsirEditions) {
    if (e.slug == slug) return e;
  }
  return null;
}

class TafsirDownloadException implements Exception {
  TafsirDownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Downloaded tafsir texts stored at
/// `{applicationSupport}/tafsir/{slug}.json` as `{"slug", "surahs": [[ayah texts]]}`.
class OfflineTafsir extends ChangeNotifier {
  OfflineTafsir({http.Client? client, Future<Directory> Function()? root})
    : _client = client ?? http.Client(),
      _rootProvider = root ?? getApplicationSupportDirectory;

  static final OfflineTafsir instance = OfflineTafsir();

  static const sourceBase = 'https://api.alquran.cloud/v1/quran';
  static String sourceUrl(String slug) => '$sourceBase/$slug';

  final http.Client _client;
  final Future<Directory> Function() _rootProvider;

  Future<void>? _ready;
  Directory? _dir;
  final Set<String> _downloaded = {};
  final Map<String, Future<void>> _running = {};

  /// One edition is kept decoded in memory at a time.
  String? _cachedSlug;
  Future<List<List<String>>>? _cached;

  /// Scans the editions already on disk.
  Future<void> ready() => _ready ??= _scan().catchError((Object error) {
    _ready = null;
    throw error;
  });

  Future<void> _scan() async {
    final dir = Directory('${(await _rootProvider()).path}/tafsir');
    _dir = dir;
    _downloaded.clear();
    for (final e in offlineTafsirEditions) {
      if (await _file(e.slug).exists()) _downloaded.add(e.slug);
    }
    notifyListeners();
  }

  File _file(String slug) => File('${_dir!.path}/$slug.json');

  /// Requires [ready]; false until then.
  bool isDownloaded(String slug) => _downloaded.contains(slug);

  bool isDownloading(String slug) => _running.containsKey(slug);

  List<String> get downloaded => [
    for (final e in offlineTafsirEditions)
      if (_downloaded.contains(e.slug)) e.slug,
  ];

  /// [preferred] when it is downloaded, otherwise the first downloaded edition.
  Future<String?> resolve(String? preferred) async {
    await ready();
    if (preferred != null && isDownloaded(preferred)) return preferred;
    final all = downloaded;
    return all.isEmpty ? null : all.first;
  }

  /// Downloads and indexes an edition; a repeated call joins the running one.
  Future<void> download(String slug) {
    return _running[slug] ??= _download(slug).whenComplete(() {
      _running.remove(slug);
      notifyListeners();
    });
  }

  Future<void> _download(String slug) async {
    await ready();
    if (offlineTafsirEdition(slug) == null) {
      throw TafsirDownloadException('هذا التفسير غير متاح للتنزيل');
    }
    notifyListeners();
    late List<List<String>> surahs;
    late Map<String, String> headers;
    try {
      final response = await _client
          .get(Uri.parse(sourceUrl(slug)))
          .timeout(const Duration(minutes: 3));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      surahs = await compute(parseAlQuranCloud, response.bodyBytes);
      headers = response.headers;
    } catch (_) {
      throw TafsirDownloadException(
        'تعذّر تنزيل التفسير. تحقق من الاتصال بالإنترنت ثم أعد المحاولة.',
      );
    }
    final target = _file(slug);
    await target.parent.create(recursive: true);
    final part = File('${target.path}.part');
    await part.writeAsString(
      jsonEncode({'slug': slug, 'surahs': surahs}),
      flush: true,
    );
    await part.rename(target.path);
    if (_cachedSlug == slug) _cached = null;
    _downloaded.add(slug);
    await DownloadUpdates.instance.record(
      'tafsir:$slug',
      sourceUrl(slug),
      headers,
    );
  }

  Future<void> delete(String slug) async {
    await ready();
    await _running[slug]?.catchError((_) {});
    for (final path in [_file(slug).path, '${_file(slug).path}.part']) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    _downloaded.remove(slug);
    await DownloadUpdates.instance.remove('tafsir:$slug');
    if (_cachedSlug == slug) {
      _cachedSlug = null;
      _cached = null;
    }
    notifyListeners();
  }

  /// Bytes on disk for one edition (0 when not downloaded).
  Future<int> size(String slug) async {
    await ready();
    final f = _file(slug);
    return await f.exists() ? f.length() : 0;
  }

  Future<int> totalSize() async {
    var total = 0;
    for (final e in offlineTafsirEditions) {
      total += await size(e.slug);
    }
    return total;
  }

  Future<List<List<String>>?> _load(String slug) async {
    await ready();
    if (!isDownloaded(slug)) return null;
    if (_cachedSlug != slug || _cached == null) {
      _cachedSlug = slug;
      _cached = () async {
        final text = await _file(slug).readAsString();
        return compute(_decodeStored, text);
      }();
    }
    try {
      return await _cached!;
    } catch (_) {
      // A corrupt file: drop it so the user can download it again.
      _cached = null;
      _cachedSlug = null;
      await delete(slug);
      return null;
    }
  }

  /// Tafsir of one ayah (`"2:255"`), or null when not downloaded/available.
  Future<String?> text(String slug, String ayahKey) async {
    final parts = ayahKey.split(':');
    if (parts.length != 2) return null;
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    if (surah == null || ayah == null) return null;
    final surahs = await _load(slug);
    if (surahs == null || surah < 1 || surah > surahs.length) return null;
    final ayahs = surahs[surah - 1];
    if (ayah < 1 || ayah > ayahs.length) return null;
    final value = ayahs[ayah - 1];
    return value.isEmpty ? null : value;
  }

  /// Ayah key → tafsir for a whole surah; null when not downloaded.
  Future<Map<String, String>?> surah(String slug, int surahId) async {
    final surahs = await _load(slug);
    if (surahs == null || surahId < 1 || surahId > surahs.length) return null;
    final ayahs = surahs[surahId - 1];
    return {
      for (var i = 0; i < ayahs.length; i++)
        if (ayahs[i].isNotEmpty) '$surahId:${i + 1}': ayahs[i],
    };
  }

  /// Same shape as `GET /quran/ayahs/{key}/tafsir`, so the reader's tafsir
  /// sheet can use it in place of the API when no backend is configured.
  /// Returns null when the edition is not downloaded.
  Future<Map<String, dynamic>?> ayahTafsir(String ayahKey, String slug) async {
    await ready();
    final edition = offlineTafsirEdition(slug);
    if (edition == null || !isDownloaded(slug)) return null;
    return {
      'ayahKey': ayahKey,
      'edition': {'slug': slug, 'nameAr': edition.nameAr},
      'text': await text(slug, ayahKey),
      'source': 'OFFLINE',
    };
  }
}

/// Parses an alquran.cloud `/v1/quran/{edition}` response into ayah texts
/// per surah (index 0 = Al-Fatiha).
List<List<String>> parseAlQuranCloud(List<int> bytes) {
  final decoded = jsonDecode(utf8.decode(bytes));
  final data = decoded is Map ? decoded['data'] : null;
  final surahs = data is Map ? data['surahs'] : null;
  if (surahs is! List || surahs.isEmpty) {
    throw const FormatException('Unexpected tafsir response');
  }
  final result = <List<String>>[];
  for (final s in surahs) {
    final ayahs = (s as Map)['ayahs'] as List;
    final texts = List.filled(ayahs.length, '');
    for (final a in ayahs.cast<Map>()) {
      final n = a['numberInSurah'] as int;
      if (n >= 1 && n <= texts.length) {
        texts[n - 1] = '${a['text'] ?? ''}'.trim();
      }
    }
    final number = s['number'] as int;
    while (result.length < number - 1) {
      result.add(const []);
    }
    if (result.length == number - 1) result.add(texts);
  }
  return result;
}

List<List<String>> _decodeStored(String text) {
  final decoded = jsonDecode(text) as Map;
  return [
    for (final s in decoded['surahs'] as List) (s as List).cast<String>(),
  ];
}
