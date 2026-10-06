import 'dart:convert';
import 'dart:io';

import 'package:fadl/core/offline_hadith.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real excerpts of fawazahmed0/hadith-api (Unlicense) editions.
File _fixture(String name) => File('test/fixtures/hadith/$name.json');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late List<Uri> requested;
  late OfflineHadith store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('fadl_hadith_source_');
    requested = [];
    store = OfflineHadith(
      root: () async => root,
      publicClient: MockClient((request) async {
        requested.add(request.url);
        final name = request.url.pathSegments.last.replaceAll('.min.json', '');
        final file = _fixture(name);
        if (!file.existsSync()) return http.Response('', 404);
        return http.Response.bytes(
          utf8.encode(file.readAsStringSync()),
          200,
          headers: {'etag': '"$name"'},
        );
      }),
    );
  });
  tearDown(() => root.delete(recursive: true));

  test('only books with a redistributable source are offered', () {
    expect(store.availableBooks.map((b) => b['slug']), [
      'bukhari',
      'muslim',
      'abudawud',
      'tirmidhi',
      'nasai',
      'ibnmajah',
      'malik',
      'nawawi40',
      'qudsi40',
    ]);
    expect(store.availableBooks.first['nameAr'], 'صحيح البخاري');
    for (final slug in ['bukhari', 'nawawi40']) {
      expect(
        Uri.parse(OfflineHadith.sourceUrl(slug)!).path,
        contains('/fawazahmed0/hadith-api@1/editions/ara-'),
      );
      expect(
        Uri.parse(OfflineHadith.translationSourceUrl(slug)!).path,
        contains('/editions/eng-'),
      );
    }
  });

  test(
    'Nawawi 40 downloads Arabic with diacritics and English by number',
    () async {
      await store.download('nawawi40', {'slug': 'nawawi40'});
      expect(requested.map((u) => u.pathSegments.last), [
        'ara-nawawi.min.json',
        'eng-nawawi.min.json',
      ]);
      final book = (await store.book('nawawi40'))!;
      expect(book['nameAr'], 'الأربعون النووية');
      expect(book['authorAr'], 'يحيى بن شرف النووي');
      expect(book['hadithCount'], 42);
      final page = await store.hadiths('nawawi40', limit: 2);
      final first = (page['hadiths'] as List).first as Map;
      expect(first['number'], 1);
      expect(first['textAr'], contains('إنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ'));
      expect(first['textEn'], contains('Actions are'));
      expect(first['reference'], 'الأربعون النووية (1)');
    },
  );

  test(
    'Sunan keep al-Albani grades, sub-numbers, and skip numbering gaps',
    () async {
      await store.download('tirmidhi', {'slug': 'tirmidhi'});
      final book = (await store.book('tirmidhi'))!;
      // Hadith 391 has no Arabic text, and its section holds nothing else.
      expect(book['hadithCount'], 5);
      expect((book['chapters'] as List).map((c) => c['nameAr']), [
        'The Book on Purification',
        'The Book on Hajj',
      ]);
      final rows =
          ((await store.hadiths('tirmidhi', limit: 10))['hadiths'] as List)
              .cast<Map>();
      expect(rows.first['grade'], 'صحيح');
      expect(rows.first['gradeSource'], 'الألباني');
      expect(rows[2]['grade'], 'حسن صحيح');
      final sub = rows.singleWhere(
        (r) => r['reference'] == 'جامع الترمذي (815.2)',
      );
      expect(sub['number'], 815);
      expect(sub['grade'], isNull);
      expect(sub['textEn'], 'English 815.2');
      expect(sub['chapterAr'], 'The Book on Hajj');
    },
  );

  test('every offered book has a positive download estimate', () {
    final slugs = store.availableBooks.map((b) => b['slug']).toSet();
    expect(hadithApproxDownloadBytes.keys.toSet(), slugs);
    expect(hadithApproxDownloadBytes.values.every((b) => b > 0), isTrue);
    expect(
      hadithApproxDownloadBytes['bukhari']!,
      greaterThan(hadithApproxDownloadBytes['nawawi40']!),
    );
  });

  test('Sahih al-Bukhari rows are graded sahih by the collection', () async {
    await store.download('bukhari', {'slug': 'bukhari'});
    final rows = ((await store.hadiths('bukhari'))['hadiths'] as List)
        .cast<Map>();
    expect(rows, hasLength(3));
    expect(
      rows.every(
        (r) => r['grade'] == 'صحيح' && r['gradeSource'] == 'صحيح البخاري',
      ),
      isTrue,
    );
    expect(rows.first['textEn'], startsWith("Narrated 'Umar bin Al-Khattab"));
  });

  test('a failed source download saves nothing', () async {
    // No Muslim fixture exists, so the source answers 404.
    await expectLater(
      store.download('muslim', {'slug': 'muslim'}),
      throwsA(isA<FormatException>()),
    );
    expect(store.isDownloaded('muslim'), isFalse);
    expect(File('${root.path}/hadith/muslim.jsonl').existsSync(), isFalse);
    expect(
      () => store.download('../nawawi40', {'slug': '../nawawi40'}),
      throwsStateError,
    );
    expect(() => store.download('riyad', {'slug': 'riyad'}), throwsStateError);
  });
}
