import 'dart:convert';
import 'dart:io';

final _diacritics = RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]');
final _searchMarks = RegExp(
  r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u08D3-\u08FF]',
);
final _nonArabic = RegExp(r'[^\u0621-\u064A0-9a-zA-Z\s]');

String _plainSurahName(String name) => name
    .replaceAll(_diacritics, '')
    .replaceAll('\u0671', 'ا')
    .replaceFirst(RegExp(r'^سورة\s+'), '')
    .trim();

String _normalizeArabic(String text) => text
    .replaceAll(_searchMarks, '')
    .replaceAll('\u0640', '')
    .replaceAll(RegExp(r'[\u0622\u0623\u0625\u0671\u0672\u0673]'), 'ا')
    .replaceAll('\u0649', 'ي')
    .replaceAll('\u0629', 'ه')
    .replaceAll('\u0624', 'و')
    .replaceAll('\u0626', 'ي')
    .replaceAll(_nonArabic, ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

String _uthmaniText(String raw, int surah, int number) {
  final text = raw.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
  if (surah == 1 || surah == 9 || number != 1) return text;
  final words = text.split(RegExp(r'\s+'));
  if (_normalizeArabic(words.take(4).join(' ')) == 'بسم الله الرحمن الرحيم') {
    return words.skip(4).join(' ');
  }
  return text;
}

void main() {
  final source = File('../backend/data/cache/quran-uthmani.json');
  final surahs =
      ((jsonDecode(source.readAsStringSync()) as Map)['data'] as Map)['surahs']
          as List;
  final metadata = <List<Object?>>[];
  final ayahs = <List<Object?>>[];
  for (final entry in surahs) {
    final surah = entry as Map;
    final id = surah['number'] as int;
    final verses = surah['ayahs'] as List;
    metadata.add([
      id,
      _plainSurahName(surah['name'] as String),
      surah['englishNameTranslation'],
      surah['englishName'],
      surah['revelationType'] == 'Meccan' ? 'MECCAN' : 'MEDINAN',
      verses.length,
      (verses.first as Map)['page'],
    ]);
    for (final entry in verses) {
      final ayah = entry as Map;
      ayahs.add([
        ayah['number'],
        id,
        ayah['numberInSurah'],
        ayah['page'],
        ayah['juz'],
        ayah['hizbQuarter'],
        _uthmaniText(ayah['text'] as String, id, ayah['numberInSurah'] as int),
        ayah['sajda'] != false,
      ]);
    }
  }
  if (metadata.length != 114 || ayahs.length != 6236) {
    throw StateError('Unexpected Quran source counts');
  }
  final output = File('assets/quran/quran.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(jsonEncode({'s': metadata, 'a': ayahs}));
  stdout.writeln('${output.path}: ${output.lengthSync()} bytes');
}
