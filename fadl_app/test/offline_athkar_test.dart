import 'dart:convert';
import 'dart:io';

import 'package:fadl/core/api.dart';
import 'package:fadl/core/offline_athkar.dart';
import 'package:fadl/core/quran_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The SQLite JSON export the backend seeds from.
List<List<dynamic>> sourceRows() {
  final json =
      jsonDecode(File('../backend/data/cache/azkar.json').readAsStringSync())
          as Map<String, dynamic>;
  return (json['rows'] as List).cast<List<dynamic>>();
}

/// Simulates an app restart: keep only what was persisted to disk.
Future<void> reloadPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = {for (final k in prefs.getKeys()) k: prefs.get(k)!};
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues(stored.cast<String, Object>());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineAthkar athkar;
  late List<List<dynamic>> source;

  setUpAll(() async {
    athkar = await OfflineAthkar.load();
    source = sourceRows();
  });

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  test('asset rows are the source rows without the search column', () {
    final asset =
        jsonDecode(File('assets/athkar/azkar.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(asset['columns'], [
      'category',
      'zekr',
      'description',
      'count',
      'reference',
    ]);
    expect(asset['rows'], [for (final r in source) r.sublist(0, 5)]);
    expect(Api.hasBackend, isFalse);
  });

  test('featured categories follow seed-data.ts slugs and order', () {
    final featured = athkar.categories(featured: true);
    expect(featured.map((c) => c['slug']), [
      for (final f in featuredAthkarCategories.values) f.slug,
    ]);
    expect(featured.map((c) => c['nameAr']), featuredAthkarCategories.keys);
    for (final c in featured) {
      final rows = source.where((r) => (r[0] as String).trim() == c['nameAr']);
      expect(c['count'], rows.length, reason: c['slug'] as String);
    }
    final all = athkar.categories();
    final names = <String>{for (final r in source) r[0] as String};
    expect(all.length, names.length);
    expect(all.take(featured.length).toList(), featured);
    final others = all.where((c) => c['featured'] != true);
    expect(
      others.every((c) => (c['slug'] as String).startsWith('hisn-')),
      isTrue,
    );
  });

  test('morning and evening items match the source text exactly', () {
    for (final slug in ['morning', 'evening']) {
      final category = athkar.category(slug)!;
      final rows = source
          .where((r) => (r[0] as String).trim() == category['nameAr'])
          .toList();
      final items = (category['items'] as List).cast<Map<String, dynamic>>();
      expect(items.map((i) => i['text']), [
        for (final r in rows) (r[1] as String).trim(),
      ]);
      expect(items.map((i) => i['repeat']), [
        for (final r in rows) r[3] is int && (r[3] as int) > 0 ? r[3] : 1,
      ]);
      expect(
        category['totalRepeats'],
        items.fold<int>(0, (s, i) => s + (i['repeat'] as int)),
      );
      expect(items.first['amenKey'], 'dhikr:${items.first['id']}');
    }
    expect(athkar.category('missing'), isNull);
  });

  test('search ignores diacritics and returns category info', () {
    final first =
        (athkar.category('morning')!['items'] as List).first
            as Map<String, dynamic>;
    // Search with a diacritized word taken from the dhikr itself.
    final word = (first['text'] as String)
        .split(RegExp(r'\s+'))
        .firstWhere((w) => normalizeArabic(w).length >= 4);
    final results = athkar.search(word, limit: 50);
    expect(results.map((r) => r['id']), contains(first['id']));
    final hit = results.firstWhere((r) => r['id'] == first['id']);
    expect(hit['category'], {'slug': 'morning', 'nameAr': 'أذكار الصباح'});
    expect(
      athkar.search(normalizeArabic(word), limit: 50).length,
      results.length,
    );
    expect(athkar.search('ا'), isEmpty);
  });

  test('dua collections use QuranData verses and asset athkar', () async {
    final quran = await QuranData.load();
    final list = athkar.duaCollectionList();
    expect(list.map((c) => c['slug']), [
      for (final c in duaCollections) c.slug,
    ]);

    for (final spec in duaCollections) {
      final c = athkar.duaCollection(spec.slug, quran)!;
      final items = (c['items'] as List).cast<Map<String, dynamic>>();
      expect(
        list.firstWhere((l) => l['slug'] == spec.slug)['count'],
        items.length,
      );
      final verses = items.where((i) => i['kind'] == 'verse').toList();
      expect(verses.map((v) => v['verseRange']), spec.verses);
      for (final v in verses) {
        final m = RegExp(
          r'^(\d+):(\d+)(?:-(\d+))?$',
        ).firstMatch(v['verseRange'] as String)!;
        final from = int.parse(m[2]!);
        final to = int.parse(m[3] ?? m[2]!);
        expect(
          v['text'],
          [
            for (var n = from; n <= to; n++) quran.ayah('${m[1]}:$n')!['text'],
          ].join(' ۝ '),
        );
        expect(v['amenKey'], 'verse:${v['verseRange']}');
      }
      final dhikr = items.where((i) => i['kind'] == 'dhikr').toList();
      expect(dhikr.map((d) => d['text']), [
        for (final name in spec.categories)
          for (final r in source.where((r) => (r[0] as String).trim() == name))
            (r[1] as String).trim(),
      ]);
    }
    final parents = athkar.duaCollection('parents', quran)!;
    final first = (parents['items'] as List).first as Map<String, dynamic>;
    final surah = quran.surahs.firstWhere((s) => s['id'] == 17);
    expect(first['reference'], 'سورة ${surah['nameAr']} - آية 24');
  });

  test('athkar progress persists across reloads and resets next day', () async {
    final day = DateTime(2026, 3, 1, 9);
    final items = (athkar.category('morning')!['items'] as List)
        .cast<Map<String, dynamic>>();
    for (final i in items) {
      await OfflineAthkarStore.setProgress(
        athkar,
        i['id'] as int,
        i['repeat'] as int,
        now: day,
      );
    }
    final partial = items.firstWhere((i) => (i['repeat'] as int) > 1);
    final put = await OfflineAthkarStore.setProgress(
      athkar,
      partial['id'] as int,
      1,
      now: day,
    );
    expect(put, {
      'dhikrId': partial['id'],
      'count': 1,
      'repeat': partial['repeat'],
      'done': false,
    });

    await reloadPrefs();
    final progress = await OfflineAthkarStore.progress(athkar, now: day);
    final morning = (progress['categories'] as List).firstWhere(
      (c) => c['slug'] == 'morning',
    );
    expect(morning['completed'], items.length - 1);
    expect(morning['total'], items.length);
    expect(morning['status'], 'PARTIAL');
    expect(
      (progress['items'] as List).firstWhere(
        (p) => p['dhikrId'] == partial['id'],
      )['count'],
      1,
    );
    final evening = (progress['categories'] as List).firstWhere(
      (c) => c['slug'] == 'evening',
    );
    expect(evening['status'], 'NOT_STARTED');

    await OfflineAthkarStore.setProgress(
      athkar,
      partial['id'] as int,
      partial['repeat'] as int,
      now: day,
    );
    final done = await OfflineAthkarStore.progress(athkar, now: day);
    expect(
      (done['categories'] as List).firstWhere(
        (c) => c['slug'] == 'morning',
      )['status'],
      'COMPLETED',
    );

    final next = await OfflineAthkarStore.progress(
      athkar,
      now: day.add(const Duration(days: 1)),
    );
    expect(next['items'], isEmpty);
  });

  test('amen, reads, dedications and personal duas persist locally', () async {
    final day = DateTime(2026, 3, 1, 12);
    final first = await OfflineAthkarStore.sayAmen('verse:17:24', now: day);
    expect(first, {
      'targetKey': 'verse:17:24',
      'counted': true,
      'amenCount': 1,
    });
    final again = await OfflineAthkarStore.sayAmen('verse:17:24', now: day);
    expect(again['counted'], isFalse);
    await OfflineAthkarStore.sayAmen(
      'verse:17:24',
      now: day.add(const Duration(days: 1)),
    );
    await OfflineAthkarStore.setRead('verse:17:24', 2, now: day);
    await OfflineAthkarStore.dedicate('DUA');
    await OfflineAthkarStore.dedicate('ATHKAR', amount: 5);

    // A personal dua copied from the dataset (no invented text).
    final text =
        (athkar.category('distress')!['items'] as List).first['text'] as String;
    final saved = await OfflineAthkarStore.savePersonalDua(text, now: day);

    await reloadPrefs();
    expect(await OfflineAthkarStore.amenCounts(), {'verse:17:24': 2});
    expect(await OfflineAthkarStore.reads(now: day), {'verse:17:24': 2});
    expect(
      await OfflineAthkarStore.reads(now: day.add(const Duration(days: 1))),
      isEmpty,
    );
    final stats = await OfflineAthkarStore.dedicationStats();
    expect(stats['totalDedications'], 2);
    expect(stats['byType'], {
      'DUA': {'count': 1, 'amount': 1},
      'ATHKAR': {'count': 1, 'amount': 5},
    });
    final personal = await OfflineAthkarStore.personalDuas();
    expect(personal.single['text'], text);
    expect(
      (personal.single['createdAt'] as String).substring(0, 10),
      '2026-03-01',
    );

    expect(
      await OfflineAthkarStore.deletePersonalDua(saved['id'] as String),
      isTrue,
    );
    await reloadPrefs();
    expect(await OfflineAthkarStore.personalDuas(), isEmpty);
    expect(await OfflineAthkarStore.deletePersonalDua('unknown'), isFalse);
  });
}
