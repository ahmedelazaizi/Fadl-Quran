import 'package:fadl/core/mushaf_layout.dart';
import 'package:fadl/core/quran_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all printed line slots preserve QuranData ayahs and their order',
    () async {
      final layout = await MushafLayout.load();
      final quran = await QuranData.load();
      expect(layout.pageCount, 604);
      for (var page = 1; page <= 604; page++) {
        final lines = layout.lines(page);
        expect(lines, hasLength(15), reason: 'page $page');
        for (var index = 0; index < lines.length; index++) {
          final line = lines[index];
          if (line.surahId == null && !line.isBasmala) {
            expect(
              line.tokens.length,
              lessThanOrEqualTo(20),
              reason: 'page $page line ${index + 1}',
            );
          }
        }
        final tokens = lines.expand((line) => line.tokens).toList();
        final ayahs = (quran.page(page)['ayahs'] as List)
            .cast<Map<String, dynamic>>();
        final expected = ayahs.map((ayah) => ayah['key'] as String).toList();
        final keys = tokens.map((token) => token.ayahKey).toSet();
        expect(keys, expected.toSet(), reason: 'page $page keys');
        expect(
          tokens.where((token) => token.isEnd).map((token) => token.ayahKey),
          expected,
          reason: 'page $page end markers',
        );
        final firstAppearance = <String>[];
        for (final token in tokens) {
          if (!firstAppearance.contains(token.ayahKey)) {
            firstAppearance.add(token.ayahKey);
          }
        }
        expect(firstAppearance, expected, reason: 'page $page token order');
      }
    },
  );

  test('previously squeezed lines on pages 121, 595 and 598 fit', () async {
    final layout = await MushafLayout.load();
    for (final (page, line) in [(121, 1), (595, 15), (598, 15)]) {
      expect(
        layout.lines(page)[line - 1].tokens.length,
        lessThanOrEqualTo(20),
        reason: 'page $page line $line',
      );
    }
  });
}
