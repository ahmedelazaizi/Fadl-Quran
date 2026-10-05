import 'dart:convert';
import 'dart:math';

import 'package:fadl/core/quran_data.dart';
import 'package:fadl/core/quran_learning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranData quran;
  late QuranQuizGenerator generator;

  setUpAll(() async {
    quran = await QuranData.load();
    generator = QuranQuizGenerator(quran);
  });

  test('hide next ayah reveals the canonical following ayah', () {
    final quiz = generator.generate(1, QuranQuizMode.hideNextAyah);
    expect(quiz.ayahs.map((ayah) => ayah.key), ['1:1', '1:2']);
    expect(quiz.prompt, quran.ayah('1:1')!['text']);
    expect(quiz.answer, quran.ayah('1:2')!['text']);
    expect(
      generator.generate(604, QuranQuizMode.hideNextAyah).ayahs,
      hasLength(2),
    );
  });

  test('masked words repeat for a seed and leave source text unchanged', () {
    final original = quran.ayah('1:1')!['text'] as String;
    final first = generator.generate(
      1,
      QuranQuizMode.maskedWords,
      random: Random(17),
    );
    final again = generator.generate(
      1,
      QuranQuizMode.maskedWords,
      random: Random(17),
    );
    expect(first.prompt, again.prompt);
    expect(first.prompt, contains('ـــ'));
    expect(first.prompt, isNot(original));
    expect(first.answer, original);
    expect(
      first.prompt.split(RegExp(r'\s+')).length,
      original.split(RegExp(r'\s+')).length,
    );
    expect(quran.ayah('1:1')!['text'], original);
  });

  test('order quiz shuffles unique keys and validates reordered keys', () {
    final quiz = generator.generate(1, QuranQuizMode.orderAyahs);
    final shuffled = quiz.shuffled(Random(31));
    expect(
      shuffled.map((ayah) => ayah.key).toList(),
      quiz.shuffled(Random(31)).map((ayah) => ayah.key).toList(),
    );
    expect(
      shuffled.map((ayah) => ayah.key).toSet(),
      quiz.ayahs.map((ayah) => ayah.key).toSet(),
    );
    expect(
      shuffled.map((ayah) => ayah.key),
      isNot(quiz.ayahs.map((ayah) => ayah.key)),
    );
    expect(
      quiz.isCorrectOrder(shuffled.map((ayah) => ayah.key).toList()),
      isFalse,
    );
    expect(
      quiz.isCorrectOrder(quiz.ayahs.map((ayah) => ayah.key).toList()),
      isTrue,
    );
    expect(quiz.isCorrectOrder(['1:1', '1:1', '1:2', '1:3']), isFalse);
  });

  test(
    'high quality grows intervals while failed recall resets repetition',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = QuranReviewStore(await SharedPreferences.getInstance())
        ..load();
      final now = DateTime.utc(2026, 2, 1);
      final first = await store.record(1, 5, now);
      expect([first.quality, first.repetitions, first.intervalDays], [5, 1, 1]);
      expect(first.due, now.add(const Duration(days: 1)));
      expect(store.dueCount(now), 0);
      final second = await store.record(1, 5, first.due);
      expect([second.repetitions, second.intervalDays], [2, 6]);
      final third = await store.record(1, 5, second.due);
      expect(third.repetitions, 3);
      expect(third.intervalDays, greaterThan(6));
      final failed = await store.record(1, 1, third.due);
      expect(
        [failed.quality, failed.repetitions, failed.intervalDays],
        [1, 0, 1],
      );
      expect(failed.due, third.due.add(const Duration(days: 1)));
      expect(store.dueCount(failed.due), 1);
      expect(failed.ease, lessThan(third.ease));
    },
  );

  test(
    'local records survive reload and reject invalid pages and ratings',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = QuranReviewStore(prefs)..load();
      final now = DateTime.utc(2026, 3, 1);
      await store.record(604, 4, now);
      final loaded = QuranReviewStore(prefs)..load();
      expect(loaded.review(604)!.quality, 4);
      expect(loaded.review(604)!.due, now.add(const Duration(days: 1)));
      expect(() => loaded.review(0), throwsRangeError);
      await expectLater(loaded.record(605, 4, now), throwsRangeError);
      await expectLater(loaded.record(1, 6, now), throwsRangeError);
      expect(loaded.review(1), isNull);
    },
  );

  test(
    'malformed storage skips broken records but preserves valid pages',
    () async {
      final now = DateTime.utc(2026, 3, 1);
      SharedPreferences.setMockInitialValues({
        QuranReviewStore.preferenceKey: jsonEncode({
          '1': [5, 1, 1, 2.6, now.millisecondsSinceEpoch],
          '2': [7, 1, 1, 2.5, now.millisecondsSinceEpoch],
          '700': [5, 1, 1, 2.5, now.millisecondsSinceEpoch],
          '3': 'broken',
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final store = QuranReviewStore(prefs)..load();
      expect(store.review(1)!.quality, 5);
      expect(store.review(2), isNull);
      expect(store.review(3), isNull);
      expect(store.dueCount(now), 1);
      await prefs.setString(QuranReviewStore.preferenceKey, '{broken');
      store.load();
      expect(store.review(1), isNull);
    },
  );
}
