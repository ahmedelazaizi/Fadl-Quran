import 'dart:convert';
import 'dart:io';

import 'package:fadl/core/athkar_repeats.dart';
import 'package:fadl/core/offline_athkar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final asset =
      jsonDecode(File('assets/athkar/azkar.json').readAsStringSync()) as Map;
  final columns = (asset['columns'] as List).cast<String>();
  final rows = (asset['rows'] as List).cast<List>();
  final textColumn = columns.indexOf('zekr');
  final countColumn = columns.indexOf('count');
  final uncounted = [
    for (final row in rows)
      if (row[countColumn] is! int || (row[countColumn] as int) < 1)
        normalizeArabic(row[textColumn] as String),
  ];

  test('every stated count names exactly one uncounted dhikr', () {
    for (final (phrase, repeat) in athkarStatedRepeats) {
      final key = normalizeArabic(phrase);
      expect(
        uncounted.where((text) => text.contains(key)),
        hasLength(1),
        reason: phrase,
      );
      expect(repeat, greaterThan(1), reason: phrase);
    }
  });

  test('the loaded athkar use the counts their texts state', () async {
    final athkar = await OfflineAthkar.load();
    int repeatOf(String phrase) {
      final key = normalizeArabic(phrase);
      final matches = [
        for (var id = 1; athkar.dhikr(id) != null; id++)
          if (normalizeArabic(
            athkar.dhikr(id)!['text'] as String,
          ).contains(key))
            athkar.dhikr(id)!,
      ];
      // Morning and evening share some adhkar: every copy counts the same.
      final repeats = {for (final m in matches) m['repeat'] as int};
      expect(repeats, hasLength(1), reason: phrase);
      return repeats.single;
    }

    expect(repeatOf('أكثر من سبعين مرة'), 70);
    expect(repeatOf('سبحان الله وبحمده في يوم مائة مرة'), 100);
    expect(repeatOf('سبحان ربي العظيم'), 3);
    expect(repeatOf('والله أكبر (أربعا وثلاثين)'), 100);
    // Counts given by the data are kept.
    expect(repeatOf('رضيت بالله ربا وبالإسلام دينا'), 3);
    // A text that writes out its own repetitions stays a single count.
    expect(repeatOf('والحمد لله كثيرا، والحمد لله كثيرا'), 1);
  });

  test('the counter starts again after each finished round', () {
    expect(
      [for (var c = 0; c <= 7; c++) athkarRoundDone(c, 3)],
      [false, false, false, true, false, false, true, false],
    );
    expect(athkarRoundDone(5, 1), isTrue);
  });
}
