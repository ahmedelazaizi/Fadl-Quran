import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/full_surah_reciters.dart';
import 'package:fadl/screens/quran/audio_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  final arabic = <String, dynamic>{
    'reciters': [
      {
        'id': 12,
        'name': 'إدريس أبكر',
        'moshaf': [
          {
            'id': 12,
            'name': 'حفص عن عاصم - مرتل',
            'server': 'https://cdn.mp3quran.net/audio/idrees-abkar/r1/',
            'surah_list': '1,2,114',
          },
          {
            'id': 13,
            'name': 'ورش عن نافع - مرتل',
            'server': 'https://cdn.mp3quran.net/audio/idrees-abkar/r2/',
            'surah_list': '1,114',
          },
          {
            'id': 12,
            'name': 'حفص عن عاصم - مرتل',
            'server': 'https://cdn.mp3quran.net/audio/idrees-abkar/r1/',
            'surah_list': '1,2,114',
          },
        ],
      },
      {
        'id': 99,
        'name': 'قارئ آخر',
        'moshaf': [
          {
            'id': 14,
            'name': 'حفص',
            'server': 'https://elsewhere.example/audio/',
            'surah_list': '1',
          },
        ],
      },
    ],
  };
  final english = <String, dynamic>{
    'reciters': [
      {'id': 12, 'name': 'Idrees Abkar'},
    ],
  };

  test(
    'parses distinct reciter-edition pairs and excludes foreign servers',
    () {
      final editions = parseFullSurahReciters(arabic, english);
      expect(editions, hasLength(2));
      expect(
        editions.map((e) => (e.reciterId, e.editionId)).toSet(),
        hasLength(2),
      );
      expect(
        editions.map((e) => e.editionName),
        contains('ورش عن نافع - مرتل'),
      );
    },
  );

  test('matches Arabic spelling variants and Latin reciter names', () {
    final edition = parseFullSurahReciters(arabic, english).first;
    expect(edition.matches('ادريس ابكر'), isTrue);
    expect(edition.matches('IDREES ABKAR'), isTrue);
    expect(
      parseFullSurahReciters(arabic).first.matches('idrees abkar'),
      isTrue,
    );
    expect(edition.matches('السديس'), isFalse);
  });

  test('constructs only listed surah URLs using zero-padded numbers', () {
    final edition = parseFullSurahReciters(arabic).first;
    expect(
      edition.urlForSurah(2),
      'https://cdn.mp3quran.net/audio/idrees-abkar/r1/002.mp3',
    );
    expect(
      edition.urlForSurah(114),
      'https://cdn.mp3quran.net/audio/idrees-abkar/r1/114.mp3',
    );
    expect(edition.urlForSurah(3), isNull);
    expect(edition.urlForSurah(0), isNull);
  });

  testWidgets('library labels full-surah mode without automatic ayah sync', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(home: AudioLibraryScreen()),
      ),
    );
    expect(find.text(fullSurahModeLabel), findsOneWidget);
    expect(find.text('تلاوة آية بآية — مزامنة الآيات'), findsOneWidget);
  });
}
