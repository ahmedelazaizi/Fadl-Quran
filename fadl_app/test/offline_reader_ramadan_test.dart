import 'dart:convert';
import 'dart:io';

import 'package:fadl/core/local_user_data.dart';
import 'package:fadl/core/offline_athkar.dart';
import 'package:fadl/core/offline_prayer.dart';
import 'package:fadl/core/offline_tafsir.dart';
import 'package:fadl/core/quran_data.dart';
import 'package:fadl/screens/prayer/ramadan_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'downloaded tafsir maps keys to the reader shape without invented text',
    () async {
      final root = await Directory.systemTemp.createTemp('reader_tafsir');
      try {
        final directory = Directory('${root.path}/tafsir')..createSync();
        File('${directory.path}/ar.jalalayn.json').writeAsStringSync(
          jsonEncode({
            'slug': 'ar.jalalayn',
            'surahs': [
              <String>[''],
            ],
          }),
        );
        final tafsir = OfflineTafsir(root: () async => root);
        expect(await tafsir.ayahTafsir('1:1', 'ar.muyassar'), isNull);
        final result = await tafsir.ayahTafsir('1:1', 'ar.jalalayn');
        expect(result, {
          'ayahKey': '1:1',
          'edition': {'slug': 'ar.jalalayn', 'nameAr': 'تفسير الجلالين'},
          'text': null,
          'source': 'OFFLINE',
        });
        expect(
          await tafsir.ayahTafsir('1:2', 'ar.jalalayn'),
          containsPair('text', null),
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'local bookmarks survive a new store instance and can be deleted',
    () async {
      final first = LocalUserData(clock: () => DateTime.utc(2024, 3, 15));
      await first.addBookmark('2:255');
      await first.addBookmark('1:1');
      final second = LocalUserData();
      expect((await second.bookmarks()).map((b) => b['ayahKey']), [
        '1:1',
        '2:255',
      ]);
      expect(await second.isBookmarked('2:255'), isTrue);
      await second.removeBookmark('2:255');
      expect(await first.isBookmarked('2:255'), isFalse);
    },
  );

  test('Ramadan days have the reader table and today shapes', () {
    final date = List.generate(45, (i) => DateTime.utc(2024, 3, 1 + i))
        .firstWhere(
          (d) =>
              OfflinePrayer.hijri(d)['month'] == 9 &&
              OfflinePrayer.hijri(d)['day'] == 5,
        );
    final data = localRamadanImsakiya({
      'latitude': 21.4225,
      'longitude': 39.8262,
      'timezone': 'Asia/Riyadh',
    }, date.add(const Duration(hours: 12)))!;
    final days = (data['days'] as List).cast<Map<String, dynamic>>();
    expect(days.length, anyOf(29, 30));
    expect(days.first['ramadanDay'], 1);
    expect(days[4]['ramadanDay'], 5);
    for (final d in days) {
      for (final key in ['imsak', 'fajr', 'maghrib', 'isha']) {
        expect(d[key], matches(RegExp(r'^\d{2}:\d{2}$')));
      }
    }
    final today = data['today'] as Map;
    expect(today['ramadanDay'], 5);
    expect(today['iftar'], days[4]['maghrib']);
    expect(today['tomorrowImsak'], days[5]['imsak']);
    expect(
      localRamadanImsakiya({
        'timezone': 'Asia/Riyadh',
      }, DateTime.utc(2024, 1, 1)),
      isNull,
    );
    expect(
      localRamadanImsakiya({'timezone': 'Asia/Riyadh'}, DateTime.utc(2300)),
      isNull,
    );
  });

  test(
    'Ramadan duas use the bundled collection and local dedication persists',
    () async {
      final collection = (await OfflineAthkar.load()).duaCollection(
        'ramadan',
        await QuranData.load(),
      )!;
      expect(collection['nameAr'], 'أدعية رمضان والصيام');
      expect((collection['items'] as List), isNotEmpty);
      await OfflineAthkarStore.dedicate('READING', amount: 2);
      final stats = await OfflineAthkarStore.dedicationStats();
      expect(stats['totalDedications'], 1);
      expect((stats['byType'] as Map)['READING'], {'count': 1, 'amount': 2});
    },
  );
}
