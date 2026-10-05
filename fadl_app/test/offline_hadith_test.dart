import 'dart:convert';
import 'dart:io';

import 'package:fadl/core/offline_hadith.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Map<String, dynamic> nawawi;
  late Map<String, dynamic> tirmidhi;
  late Map<String, dynamic> bukhari;
  late Map<String, dynamic> grades;

  Future<Map<String, dynamic>> fixture(String name) async =>
      jsonDecode(await File('../backend/data/cache/$name.json').readAsString())
          as Map<String, dynamic>;

  OfflineHadith open({
    bool invalid = false,
    bool graded = false,
    bool defaultGrade = false,
  }) => OfflineHadith(
    root: () async => root,
    publicClient: MockClient((request) async {
      if (invalid) return http.Response('unavailable', 503);
      final source = request.url.host == 'cdn.jsdelivr.net'
          ? grades
          : graded
          ? tirmidhi
          : defaultGrade
          ? bukhari
          : nawawi;
      return http.Response.bytes(utf8.encode(jsonEncode(source)), 200);
    }),
  );

  setUpAll(() async {
    nawawi = await fixture('hadith-nawawi40');
    tirmidhi = await fixture('hadith-tirmidhi');
    bukhari = await fixture('hadith-bukhari');
    bukhari = {
      ...bukhari,
      'hadiths': (bukhari['hadiths'] as List).take(3).toList(),
    };
    grades = await fixture('grades-tirmidhi');
    // Keep grade fixture bounded while retaining authentic records and text.
    tirmidhi = {
      ...tirmidhi,
      'hadiths': (tirmidhi['hadiths'] as List).take(120).toList(),
    };
    grades = {
      ...grades,
      'hadiths': (grades['hadiths'] as List).take(120).toList(),
    };
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('hadith_test');
  });
  tearDown(() async => root.delete(recursive: true));

  test('public catalog exposes every mapped book without a backend', () async {
    final store = open();
    await store.ready();
    expect(store.availableBooks.length, 16);
    expect(store.availableBooks.first['slug'], 'bukhari');
    expect(
      store.availableBooks.where((book) => book['group'] == 'forties').length,
      2,
    );
    expect(store.downloadedBooks, isEmpty);
  });

  test('every public book has a positive download estimate', () {
    final slugs = open().availableBooks
        .map((book) => book['slug'] as String)
        .toSet();
    expect(slugs, hasLength(16));
    expect(hadithApproxDownloadBytes.keys.toSet(), slugs);
    expect(
      hadithApproxDownloadBytes.values.every((bytes) => bytes > 0),
      isTrue,
    );
    expect(
      hadithApproxDownloadBytes['bukhari']!,
      greaterThan(hadithApproxDownloadBytes['nawawi40']!),
    );
  });

  test(
    'authentic Nawawi collection persists full text, order and null grade',
    () async {
      final store = open();
      await store.download(
        'nawawi40',
        store.availableBooks.firstWhere((book) => book['slug'] == 'nawawi40'),
      );
      final reopened = open();
      final book = await reopened.book('nawawi40');
      expect(book?['nameAr'], 'الأربعون النووية');
      expect(book?['hadithCount'], 42);
      final chapters = book!['chapters'] as List;
      expect(chapters.first['number'], 0);
      expect(chapters.first['count'], 42);
      final page = await reopened.hadiths(
        'nawawi40',
        chapterId: chapters.first['id'] as int,
        limit: 2,
      );
      expect(page['total'], 42);
      final rows = page['hadiths'] as List;
      final original = nawawi['hadiths'] as List;
      expect(rows[0]['number'], original[0]['idInBook']);
      expect(rows[1]['number'], original[1]['idInBook']);
      expect(rows[0]['textAr'], (original[0]['arabic'] as String).trim());
      expect(
        rows[0]['textEn'],
        (original[0]['english']['text'] as String).trim(),
      );
      expect(rows[0]['grade'], isNull);
      expect(rows[0]['gradeSource'], isNull);
      expect(rows[0]['reference'], 'الأربعون النووية (1)');
      expect(
        (rows[0]['links'] as Map)['dorar'],
        startsWith('https://dorar.net/hadith/search?q='),
      );
      expect(
        (await reopened.search('النيات', bookSlug: 'nawawi40'))['total'],
        greaterThan(0),
      );
      await reopened.delete('nawawi40');
      expect(await reopened.size('nawawi40'), 0);
    },
  );

  test(
    'authentic Tirmidhi subset only grades unique normalized matches',
    () async {
      final store = open(graded: true);
      await store.download(
        'tirmidhi',
        store.availableBooks.firstWhere((book) => book['slug'] == 'tirmidhi'),
      );
      final rows =
          (await store.hadiths('tirmidhi', limit: 120))['hadiths'] as List;
      expect(rows.length, 120);
      expect(rows.map((row) => row['id']).toSet().length, 120);
      expect(rows.any((row) => row['grade'] != null), isTrue);
      expect(
        rows
            .where((row) => row['grade'] != null)
            .every((row) => row['gradeSource'] != null),
        isTrue,
      );
    },
  );

  test('ambiguous authentic grade prefix remains ungraded', () async {
    String prefix(String text) {
      final normalized = OfflineHadith.normalize(
        text,
      ).replaceAll(RegExp(r'\s'), '');
      return normalized.substring(0, normalized.length.clamp(0, 120));
    }

    final own = (tirmidhi['hadiths'] as List).cast<Map<String, dynamic>>();
    final feed = (grades['hadiths'] as List).cast<Map<String, dynamic>>();
    final ownPrefixes = own
        .map((hadith) => prefix(hadith['arabic'] as String))
        .toSet();
    final matching = feed.firstWhere(
      (hadith) => ownPrefixes.contains(prefix(hadith['text'] as String)),
    );
    final original = grades;
    grades = {
      ...grades,
      'hadiths': [...feed, matching],
    };
    try {
      final store = open(graded: true);
      await store.download('tirmidhi', store.availableBooks[3]);
      final rows =
          (await store.hadiths('tirmidhi', limit: 120))['hadiths'] as List;
      final ownHadith = own.firstWhere(
        (hadith) =>
            prefix(hadith['arabic'] as String) ==
            prefix(matching['text'] as String),
      );
      final row = rows.firstWhere(
        (hadith) => hadith['number'] == ownHadith['idInBook'],
      );
      expect(row['grade'], isNull);
      expect(row['gradeSource'], isNull);
    } finally {
      grades = original;
    }
  });

  test(
    'Bukhari default grade comes from the documented book mapping',
    () async {
      final store = open(defaultGrade: true);
      await store.download('bukhari', store.availableBooks.first);
      final rows = (await store.hadiths('bukhari'))['hadiths'] as List;
      expect(rows.length, 3);
      expect(
        rows.every(
          (row) =>
              row['grade'] == 'صحيح' && row['gradeSource'] == 'صحيح البخاري',
        ),
        isTrue,
      );
      expect(
        rows.first['textAr'],
        ((bukhari['hadiths'] as List).first['arabic'] as String).trim(),
      );
    },
  );

  test('bad response and unlisted slug never leave a complete book', () async {
    final store = open(invalid: true);
    await expectLater(
      store.download('nawawi40', store.availableBooks[9]),
      throwsA(isA<FormatException>()),
    );
    expect(store.isDownloaded('nawawi40'), isFalse);
    expect(Directory('${root.path}/hadith').existsSync(), isFalse);
    expect(
      () => store.download('../nawawi40', {'slug': '../nawawi40'}),
      throwsStateError,
    );
  });
}
