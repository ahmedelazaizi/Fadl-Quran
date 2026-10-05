import 'dart:async';

import 'package:fadl/widgets/live_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('typing waits for debounce and ignores an older response', (
    tester,
  ) async {
    final older = Completer<List<LiveSearchSuggestion<String>>>();
    final newer = Completer<List<LiveSearchSuggestion<String>>>();
    final queries = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveSearch<String>(
            hintText: 'بحث',
            search: (query) {
              queries.add(query);
              return query == 'قديم' ? older.future : newer.future;
            },
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'قديم');
    await tester.pump(const Duration(milliseconds: 299));
    expect(queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(queries, ['قديم']);
    await tester.enterText(find.byType(TextField), 'جديد');
    await tester.pump(const Duration(milliseconds: 300));
    newer.complete([const LiveSearchSuggestion('new', 'نتيجة جديدة')]);
    await tester.pump();
    older.complete([const LiveSearchSuggestion('old', 'نتيجة قديمة')]);
    await tester.pump();
    expect(find.text('نتيجة جديدة'), findsOneWidget);
    expect(find.text('نتيجة قديمة'), findsNothing);
  });

  testWidgets(
    'clear removes suggestions and keyboard enter submits immediately',
    (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveSearch<String>(
              hintText: 'بحث',
              search: (q) async => [LiveSearchSuggestion(q, 'مطابقة')],
              onSelected: (_) {},
              onSubmitted: submitted.add,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'اختبار');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(submitted, ['اختبار']);
      expect(find.text('مطابقة'), findsOneWidget);
      await tester.tap(find.byTooltip('مسح'));
      await tester.pump();
      expect(find.text('مطابقة'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  test('Arabic normalization and Quranic prayer spelling match', () {
    expect(matchesLiveSearch('الصَّلَوٰة', 'الصلاة'), isTrue);
    expect(matchesLiveSearch('الصلاة', 'الصلوة'), isTrue);
    expect(matchesLiveSearch('الرَّحْمَة', 'الرحمه'), isTrue);
  });

  test('surah lookup matches unvowelled Arabic names and pages', () {
    final surah = <String, dynamic>{
      'id': 1,
      'nameAr': 'الْفَاتِحَة',
      'nameTranslit': 'Al-Fatiha',
      'startPage': 1,
    };
    expect(matchesSurahSearch(surah, 'الفاتحه'), isTrue);
    expect(matchesSurahSearch(surah, '١'), isTrue);
    expect(matchesSurahSearch(surah, 'فَاتِحَة'), isTrue);
  });
}
