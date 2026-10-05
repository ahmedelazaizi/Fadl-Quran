import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'quran_data.dart';

class QuranIndex {
  static Future<List<Map<String, dynamic>>>? _surahs;

  static Future<List<Map<String, dynamic>>> surahs() => _surahs ??= () async {
    try {
      return (await QuranData.load()).surahs;
    } catch (_) {
      _surahs = null;
      rethrow;
    }
  }();
}

/// Pages are read from the bundled mushaf without disk or network caching.
class QuranPages {
  QuranPages._();

  static Future<Map<String, dynamic>> load(int page) async =>
      (await QuranData.load()).page(page);

  static void prefetch(int page) {
    if (page >= 1 && page <= 604) QuranData.load();
  }
}

class ReadingPosition {
  const ReadingPosition({
    required this.key,
    required this.page,
    this.number,
    this.juz,
    this.surahName,
  });
  final String key;
  final int page;
  final int? number;
  final int? juz;
  final String? surahName;

  Map<String, dynamic> toJson() => {
    'key': key,
    'page': page,
    'number': number,
    'juz': juz,
    'surahName': surahName,
  };

  static ReadingPosition? fromJson(Object? value) {
    if (value is! Map || value['key'] is! String || value['page'] is! int) {
      return null;
    }
    final page = value['page'] as int;
    if (page < 1 || page > 604) return null;
    return ReadingPosition(
      key: value['key'] as String,
      page: page,
      number: value['number'] is int ? value['number'] as int : null,
      juz: value['juz'] is int ? value['juz'] as int : null,
      surahName: value['surahName'] as String?,
    );
  }
}

/// Local reading position wins over an older server response.
class LastReadStore extends ValueNotifier<ReadingPosition?> {
  LastReadStore._() : super(null);
  static final instance = LastReadStore._();
  static const _prefKey = 'fadl.lastRead';
  Future<void>? _loading;

  Future<void> loadLocal() => _loading ??= () async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null && value == null) {
      try {
        value = ReadingPosition.fromJson(jsonDecode(raw));
      } catch (_) {
        // Ignore an invalid saved position.
      }
    }
  }();

  Future<void> save(ReadingPosition position) async {
    value = position;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(position.toJson()));
  }

  Future<void> refresh() async {
    await loadLocal();
    if (value != null || !Api.hasBackend) return;
    try {
      final response = await Api.instance.get('/me/last-read') as Map;
      final last = response['lastRead'];
      if (last is! Map || last['ayah'] is! Map) return;
      final ayah = last['ayah'] as Map;
      final position = ReadingPosition.fromJson({
        'key': ayah['key'],
        'page': ayah['page'],
        'number': ayah['number'],
        'juz': ayah['juz'],
        'surahName': last['surahNameAr'],
      });
      if (position != null && value == null) await save(position);
    } catch (_) {
      // Resume remains available offline.
    }
  }
}
