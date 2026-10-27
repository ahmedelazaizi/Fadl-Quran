import 'package:fadl/core/mushaf_layout.dart';
import 'package:fadl/core/quran_data.dart';
import 'package:fadl/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _ignoredFormattingCodePoints = {
  0x061C, // Arabic Letter Mark.
  0x200C, // Zero Width Non-Joiner.
  0x200D, // Zero Width Joiner.
  0x200E, // Left-to-Right Mark.
  0x200F, // Right-to-Left Mark.
  0x202A, 0x202B, 0x202C, 0x202D, 0x202E, // Bidi embedding/overrides.
  0x2060, 0x2061, 0x2062, 0x2063, 0x2064, 0x2066, 0x2067, 0x2068, 0x2069,
  0xFE00, 0xFE01, 0xFE02, 0xFE03, 0xFE04, 0xFE05, 0xFE06, 0xFE07,
  0xFE08, 0xFE09, 0xFE0A, 0xFE0B, 0xFE0C, 0xFE0D, 0xFE0E, 0xFE0F,
};

int _u16(Uint8List bytes, int offset) =>
    (bytes[offset] << 8) | bytes[offset + 1];

int _s16(Uint8List bytes, int offset) {
  final value = _u16(bytes, offset);
  return value & 0x8000 == 0 ? value : value - 0x10000;
}

int _u32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

List<Uint8List> _cmapSubtables(Uint8List bytes) {
  var cmapOffset = -1;
  final tableCount = _u16(bytes, 4);
  for (var index = 0; index < tableCount; index++) {
    final record = 12 + index * 16;
    if (String.fromCharCodes(bytes.sublist(record, record + 4)) == 'cmap') {
      cmapOffset = _u32(bytes, record + 8);
      break;
    }
  }
  expect(cmapOffset, greaterThanOrEqualTo(0), reason: 'font cmap table');
  final encodingCount = _u16(bytes, cmapOffset + 2);
  final subtables = <Uint8List>[];
  for (var index = 0; index < encodingCount; index++) {
    final record = cmapOffset + 4 + index * 8;
    final offset = cmapOffset + _u32(bytes, record + 4);
    final format = _u16(bytes, offset);
    if (format == 4 || format == 12) {
      subtables.add(bytes.sublist(offset));
    }
  }
  expect(subtables, isNotEmpty, reason: 'font cmap format 4/12');
  return subtables;
}

bool _subtableContains(Uint8List table, int codePoint) {
  final format = _u16(table, 0);
  if (format == 12) {
    final groups = _u32(table, 12);
    for (var index = 0; index < groups; index++) {
      final group = 16 + index * 12;
      final start = _u32(table, group);
      final end = _u32(table, group + 4);
      if (codePoint >= start && codePoint <= end) return true;
    }
    return false;
  }
  final segmentCount = _u16(table, 6) ~/ 2;
  final endCodes = 14;
  final startCodes = endCodes + segmentCount * 2 + 2;
  final deltas = startCodes + segmentCount * 2;
  final rangeOffsets = deltas + segmentCount * 2;
  for (var index = 0; index < segmentCount; index++) {
    final end = _u16(table, endCodes + index * 2);
    if (codePoint > end) continue;
    final start = _u16(table, startCodes + index * 2);
    if (codePoint < start || codePoint > 0xFFFF) return false;
    final rangeOffset = _u16(table, rangeOffsets + index * 2);
    if (rangeOffset == 0) {
      return ((codePoint + _s16(table, deltas + index * 2)) & 0xFFFF) != 0;
    }
    final glyphOffset =
        rangeOffsets + index * 2 + rangeOffset + (codePoint - start) * 2;
    return glyphOffset + 1 < table.length && _u16(table, glyphOffset) != 0;
  }
  return false;
}

bool _cmapContains(List<Uint8List> subtables, int codePoint) =>
    subtables.any((table) => _subtableContains(table, codePoint));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final madinah = await rootBundle.load('assets/fonts/Al-Madinah.ttf');
    final amiri = await rootBundle.load('assets/fonts/AmiriQuran.ttf');
    await (FontLoader('AlMadinah')..addFont(Future.value(madinah))).load();
    await (FontLoader('AmiriQuran')..addFont(Future.value(amiri))).load();
  });

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

  test('Al-Madinah cmap covers every Mushaf code point on all pages', () async {
    final madinahFont = await rootBundle.load('assets/fonts/Al-Madinah.ttf');
    final amiriFont = await rootBundle.load('assets/fonts/AmiriQuran.ttf');
    final madinahBytes = madinahFont.buffer.asUint8List(
      madinahFont.offsetInBytes,
      madinahFont.lengthInBytes,
    );
    final amiriBytes = amiriFont.buffer.asUint8List(
      amiriFont.offsetInBytes,
      amiriFont.lengthInBytes,
    );
    final madinahCmap = _cmapSubtables(madinahBytes);
    final amiriCmap = _cmapSubtables(amiriBytes);
    final quran = await QuranData.load();
    final codePoints = <int>{};
    const basmala = 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ';
    codePoints.addAll(basmala.runes);
    for (var page = 1; page <= 604; page++) {
      final pageData = quran.page(page);
      for (final surah
          in (pageData['surahs'] as List).cast<Map<String, dynamic>>()) {
        codePoints.addAll((surah['nameAr'] as String).runes);
      }
      for (final ayah
          in (pageData['ayahs'] as List).cast<Map<String, dynamic>>()) {
        codePoints.addAll((ayah['text'] as String).runes);
        codePoints.addAll(ayahMarker(ayah['number'] as int).runes);
      }
    }

    final primaryMissing = {
      for (final codePoint in codePoints)
        if (!_ignoredFormattingCodePoints.contains(codePoint) &&
            !_cmapContains(madinahCmap, codePoint))
          codePoint,
    };
    expect(primaryMissing, {0x06EA, 0x06EB});
    final fallbackMissing = {
      for (final codePoint in primaryMissing)
        if (!_cmapContains(amiriCmap, codePoint)) codePoint,
    };
    expect(fallbackMissing, isEmpty, reason: 'AmiriQuran cmap fallback');
  });

  test('Al-Madinah renders every printed line within the page width', () async {
    final layout = await MushafLayout.load();
    final quran = await QuranData.load();
    const pageWidth = 406.0;
    const style = TextStyle(
      fontFamily: 'AlMadinah',
      fontFamilyFallback: ['AmiriQuran'],
      fontSize: 18,
    );
    final painter = TextPainter(textDirection: TextDirection.rtl);
    addTearDown(painter.dispose);

    for (var page = 1; page <= 604; page++) {
      final lines = layout.lines(page);
      for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        final line = lines[lineIndex];
        if (line.surahId != null || line.isBasmala) continue;
        var naturalWidth = 0.0;
        for (final token in line.tokens) {
          final text = token.isEnd
              ? ayahMarker(
                  (quran.page(page)['ayahs'] as List)
                          .cast<Map<String, dynamic>>()
                          .firstWhere(
                            (ayah) => ayah['key'] == token.ayahKey,
                          )['number']
                      as int,
                )
              : token.text!;
          expect(
            text,
            isNot(contains('\uFFFD')),
            reason: 'page $page line ${lineIndex + 1}',
          );
          expect(
            text,
            isNot(contains('\u25A1')),
            reason: 'page $page line ${lineIndex + 1}',
          );
          painter.text = TextSpan(text: text, style: style);
          painter.layout();
          expect(
            painter.width,
            greaterThan(0),
            reason: 'page $page line ${lineIndex + 1}',
          );
          expect(
            painter.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: text.length),
            ),
            isNotEmpty,
            reason: 'page $page line ${lineIndex + 1}',
          );
          naturalWidth += painter.width;
        }
        final widthWithReducedGaps =
            naturalWidth + (line.tokens.length - 1).clamp(0, 100) * 4;
        expect(
          widthWithReducedGaps,
          lessThanOrEqualTo(pageWidth),
          reason: 'page $page line ${lineIndex + 1}',
        );
      }
    }
  });

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
