import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'quran_data.dart';

enum QuranQuizMode { hideNextAyah, maskedWords, orderAyahs }

class QuizAyah {
  const QuizAyah(this.key, this.text);
  final String key;
  final String text;
}

class QuranQuiz {
  const QuranQuiz({
    required this.mode,
    required this.ayahs,
    required this.prompt,
    required this.answer,
  });

  final QuranQuizMode mode;
  // The source ayahs always remain unmodified and in canonical order.
  final List<QuizAyah> ayahs;
  final String prompt;
  final String answer;

  List<QuizAyah> shuffled(Random random) {
    final shuffled = [...ayahs]..shuffle(random);
    if (shuffled.length > 1 &&
        shuffled.indexed.every(
          (entry) => entry.$2.key == ayahs[entry.$1].key,
        )) {
      final first = shuffled.removeAt(0);
      shuffled.add(first);
    }
    return shuffled;
  }

  bool isCorrectOrder(List<String> keys) =>
      keys.length == ayahs.length &&
      keys.indexed.every((entry) => entry.$2 == ayahs[entry.$1].key);
}

class QuranQuizGenerator {
  QuranQuizGenerator(this.quran);
  final QuranData quran;

  QuranQuiz generate(int page, QuranQuizMode mode, {Random? random}) {
    final pageAyahs = (quran.page(page)['ayahs'] as List)
        .cast<Map<String, dynamic>>();
    final first = pageAyahs.first;
    final firstAyah = QuizAyah(first['key'] as String, first['text'] as String);
    if (mode == QuranQuizMode.maskedWords) {
      final text = firstAyah.text;
      final words = RegExp(r'\S+').allMatches(text).toList();
      final picks = List.generate(words.length, (index) => index)
        ..shuffle(random ?? Random());
      final hidden = picks.take(max(1, (words.length / 3).ceil())).toSet();
      var wordIndex = 0;
      final masked = text.replaceAllMapped(RegExp(r'\S+'), (match) {
        return hidden.contains(wordIndex++) ? 'ـــ' : match.group(0)!;
      });
      return QuranQuiz(
        mode: mode,
        ayahs: [firstAyah],
        prompt: masked,
        answer: text,
      );
    }
    if (mode == QuranQuizMode.hideNextAyah) {
      final next = quran.globalAyah((first['id'] as int) + 1)!;
      return QuranQuiz(
        mode: mode,
        ayahs: [
          firstAyah,
          QuizAyah(next['key'] as String, next['text'] as String),
        ],
        prompt: firstAyah.text,
        answer: next['text'] as String,
      );
    }
    final group = pageAyahs
        .take(4)
        .map((ayah) => QuizAyah(ayah['key'] as String, ayah['text'] as String))
        .toList();
    // A page with one ayah still needs a second card to reorder.
    if (group.length == 1) {
      final next = quran.globalAyah((first['id'] as int) + 1);
      final neighbor = next ?? quran.globalAyah((first['id'] as int) - 1)!;
      final extra = QuizAyah(
        neighbor['key'] as String,
        neighbor['text'] as String,
      );
      if (next == null) {
        group.insert(0, extra);
      } else {
        group.add(extra);
      }
    }
    return QuranQuiz(mode: mode, ayahs: group, prompt: '', answer: '');
  }
}

class PageReview {
  const PageReview({
    required this.quality,
    required this.repetitions,
    required this.intervalDays,
    required this.ease,
    required this.due,
  });
  final int quality;
  final int repetitions;
  final int intervalDays;
  final double ease;
  final DateTime due;

  bool isDue(DateTime now) => !due.isAfter(now);

  PageReview rate(int rating, DateTime now) {
    validateRating(rating);
    final nextEase = max(
      1.3,
      ease + 0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02),
    );
    final nextRepetitions = rating < 3 ? 0 : repetitions + 1;
    final days = rating < 3
        ? 1
        : nextRepetitions == 1
        ? 1
        : nextRepetitions == 2
        ? 6
        : max(1, (intervalDays * nextEase).round());
    return PageReview(
      quality: rating,
      repetitions: nextRepetitions,
      intervalDays: days,
      ease: nextEase,
      due: now.add(Duration(days: days)),
    );
  }

  List<Object> toRow() => [
    quality,
    repetitions,
    intervalDays,
    ease,
    due.millisecondsSinceEpoch,
  ];

  static PageReview? fromRow(Object? row) {
    if (row is! List ||
        row.length != 5 ||
        row[0] is! int ||
        row[1] is! int ||
        row[2] is! int ||
        row[3] is! num ||
        row[4] is! int) {
      return null;
    }
    final quality = row[0] as int;
    final repetitions = row[1] as int;
    final interval = row[2] as int;
    final ease = (row[3] as num).toDouble();
    final millis = row[4] as int;
    if (quality < 0 ||
        quality > 5 ||
        repetitions < 0 ||
        interval < 1 ||
        !ease.isFinite ||
        ease < 1.3 ||
        millis < 0 ||
        millis > 8640000000000000) {
      return null;
    }
    return PageReview(
      quality: quality,
      repetitions: repetitions,
      intervalDays: interval,
      ease: ease,
      due: DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
    );
  }
}

void validateRating(int rating) {
  if (rating < 0 || rating > 5) throw RangeError.range(rating, 0, 5);
}

class QuranReviewStore {
  QuranReviewStore(this.preferences);
  static const preferenceKey = 'fadl.quran.pageReviews.v1';
  final SharedPreferences preferences;
  final Map<int, PageReview> _reviews = {};

  void load() {
    _reviews.clear();
    final raw = preferences.getString(preferenceKey);
    if (raw == null) return;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    for (final entry in decoded.entries) {
      final page = int.tryParse(entry.key.toString());
      final review = PageReview.fromRow(entry.value);
      if (page != null && page >= 1 && page <= 604 && review != null) {
        _reviews[page] = review;
      }
    }
  }

  PageReview? review(int page) {
    _validatePage(page);
    return _reviews[page];
  }

  int dueCount(DateTime now) =>
      _reviews.values.where((review) => review.isDue(now)).length;

  Future<PageReview> record(int page, int rating, DateTime now) async {
    _validatePage(page);
    validateRating(rating);
    final previous =
        _reviews[page] ??
        PageReview(
          quality: 0,
          repetitions: 0,
          intervalDays: 1,
          ease: 2.5,
          due: now,
        );
    final updated = previous.rate(rating, now);
    _reviews[page] = updated;
    await preferences.setString(
      preferenceKey,
      jsonEncode({
        for (final entry in _reviews.entries)
          '${entry.key}': entry.value.toRow(),
      }),
    );
    return updated;
  }

  void _validatePage(int page) {
    if (page < 1 || page > 604) throw RangeError.range(page, 1, 604);
  }
}
