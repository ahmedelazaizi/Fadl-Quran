import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Local Uthmani mushaf; compact asset rows expand to the existing API maps.
class QuranData {
  QuranData._(
    this._surahs,
    this._pages,
    this._bySurah,
    this._byKey,
    this._byGlobal,
    this._juzStarts,
  );

  static Future<QuranData>? _cached;

  static Future<QuranData> load() =>
      _cached ??= _read().catchError((Object error) {
        _cached = null;
        throw error;
      });

  static Future<QuranData> _read() async {
    final source = await rootBundle.loadString('assets/quran/quran.json');
    final decoded = await compute(_decodeAsset, source);
    return QuranData._fromRows(decoded);
  }

  static Map<String, dynamic> _decodeAsset(String source) =>
      jsonDecode(source) as Map<String, dynamic>;

  final List<Map<String, dynamic>> _surahs;
  final List<List<Map<String, dynamic>>> _pages;
  final Map<int, List<Map<String, dynamic>>> _bySurah;
  final Map<String, Map<String, dynamic>> _byKey;
  final Map<int, Map<String, dynamic>> _byGlobal;
  final Map<int, int> _juzStarts;

  factory QuranData._fromRows(Map<String, dynamic> rows) {
    final surahs = (rows['s'] as List).map((entry) {
      final row = entry as List;
      final revelation = row[4] as String;
      return <String, dynamic>{
        'id': row[0],
        'nameAr': row[1],
        'nameEn': row[2],
        'nameTranslit': row[3],
        'revelationType': revelation,
        'revelationTypeAr': revelation == 'MECCAN' ? 'مكية' : 'مدنية',
        'ayahCount': row[5],
        'startPage': row[6],
      };
    }).toList();
    final pages = List.generate(605, (_) => <Map<String, dynamic>>[]);
    final bySurah = <int, List<Map<String, dynamic>>>{};
    final byKey = <String, Map<String, dynamic>>{};
    final byGlobal = <int, Map<String, dynamic>>{};
    final juzStarts = <int, int>{};
    for (final entry in rows['a'] as List) {
      final row = entry as List;
      final quarter = row[5] as int;
      final surahId = row[1] as int;
      final number = row[2] as int;
      final ayah = <String, dynamic>{
        'id': row[0],
        'key': '$surahId:$number',
        'surahId': surahId,
        'number': number,
        'page': row[3],
        'juz': row[4],
        'hizbQuarter': quarter,
        'hizb': (quarter + 3) ~/ 4,
        'quarter': (quarter - 1) % 4 + 1,
        'text': row[6],
        'sajda': row[7],
      };
      pages[ayah['page'] as int].add(ayah);
      bySurah.putIfAbsent(surahId, () => []).add(ayah);
      byKey[ayah['key'] as String] = ayah;
      byGlobal[ayah['id'] as int] = ayah;
      juzStarts.putIfAbsent(ayah['juz'] as int, () => ayah['page'] as int);
    }
    return QuranData._(surahs, pages, bySurah, byKey, byGlobal, juzStarts);
  }

  List<Map<String, dynamic>> get surahs => _surahs;
  int juzStartPage(int juz) =>
      _juzStarts[juz] ?? (throw RangeError.range(juz, 1, 30));
  Map<String, dynamic>? ayah(String key) => _byKey[key];
  Map<String, dynamic>? globalAyah(int number) => _byGlobal[number];
  List<Map<String, dynamic>> surahAyahs(int id) =>
      List.unmodifiable(_bySurah[id] ?? const <Map<String, dynamic>>[]);

  Map<String, dynamic> page(int number) {
    if (number < 1 || number > 604) throw RangeError.range(number, 1, 604);
    final verses = _pages[number];
    final first = verses.first;
    final ids = verses.map((ayah) => ayah['surahId'] as int).toSet();
    return {
      'page': number,
      'totalPages': 604,
      'juz': first['juz'],
      'hizb': first['hizb'],
      'quarter': first['quarter'],
      'surahs': _surahs.where((surah) => ids.contains(surah['id'])).toList(),
      'ayahs': verses,
    };
  }
}
