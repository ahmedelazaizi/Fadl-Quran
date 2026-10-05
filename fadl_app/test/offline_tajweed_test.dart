import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fadl/core/offline_tajweed.dart';

List<int> response(List<Map<String, String>> verses) =>
    utf8.encode(jsonEncode({'verses': verses}));

Map<String, String> verse(String key, String markup) => {
  'verse_key': key,
  'text_uthmani_tajweed': markup,
};

void main() {
  test('tagged fragments preserve text and remove only the end marker', () {
    final pieces = parseTajweedMarkup(
      'X<tajweed class=ikhafa>Y</tajweed>Z <span class=end>1</span>',
    );
    expect(pieces.map((piece) => piece.text).join(), 'XYZ');
    expect(pieces.map((piece) => piece.rule), [null, 'ikhafa', null]);
    expect(tajweedColors['ikhafa'], isNotNull);
  });

  test('escaped characters are plain text and unknown tags are rejected', () {
    expect(
      parseTajweedMarkup(
        'X&amp;Y <span class=end>1</span>',
      ).map((piece) => piece.text).join(),
      'X&Y',
    );
    for (final markup in [
      'X<tajweed class=unknown>Y</tajweed> <span class=end>1</span>',
      'X<script>Y</script> <span class=end>1</span>',
      'X<tajweed class=ikhafa>Y <span class=end>1</span>',
    ]) {
      expect(() => parseTajweedMarkup(markup), throwsFormatException);
    }
  });

  test('complete unique keys and required text survive schema parsing', () {
    final verses = parseTajweedVerses(
      response([
        verse('1:1', 'X<span class=end>1</span>'),
        verse('1:2', 'Y<span class=end>2</span>'),
      ]),
      expectedCount: 2,
    );
    expect(verses.keys, ['1:1', '1:2']);
    expect(verses['1:2'], 'Y<span class=end>2</span>');
  });

  test('keys from surahs 109 and 114 pass but surah 115 fails', () {
    final accepted = parseTajweedVerses(
      response([
        verse('109:1', 'X<span class=end>1</span>'),
        verse('114:1', 'Y<span class=end>1</span>'),
      ]),
      expectedCount: 2,
    );
    expect(accepted.keys, ['109:1', '114:1']);
    expect(
      () => parseTajweedVerses(
        response([verse('115:1', 'X<span class=end>1</span>')]),
        expectedCount: 1,
      ),
      throwsFormatException,
    );
  });

  test('incomplete, duplicate and missing-text responses fail validation', () {
    final first = verse('1:1', 'X<span class=end>1</span>');
    expect(
      () => parseTajweedVerses(response([first]), expectedCount: 2),
      throwsFormatException,
    );
    expect(
      () => parseTajweedVerses(response([first, first]), expectedCount: 2),
      throwsFormatException,
    );
    expect(
      () => parseTajweedVerses(
        utf8.encode(
          jsonEncode({
            'verses': [
              {'verse_key': '1:1'},
            ],
          }),
        ),
        expectedCount: 1,
      ),
      throwsFormatException,
    );
  });
}
