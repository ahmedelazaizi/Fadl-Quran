import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>> fetchPage(
  HttpClient client,
  int page,
  String wordFields,
) async {
  final uri = Uri.https('api.quran.com', '/api/v4/verses/by_page/$page', {
    'words': 'true',
    'word_fields': wordFields,
    'per_page': '50',
    'mushaf': '1',
  });
  for (var attempt = 1; attempt <= 5; attempt++) {
    try {
      final response = await (await client.getUrl(
        uri,
      )).close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      return jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>;
    } on SocketException catch (error) {
      if (attempt == 5) rethrow;
      stderr.writeln('Page $page: $error; retry $attempt');
    } on HttpException catch (error) {
      if (attempt == 5) rethrow;
      stderr.writeln('Page $page: $error; retry $attempt');
    } on TimeoutException catch (error) {
      if (attempt == 5) rethrow;
      stderr.writeln('Page $page: $error; retry $attempt');
    }
    await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
  }
  throw StateError('Unreachable retry state');
}

void attachUthmaniText(
  List<dynamic> layoutVerses,
  List<dynamic> textVerses,
  int page,
) {
  if (layoutVerses.length != textVerses.length) {
    throw FormatException('Page $page: verse counts differ between requests');
  }
  for (var verseIndex = 0; verseIndex < layoutVerses.length; verseIndex++) {
    final verse = layoutVerses[verseIndex] as Map<String, dynamic>;
    final textVerse = textVerses[verseIndex] as Map<String, dynamic>;
    final words = verse['words'] as List;
    final textWords = textVerse['words'] as List;
    if (verse['verse_key'] != textVerse['verse_key'] ||
        words.length != textWords.length) {
      throw FormatException('Page $page: verse/word mismatch at $verseIndex');
    }
    for (var wordIndex = 0; wordIndex < words.length; wordIndex++) {
      final word = words[wordIndex] as Map<String, dynamic>;
      final textWord = textWords[wordIndex] as Map<String, dynamic>;
      if (word['id'] != textWord['id'] ||
          word['position'] != textWord['position'] ||
          word['char_type_name'] != textWord['char_type_name']) {
        throw FormatException(
          'Page $page, ayah ${verse['verse_key']}: word $wordIndex differs',
        );
      }
      if (word['char_type_name'] == 'word') {
        word['text_uthmani'] = textWord['text_uthmani'] as String;
      }
    }
  }
}

List<Object> pageSlots(List<dynamic> verses, int page) {
  final slots = List<List<Object>>.generate(15, (_) => <Object>[]);
  for (final entry in verses) {
    final verse = entry as Map<String, dynamic>;
    final key = verse['verse_key'] as String;
    for (final wordEntry in verse['words'] as List) {
      final word = wordEntry as Map<String, dynamic>;
      final sourcePage = word['page_number'] as int;
      final line = word['line_number'] as int;
      if (sourcePage != page || line < 1 || line > 15) {
        throw FormatException(
          'Page $page, ayah $key: word page $sourcePage, line $line',
        );
      }
      switch (word['char_type_name']) {
        case 'word':
          slots[line - 1].add([key, word['text_uthmani'] as String]);
        case 'end':
          slots[line - 1].add([key]);
        default:
          throw FormatException('Unexpected token type for $key');
      }
    }
  }
  for (final entry in verses) {
    final verse = entry as Map<String, dynamic>;
    if (verse['verse_number'] != 1) continue;
    final key = verse['verse_key'] as String;
    final surah = int.parse(key.split(':').first);
    final first = slots.indexWhere(
      (line) => line.any((token) => (token as List).first == key),
    );
    if (first < 1) throw FormatException('Missing header space for $key');
    final needsBasmala = surah != 1 && surah != 9;
    final separate = needsBasmala && first > 1 && slots[first - 2].isEmpty;
    final header = first - (separate ? 2 : 1);
    if (header < 0 || slots[header].isNotEmpty) {
      throw FormatException('Occupied header space for $key on page $page');
    }
    slots[header].add(['h', surah, if (needsBasmala && !separate) 1]);
    if (separate) slots[header + 1].add(['b']);
  }
  return [
    for (final line in slots)
      line.length == 1 && (line.first as List).first == 'h' ||
              line.length == 1 && (line.first as List).first == 'b'
          ? line.first
          : line,
  ];
}

Future<void> main() async {
  final source =
      jsonDecode(File('assets/quran/quran.json').readAsStringSync()) as Map;
  final expected = List.generate(605, (_) => <String>[]);
  for (final row in source['a'] as List) {
    expected[row[3] as int].add('${row[1]}:${row[2]}');
  }
  final client = HttpClient()..userAgent = 'fadl-mushaf-layout-builder/1.0';
  final pages = <Object>[];
  final disagreements = <int, String>{};
  try {
    for (var page = 1; page <= 604; page++) {
      final layoutResponse = await fetchPage(
        client,
        page,
        'line_number,page_number',
      );
      final textResponse = await fetchPage(client, page, 'text_uthmani');
      final verses = layoutResponse['verses'] as List;
      attachUthmaniText(verses, textResponse['verses'] as List, page);
      final keys = verses
          .map((entry) => (entry as Map)['verse_key'] as String)
          .toList();
      if (jsonEncode(keys) != jsonEncode(expected[page])) {
        final actualKeys = keys.toSet();
        final expectedKeys = expected[page].toSet();
        disagreements[page] =
            'missing ${expectedKeys.difference(actualKeys)}, '
            'extra ${actualKeys.difference(expectedKeys)}, '
            'expected ${expected[page]}, actual $keys';
      } else {
        pages.add(pageSlots(verses, page));
      }
      if (page % 50 == 0) stdout.writeln('Fetched $page/604 pages');
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
  } finally {
    client.close();
  }
  if (disagreements.isNotEmpty) {
    throw FormatException('QuranData page key disagreements: $disagreements');
  }
  final output = File('assets/quran/mushaf_lines.json');
  output.writeAsStringSync(jsonEncode(pages));
  stdout.writeln(
    '${output.path}: ${output.lengthSync()} bytes; disagreements: $disagreements',
  );
}
