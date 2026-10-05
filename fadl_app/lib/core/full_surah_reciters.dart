import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'offline_athkar.dart' show normalizeArabic;

/// MP3Quran supplies whole-surah recordings, not ayah timestamps or licenses.
/// Streaming availability is not permission to redistribute recordings.
const fullSurahCatalogUrl =
    'https://www.mp3quran.net/api/v3/reciters?language=ar';
const _englishCatalogUrl =
    'https://www.mp3quran.net/api/v3/reciters?language=eng';
const fullSurahModeLabel = 'تلاوات السور كاملة — دون مزامنة تلقائية للآيات';

class FullSurahEdition {
  const FullSurahEdition({
    required this.reciterId,
    required this.editionId,
    required this.nameAr,
    required this.nameEn,
    required this.editionName,
    required this.server,
    required this.surahs,
  });

  final int reciterId;
  final int editionId;
  final String nameAr;
  final String nameEn;
  final String editionName;
  final Uri server;
  final Set<int> surahs;

  String? urlForSurah(int surah) => surahs.contains(surah)
      ? server.resolve('${surah.toString().padLeft(3, '0')}.mp3').toString()
      : null;

  bool matches(String query) {
    final needle = normalizeArabic(query);
    return needle.isEmpty ||
        normalizeArabic(nameAr).contains(needle) ||
        normalizeArabic(nameEn).contains(needle) ||
        normalizeArabic(server.path).contains(needle);
  }
}

/// Keep reciter + edition IDs together: a reciter can have several riwayat.
List<FullSurahEdition> parseFullSurahReciters(
  Map<String, dynamic> arabic, [
  Map<String, dynamic>? english,
]) {
  final englishNames = <int, String>{
    for (final reciter in (english?['reciters'] as List? ?? const []))
      if (reciter is Map && reciter['id'] is int && reciter['name'] is String)
        reciter['id'] as int: reciter['name'] as String,
  };
  final seen = <(int, int)>{};
  final editions = <FullSurahEdition>[];
  for (final reciter in arabic['reciters'] as List) {
    if (reciter is! Map ||
        reciter['id'] is! int ||
        reciter['name'] is! String) {
      continue;
    }
    final id = reciter['id'] as int;
    for (final moshaf in (reciter['moshaf'] as List? ?? const [])) {
      if (moshaf is! Map ||
          moshaf['id'] is! int ||
          moshaf['name'] is! String ||
          moshaf['server'] is! String ||
          moshaf['surah_list'] is! String) {
        continue;
      }
      final editionId = moshaf['id'] as int;
      final server = Uri.tryParse(moshaf['server'] as String);
      if (server == null ||
          server.scheme != 'https' ||
          (server.host != 'mp3quran.net' &&
              !server.host.endsWith('.mp3quran.net')) ||
          !server.path.endsWith('/')) {
        continue;
      }
      final surahs = (moshaf['surah_list'] as String)
          .split(',')
          .map((number) => int.tryParse(number.trim()))
          .whereType<int>()
          .where((number) => number >= 1 && number <= 114)
          .toSet();
      if (surahs.isEmpty || !seen.add((id, editionId))) continue;
      editions.add(
        FullSurahEdition(
          reciterId: id,
          editionId: editionId,
          nameAr: reciter['name'] as String,
          nameEn: englishNames[id] ?? '',
          editionName: moshaf['name'] as String,
          server: server,
          surahs: surahs,
        ),
      );
    }
  }
  return editions;
}

class FullSurahCatalog {
  FullSurahCatalog({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  Future<List<FullSurahEdition>>? _cached;

  void dispose() => _client.close();

  Future<List<FullSurahEdition>> load() =>
      _cached ??= _fetch().catchError((Object error) {
        _cached = null;
        throw error;
      });

  Future<List<FullSurahEdition>> _fetch() async {
    final response = await _client
        .get(Uri.parse(fullSurahCatalogUrl))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw http.ClientException('MP3Quran HTTP ${response.statusCode}');
    }
    Map<String, dynamic>? english;
    try {
      final translated = await _client
          .get(Uri.parse(_englishCatalogUrl))
          .timeout(const Duration(seconds: 8));
      if (translated.statusCode == 200) {
        english =
            jsonDecode(utf8.decode(translated.bodyBytes))
                as Map<String, dynamic>;
      }
    } on http.ClientException {
      // Arabic names and the server's Latin path remain searchable.
    } on TimeoutException {
      // English metadata is optional when the Arabic catalog succeeds.
    }
    return parseFullSurahReciters(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      english,
    );
  }
}
