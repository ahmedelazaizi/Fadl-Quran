/// Bundled verse-audio reciters: the first 18 mirror backend/scripts/seed-data.ts.
/// Parhizgar's ID and 48 kbps URL come from https://api.alquran.cloud/v1/edition?format=audio
/// and https://api.alquran.cloud/v1/ayah/1/ar.parhizgar.
/// The API does not state his riwaya, so it stays unspecified.
/// Full-surah-only editions belong to the separate MP3Quran catalog.
/// Check public redistribution rights before repackaging CDN audio; the app
/// continues to stream/download under its existing policy.
library;

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
  for (final reciter in reciters) {
    if (reciter['id'] == id) return reciter;
  }
  return null;
}

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
String ayahAudioUrl(String reciterId, int globalAyah) {
  final reciter = reciterById(reciterId);
  if (reciter == null) throw ArgumentError.value(reciterId, 'reciterId');
  final bitrate = pickBitrate((reciter['verseBitrates'] as List).cast<int>());
  return verseAudioUrl(reciterId, bitrate, globalAyah);
}
