import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MushafToken {
  const MushafToken(this.ayahKey, this.text, this.isEnd);
  final String ayahKey;
  final String? text;
  final bool isEnd;
}

class MushafLine {
  const MushafLine._(this.tokens, this.surahId, this.isBasmala);
  final List<MushafToken> tokens;
  final int? surahId;
  final bool isBasmala;
}

class MushafLayout {
  MushafLayout._(this._pages);

  static Future<MushafLayout>? _cached;

  static Future<MushafLayout> load() =>
      _cached ??= _read().catchError((Object error) {
        _cached = null;
        throw error;
      });

  static Future<MushafLayout> _read() async {
    final source = await rootBundle.loadString(
      'assets/quran/mushaf_lines.json',
    );
    final rows = await compute(_decode, source);
    return MushafLayout._([
      for (final page in rows)
        [
          for (final rawLine in page)
            if (rawLine.isNotEmpty && rawLine.first is String)
              MushafLine._(
                const [],
                rawLine.first == 'h' ? rawLine[1] as int : null,
                rawLine.first == 'b' || rawLine.length > 2,
              )
            else
              MushafLine._(
                [
                  for (final rawToken in rawLine)
                    MushafToken(
                      (rawToken as List).first as String,
                      rawToken.length > 1 ? rawToken[1] as String : null,
                      rawToken.length == 1,
                    ),
                ],
                null,
                false,
              ),
        ],
    ]);
  }

  static List<List<List<dynamic>>> _decode(String source) =>
      (jsonDecode(source) as List)
          .map((page) => (page as List).cast<List<dynamic>>())
          .toList();

  final List<List<MushafLine>> _pages;

  int get pageCount => _pages.length;

  List<MushafLine> lines(int page) {
    if (page < 1 || page > _pages.length) {
      throw RangeError.range(page, 1, _pages.length);
    }
    return _pages[page - 1];
  }
}
