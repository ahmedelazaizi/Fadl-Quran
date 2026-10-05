import 'package:fadl/core/quran_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuranData quran;

  setUpAll(() async {
    quran = await QuranData.load();
  });

  List<Map<String, dynamic>> pageAyahs(int page) =>
      (quran.page(page)['ayahs'] as List).cast<Map<String, dynamic>>();

  test('bundled mushaf has 114 surahs and 6236 ayahs', () {
    expect(quran.surahs, hasLength(114));
    var total = 0;
    for (var id = 1; id <= 114; id++) {
      final ayahs = quran.surahAyahs(id);
      expect(ayahs, hasLength(quran.surahs[id - 1]['ayahCount']));
      expect(ayahs.map((a) => a['number']), [
        for (var n = 1; n <= ayahs.length; n++) n,
      ]);
      total += ayahs.length;
    }
    expect(total, 6236);
  });

  test('every page from 1 to 604 has ayahs and keys are unique', () {
    final keys = <String>{};
    var total = 0;
    for (var page = 1; page <= 604; page++) {
      final ayahs = pageAyahs(page);
      expect(ayahs, isNotEmpty, reason: 'page $page');
      for (final ayah in ayahs) {
        expect(keys.add(ayah['key'] as String), isTrue, reason: ayah['key']);
      }
      total += ayahs.length;
    }
    expect(total, 6236);
    expect(() => quran.page(0), throwsRangeError);
    expect(() => quran.page(605), throwsRangeError);
  });

  test('first and last pages hold the expected ayahs', () {
    expect(pageAyahs(1).map((a) => a['key']), [
      for (var n = 1; n <= 7; n++) '1:$n',
    ]);
    expect(pageAyahs(604).last['key'], '114:6');
  });

  test('navigation metadata matches the Madani mushaf', () {
    expect(quran.juzStartPage(1), 1);
    expect(quran.juzStartPage(30), 582);
    expect(quran.surahs[1]['nameAr'], 'البقرة');
    expect(quran.surahs[1]['startPage'], 2);
    expect(quran.globalAyah(8)?['key'], '2:1');
    expect(quran.ayah('2:255')?['page'], 42);
  });

  test('ayah text is normalized like the server seed', () {
    final fatiha = quran.ayah('1:1')!['text'] as String;
    expect(fatiha, isNot(contains('\uFEFF')));
    expect(fatiha, startsWith('بِسْمِ'));
    final baqarah = quran.ayah('2:1')!['text'] as String;
    expect(baqarah, isNot(startsWith('بِسْمِ')));
  });
}
