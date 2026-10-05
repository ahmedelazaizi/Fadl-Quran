import 'package:fadl/core/offline_athkar.dart';
import 'package:fadl/core/offline_quran_search.dart';
import 'package:fadl/core/quran_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineQuranSearch search;
  late QuranData quran;
  late OfflineAthkar athkar;

  setUpAll(() async {
    search = await OfflineQuranSearch.load();
    quran = await QuranData.load();
    athkar = await OfflineAthkar.load();
  });

  List<Map<String, dynamic>> versesFor(String query, {int limit = 20}) =>
      ((search.search(query, limit: limit)['verses'] as Map)['hits'] as List)
          .cast<Map<String, dynamic>>();

  test('matching verse keeps the bundled text and navigable reference', () {
    final ayah = quran.ayah('1:1')!;
    final hits = versesFor(ayah['text'] as String);
    final matching = hits.firstWhere((verse) => verse['key'] == ayah['key']);
    expect(matching['text'], ayah['text']);
    expect(matching['number'], ayah['number']);
    expect(matching['page'], ayah['page']);
    expect(matching['surahNameAr'], quran.surahs.first['nameAr']);
  });

  test('diacritics and letter variants match the same Quran verse', () {
    final original = quran.ayah('1:1')!['text'] as String;
    final plain = normalizeArabic(original);
    expect(plain, isNot(original));
    expect(versesFor(plain).map((verse) => verse['key']), contains('1:1'));
    final variant = plain.replaceFirst('ا', 'أ');
    expect(variant, isNot(plain));
    expect(versesFor(variant).map((verse) => verse['key']), contains('1:1'));
  });

  test('athkar matches include the original text and its category', () {
    final morning = athkar.category('morning')!;
    final dhikr = (morning['items'] as List).first as Map<String, dynamic>;
    final matches = (search.search(dhikr['text'] as String)['athkar'] as List)
        .cast<Map<String, dynamic>>();
    final matching = matches.firstWhere((hit) => hit['id'] == dhikr['id']);
    expect(matching['text'], dhikr['text']);
    expect(matching['category']['nameAr'], morning['nameAr']);
  });

  test('empty and unmatched queries do not claim a religious answer', () {
    for (final query in ['  ', 'zzzzunmatchedzzzz']) {
      final matches = search.search(query);
      expect(matches['surahs'], isEmpty);
      expect((matches['verses'] as Map)['hits'], isEmpty);
      expect(matches['athkar'], isEmpty);
    }
    final response = search.assistantResponse('zzzzunmatchedzzzz');
    expect(response['answer'], contains('لا توجد نتائج'));
    expect(response['disclaimer'], contains('ليس فتوى'));
    expect(response['mode'], isNot('ai'));
  });

  test('the result cap applies across sources', () {
    final matches = search.search('الله', limit: 3);
    final total =
        (matches['surahs'] as List).length +
        ((matches['verses'] as Map)['hits'] as List).length +
        (matches['athkar'] as List).length;
    expect(total, 3);
    expect(versesFor('الله', limit: 0), isEmpty);
  });
}
