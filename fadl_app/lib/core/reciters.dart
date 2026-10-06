/// Bundled verse-audio reciters: the first 18 mirror backend/scripts/seed-data.ts.
/// Parhizgar's ID and 48 kbps URL come from https://api.alquran.cloud/v1/edition?format=audio
/// and https://api.alquran.cloud/v1/ayah/1/ar.parhizgar.
/// The API does not state his riwaya, so it stays unspecified.
/// Full-surah-only editions belong to the separate MP3Quran catalog.
/// Check public redistribution rights before repackaging CDN audio; the app
/// continues to stream/download under its existing policy.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_athkar.dart' show normalizeArabic;

const String defaultReciterId = 'ar.abdulbasitmurattal';
const String defaultRiwaya = 'حفص عن عاصم';

/// Same CDN as the server's `AUDIO_CDN` default.
const String audioCdn = 'https://cdn.islamic.network/quran';

/// Bitrates verified against cdn.islamic.network.
// dart format off
const List<Map<String, dynamic>> _seed = [
  {'id': 'ar.abdulbasitmurattal', 'nameAr': 'عبد الباسط عبد الصمد', 'nameEn': 'Abdul Basit Abdul Samad', 'style': 'مرتل', 'verseBitrates': [192, 64], 'surahBitrate': 128, 'isDefault': true},
  {'id': 'ar.aymanswoaid', 'nameAr': 'أيمن سويد', 'nameEn': 'Ayman Sowaid', 'style': 'معلم', 'riwaya': 'حفص عن عاصم', 'verseBitrates': [64], 'surahBitrate': null},
  {'id': 'ar.husary', 'nameAr': 'محمود خليل الحصري', 'nameEn': 'Mahmoud Khalil Al-Husary', 'style': 'مرتل', 'verseBitrates': [128, 64], 'surahBitrate': null},
  {'id': 'ar.husarymujawwad', 'nameAr': 'محمود خليل الحصري', 'nameEn': 'Al-Husary (Mujawwad)', 'style': 'مجود', 'verseBitrates': [128, 64], 'surahBitrate': null},
  {'id': 'ar.minshawi', 'nameAr': 'محمد صديق المنشاوي', 'nameEn': 'Mohamed Siddiq Al-Minshawi', 'style': 'مرتل', 'verseBitrates': [128], 'surahBitrate': null},
  {'id': 'ar.minshawimujawwad', 'nameAr': 'محمد صديق المنشاوي', 'nameEn': 'Al-Minshawi (Mujawwad)', 'style': 'مجود', 'verseBitrates': [64], 'surahBitrate': null},
  {'id': 'ar.alafasy', 'nameAr': 'مشاري راشد العفاسي', 'nameEn': 'Mishary Rashid Alafasy', 'style': 'مرتل', 'verseBitrates': [128, 64], 'surahBitrate': 128},
  {'id': 'ar.mahermuaiqly', 'nameAr': 'ماهر المعيقلي', 'nameEn': 'Maher Al-Muaiqly', 'style': 'مرتل', 'verseBitrates': [128, 64], 'surahBitrate': null},
  {'id': 'ar.abdurrahmaansudais', 'nameAr': 'عبد الرحمن السديس', 'nameEn': 'Abdurrahman As-Sudais', 'style': 'مرتل', 'verseBitrates': [192, 64], 'surahBitrate': null},
  {'id': 'ar.saoodshuraym', 'nameAr': 'سعود الشريم', 'nameEn': 'Saud Ash-Shuraim', 'style': 'مرتل', 'verseBitrates': [64], 'surahBitrate': null},
  {'id': 'ar.hudhaify', 'nameAr': 'علي بن عبد الرحمن الحذيفي', 'nameEn': 'Ali Al-Hudhaify', 'style': 'مرتل', 'verseBitrates': [128, 64, 32], 'surahBitrate': null},
  {'id': 'ar.muhammadayyoub', 'nameAr': 'محمد أيوب', 'nameEn': 'Muhammad Ayyoub', 'style': 'مرتل', 'verseBitrates': [128], 'surahBitrate': null},
  {'id': 'ar.abdullahbasfar', 'nameAr': 'عبد الله بصفر', 'nameEn': 'Abdullah Basfar', 'style': 'مرتل', 'verseBitrates': [192, 64, 32], 'surahBitrate': 128},
  {'id': 'ar.shaatree', 'nameAr': 'أبو بكر الشاطري', 'nameEn': 'Abu Bakr Ash-Shaatree', 'style': 'مرتل', 'verseBitrates': [128, 64], 'surahBitrate': null},
  {'id': 'ar.ahmedajamy', 'nameAr': 'أحمد بن علي العجمي', 'nameEn': 'Ahmed Al-Ajamy', 'style': 'مرتل', 'verseBitrates': [128, 64], 'surahBitrate': null},
  {'id': 'ar.hanirifai', 'nameAr': 'هاني الرفاعي', 'nameEn': 'Hani Rifai', 'style': 'مرتل', 'riwaya': 'حفص عن عاصم', 'verseBitrates': [192, 64], 'surahBitrate': null},
  {'id': 'ar.ibrahimakhbar', 'nameAr': 'إبراهيم الأخضر', 'nameEn': 'Ibrahim Akhdar', 'style': 'مرتل', 'riwaya': 'حفص عن عاصم', 'verseBitrates': [32], 'surahBitrate': null},
  {'id': 'ar.muhammadjibreel', 'nameAr': 'محمد جبريل', 'nameEn': 'Muhammad Jibreel', 'style': 'مرتل', 'riwaya': 'حفص عن عاصم', 'verseBitrates': [128], 'surahBitrate': null},
  {'id': 'ar.parhizgar', 'nameAr': 'شهریار پرهیزگار', 'nameEn': 'Shahriar Parhizgar', 'style': 'غير محدد', 'verseBitrates': [48], 'surahBitrate': null},
];
// dart format on

/// The 18 server reciters followed by one additional verse reciter.
final List<Map<String, dynamic>> reciters = List.unmodifiable([
  for (final (index, reciter) in _seed.indexed)
    Map<String, dynamic>.unmodifiable({
      ...reciter,
      'riwaya': reciter['riwaya'] ?? (index < 18 ? defaultRiwaya : 'غير محددة'),
      'isDefault': reciter['isDefault'] ?? false,
      'sortOrder': index,
    }),
]);

bool matchesReciterSearch(Map<String, dynamic> reciter, String query) {
  final needle = normalizeArabic(query);
  if (needle.isEmpty) return true;
  return normalizeArabic(reciter['nameAr'] as String).contains(needle) ||
      normalizeArabic(reciter['nameEn'] as String).contains(needle);
}

Map<String, dynamic>? reciterById(String id) {
  for (final reciter in allReciters) {
    if (reciter['id'] == id) return reciter;
  }
  return null;
}

/// Bundled reciters followed by the everyayah.com catalog once loaded.
List<Map<String, dynamic>> get allReciters => [
  ...reciters,
  ...ReciterCatalog.instance.everyAyah,
];

/// Highest available bitrate that does not exceed the requested one
/// (mirrors `pickBitrate` in backend/src/modules/quran/service.ts).
int pickBitrate(List<int> available, [int? requested]) {
  final sorted = [...available]..sort((a, b) => b - a);
  if (requested == null || requested == 0) return sorted.first;
  return sorted.firstWhere((b) => b <= requested, orElse: () => sorted.last);
}

/// Mirrors `verseAudioUrl` in backend/src/modules/quran/service.ts.
String verseAudioUrl(String reciterId, int bitrate, int globalAyah) =>
    '$audioCdn/audio/$bitrate/$reciterId/$globalAyah.mp3';

/// Mirrors `surahAudioUrl` in backend/src/modules/quran/service.ts.
String surahAudioUrl(String reciterId, int bitrate, int surah) =>
    '$audioCdn/audio-surah/$bitrate/$reciterId/$surah.mp3';

/// Verse URL at the bitrate the server's playlist uses (no bitrate requested).
/// everyayah.com files are named by surah and ayah, so those reciters need
/// [surah] and [ayah] as well.
String ayahAudioUrl(String reciterId, int globalAyah, {int? surah, int? ayah}) {
  final reciter = reciterById(reciterId);
  if (reciter == null) throw ArgumentError.value(reciterId, 'reciterId');
  if (reciter['provider'] == 'everyayah') {
    if (surah == null || ayah == null) {
      throw ArgumentError('everyayah needs the surah and ayah number');
    }
    return everyAyahUrl(reciter['folder'] as String, surah, ayah);
  }
  final bitrate = pickBitrate((reciter['verseBitrates'] as List).cast<int>());
  return verseAudioUrl(reciterId, bitrate, globalAyah);
}

const everyAyahBase = 'https://everyayah.com/data/';

/// everyayah.com's machine-readable list of its verse-by-verse recordings.
const everyAyahIndexUrl = '${everyAyahBase}recitations.js';

String everyAyahUrl(String folder, int surah, int ayah) =>
    '$everyAyahBase$folder/${'$surah'.padLeft(3, '0')}${'$ayah'.padLeft(3, '0')}.mp3';

/// Arabic names for everyayah folders, matched by a lower-case fragment of
/// the folder name; the first match wins, so specific entries come first.
const _everyAyahArabic = <(String, String)>[
  ('abdul_basit_mujawwad', 'عبد الباسط عبد الصمد (مجود)'),
  ('warsh_abdul_basit', 'عبد الباسط عبد الصمد (ورش)'),
  ('abdul_basit', 'عبد الباسط عبد الصمد'),
  ('juhaynee', 'عبد الله عواد الجهني'),
  ('basfar', 'عبد الله بصفر'),
  ('matroud', 'عبد الله مطرود'),
  ('sudais', 'عبد الرحمن السديس'),
  ('shaatree', 'أبو بكر الشاطري'),
  ('ajamy', 'أحمد بن علي العجمي'),
  ('neana', 'أحمد نعينع'),
  ('alaqimy', 'أكرم العلاقمي'),
  ('alafasy', 'مشاري راشد العفاسي'),
  ('suesy', 'علي حجاج السويسي'),
  ('ali_jaber', 'علي جابر'),
  ('ayman_sowaid', 'أيمن سويد'),
  ('alili', 'عزيز عليلي'),
  ('fares_abbad', 'فارس عباد'),
  ('ghamadi', 'سعد الغامدي'),
  ('hani_rifai', 'هاني الرفاعي'),
  ('hudhaify', 'علي الحذيفي'),
  ('husary_muallim', 'محمود خليل الحصري (المعلم)'),
  ('husary_128kbps_mujawwad', 'محمود خليل الحصري (مجود)'),
  ('husary', 'محمود خليل الحصري'),
  ('akhdar', 'إبراهيم الأخضر'),
  ('karim_mansoori', 'كريم منصوري'),
  ('qahtaanee', 'خالد القحطاني'),
  ('tunaiji', 'خليفة الطنيجي'),
  ('muaiqly', 'ماهر المعيقلي'),
  ('minshawy_mujawwad', 'محمد صديق المنشاوي (مجود)'),
  ('minshawy_teacher', 'محمد صديق المنشاوي (المعلم)'),
  ('minshawy', 'محمد صديق المنشاوي'),
  ('menshawi', 'محمد صديق المنشاوي'),
  ('tablaway', 'محمد الطبلاوي'),
  ('abdulkareem', 'محمد عبد الكريم'),
  ('ayyoub', 'محمد أيوب'),
  ('jibreel', 'محمد جبريل'),
  ('qasim', 'محسن القاسم'),
  ('mustafa_ismail', 'مصطفى إسماعيل'),
  ('rifa3i', 'نبيل الرفاعي'),
  ('qatami', 'ناصر القطامي'),
  ('parhizgar', 'شهريار پرهيزگار'),
  ('sahl_yassin', 'سهل ياسين'),
  ('bukhatir', 'صلاح بو خاطر'),
  ('budair', 'صلاح البدير'),
  ('shuraym', 'سعود الشريم'),
  ('yaser_salamah', 'ياسر سلامة'),
  ('dussary', 'ياسر الدوسري'),
  ('ibrahim_aldosary', 'إبراهيم الدوسري (ورش)'),
  ('yassin_al_jazaery', 'ياسين الجزائري (ورش)'),
  ('banna', 'محمود علي البنا'),
  ('mansour', 'منصور السالمي'),
];

final _bitrate = RegExp(r'(\d+)\s*kbps', caseSensitive: false);
final _entry = RegExp(
  r'\{\s*"subfolder"\s*:\s*"([^"]+)"\s*,\s*"name"\s*:\s*"([^"]*)"\s*,\s*"bitrate"\s*:\s*"([^"]*)"\s*\}',
);

/// Reciters from everyayah.com's index, one entry per recording set: the
/// same reciter at several bitrates keeps 128 kbps, else the closest below,
/// else the lowest above. Translations and folders that would escape the
/// data directory are skipped.
@visibleForTesting
List<Map<String, dynamic>> parseEveryAyahIndex(String source) {
  final best = <String, (int, Map<String, dynamic>)>{};
  for (final match in _entry.allMatches(source)) {
    final folder = match.group(1)!;
    final name = match.group(2)!.trim();
    final lower = folder.toLowerCase();
    if (lower.startsWith('translations') ||
        folder.contains('..') ||
        folder.startsWith('/') ||
        !RegExp(r'^[A-Za-z0-9_./-]+$').hasMatch(folder)) {
      continue;
    }
    final kbps =
        int.tryParse(
          _bitrate.firstMatch(match.group(3)!)?.group(1) ??
              _bitrate.firstMatch(folder)?.group(1) ??
              '',
        ) ??
        0;
    // Prefer 128 kbps, then the highest below it, then the lowest above.
    final rank = kbps == 128
        ? 0
        : kbps < 128
        ? 1000 - kbps
        : 2000 + kbps;
    // "Maher_AlMuaiqly_64kbps" and "MaherAlMuaiqly128kbps" are one set.
    final set = lower
        .replaceAll(_bitrate, '')
        .replaceAll('ketaballah.net', '')
        .replaceAll(RegExp(r'[^a-z0-9/]'), '');
    final arabic = [
      for (final (fragment, label) in _everyAyahArabic)
        if (lower.contains(fragment)) label,
    ].firstOrNull;
    final reciter = <String, dynamic>{
      'id': 'ea.${folder.replaceAll('/', '__')}',
      'provider': 'everyayah',
      'folder': folder,
      'nameAr': arabic ?? name,
      'nameEn': name,
      'style': lower.contains('mujawwad')
          ? 'مجود'
          : lower.contains('muallim') || lower.contains('teacher')
          ? 'معلم'
          : 'مرتل',
      'riwaya': lower.contains('warsh') ? 'ورش عن نافع' : defaultRiwaya,
      'verseBitrates': [if (kbps > 0) kbps else 64],
      'surahBitrate': null,
      'isDefault': false,
    };
    final current = best[set];
    if (current == null || rank < current.$1) best[set] = (rank, reciter);
  }
  final list = [for (final (_, reciter) in best.values) reciter]
    ..sort((a, b) => (a['nameAr'] as String).compareTo(b['nameAr'] as String));
  return [
    for (final (index, reciter) in list.indexed)
      Map<String, dynamic>.unmodifiable({...reciter, 'sortOrder': 100 + index}),
  ];
}

/// The everyayah.com catalog, cached on the device so it works offline
/// after one successful download, plus the user's favourite reciters.
class ReciterCatalog extends ChangeNotifier {
  ReciterCatalog({http.Client? client}) : _client = client ?? http.Client();

  static final ReciterCatalog instance = ReciterCatalog();
  static const _cacheKey = 'fadl.reciters.everyayah.v1';
  static const _favoritesKey = 'fadl.reciters.favorites';

  final http.Client _client;
  List<Map<String, dynamic>> everyAyah = const [];
  Set<String> favorites = {};
  Future<void>? _loading;

  /// Reads the cached catalog and favourites, then refreshes online in the
  /// background; failures keep whatever was cached.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    favorites = (prefs.getStringList(_favoritesKey) ?? const []).toSet();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) everyAyah = parseEveryAyahIndex(cached);
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    try {
      final response = await _client
          .get(Uri.parse(everyAyahIndexUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return;
      final body = response.body;
      final parsed = parseEveryAyahIndex(body);
      if (parsed.isEmpty) return;
      everyAyah = parsed;
      await (await SharedPreferences.getInstance()).setString(_cacheKey, body);
      notifyListeners();
    } catch (error) {
      debugPrint('ReciterCatalog: everyayah index unavailable: $error');
    }
  }

  bool isFavorite(String id) => favorites.contains(id);

  Future<void> toggleFavorite(String id) async {
    if (!favorites.remove(id)) favorites.add(id);
    notifyListeners();
    await (await SharedPreferences.getInstance()).setStringList(
      _favoritesKey,
      favorites.toList(),
    );
  }

  /// Favourites first, then bundled reciters, then the everyayah catalog.
  List<Map<String, dynamic>> ordered() {
    final all = [...reciters, ...everyAyah];
    return [
      for (final reciter in all)
        if (isFavorite(reciter['id'] as String)) reciter,
      for (final reciter in all)
        if (!isFavorite(reciter['id'] as String)) reciter,
    ];
  }
}
