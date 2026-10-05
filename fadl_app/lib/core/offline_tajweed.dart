import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'download_updates.dart';

const tajweedPreferenceKey = 'fadl.tajweedColors';
const tajweedSource = 'Quran.com API v4';
const tajweedSourceUrl =
    'https://api.quran.com/api/v4/quran/verses/uthmani_tajweed';
const tajweedMaxBytes = 12 * 1024 * 1024;
const tajweedApproxBytes = 4061465;

class TajweedDownloadException implements Exception {
  const TajweedDownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TajweedPiece {
  const TajweedPiece(this.text, this.rule);
  final String text;
  final String? rule;
}

// These are display categories of the provider's tags, not religious rulings.
const tajweedColors = <String, Color>{
  'madda_normal': Color(0xFF146A94),
  'madda_permissible': Color(0xFF146A94),
  'madda_obligatory': Color(0xFF146A94),
  'madda_necessary': Color(0xFF146A94),
  'ghunnah': Color(0xFFBD414C),
  'ikhafa': Color(0xFFBD414C),
  'ikhafa_shafawi': Color(0xFFBD414C),
  'idgham_ghunnah': Color(0xFFBD414C),
  'idgham_wo_ghunnah': Color(0xFF8B579D),
  'idgham_shafawi': Color(0xFF8B579D),
  'idgham_mutajanisayn': Color(0xFF8B579D),
  'idgham_mutaqaribayn': Color(0xFF8B579D),
  'iqlab': Color(0xFF8B579D),
  'qalaqah': Color(0xFFB15D1B),
  'ham_wasl': Color(0xFF497E51),
  'laam_shamsiyah': Color(0xFF497E51),
  'slnt': Color(0xFF757575),
};

final _tag = RegExp(r'<[^>]*>');
final _openingRule = RegExp(r'^<tajweed class=([a-z_]+)>$');
final _entity = RegExp(r'&(?:amp|lt|gt|quot|apos);');

String _unescape(String text) => text.replaceAllMapped(_entity, (match) {
  return switch (match.group(0)) {
    '&amp;' => '&',
    '&lt;' => '<',
    '&gt;' => '>',
    '&quot;' => '"',
    _ => "'",
  };
});

/// Only the provider's narrow markup vocabulary is accepted; nothing is HTML-rendered.
List<TajweedPiece> parseTajweedMarkup(String markup) {
  final pieces = <TajweedPiece>[];
  String? rule;
  var endMarker = false;
  var markerClosed = false;
  var cursor = 0;
  void append(String text) {
    if (text.isNotEmpty && !endMarker) {
      pieces.add(TajweedPiece(_unescape(text), rule));
    }
  }

  for (final match in _tag.allMatches(markup)) {
    append(markup.substring(cursor, match.start));
    final token = match.group(0)!;
    final opening = _openingRule.firstMatch(token);
    if (opening != null &&
        tajweedColors.containsKey(opening.group(1)) &&
        rule == null &&
        !endMarker) {
      rule = opening.group(1)!;
    } else if (token == '</tajweed>' && rule != null && !endMarker) {
      rule = null;
    } else if (token == '<span class=end>' && rule == null && !endMarker) {
      endMarker = true;
      if (pieces.isNotEmpty) {
        final last = pieces.removeLast();
        pieces.add(TajweedPiece(last.text.trimRight(), last.rule));
      }
    } else if (token == '</span>' && endMarker) {
      endMarker = false;
      if (markup.substring(match.end).trim().isNotEmpty) {
        throw const FormatException('Text after verse marker');
      }
      cursor = markup.length;
      markerClosed = true;
      break;
    } else {
      throw const FormatException('Unexpected tajweed markup');
    }
    cursor = match.end;
  }
  if (rule != null || endMarker) {
    throw const FormatException('Unclosed tajweed tag');
  }
  if (cursor < markup.length) append(markup.substring(cursor));
  if (!markerClosed ||
      pieces.isEmpty ||
      pieces.any(
        (piece) => piece.text.contains('<') || piece.text.contains('>'),
      )) {
    throw const FormatException('Empty or malformed tajweed text');
  }
  return pieces;
}

/// Reject incomplete or duplicated verse lists before any file becomes visible.
Map<String, String> parseTajweedVerses(
  List<int> bytes, {
  int expectedCount = 6236,
}) {
  if (bytes.length > tajweedMaxBytes) {
    throw const FormatException('Oversized tajweed response');
  }
  final decoded = jsonDecode(utf8.decode(bytes));
  final verses = decoded is Map ? decoded['verses'] : null;
  if (verses is! List || verses.length != expectedCount) {
    throw const FormatException('Incomplete tajweed response');
  }
  final texts = <String, String>{};
  final keyPattern = RegExp(
    r'^(?:[1-9]|[1-9][0-9]|10[0-9]|11[0-4]):[1-9][0-9]*$',
  );
  for (final verse in verses) {
    if (verse is! Map ||
        verse['verse_key'] is! String ||
        verse['text_uthmani_tajweed'] is! String) {
      throw const FormatException('Invalid tajweed verse');
    }
    final key = verse['verse_key'] as String;
    final markup = verse['text_uthmani_tajweed'] as String;
    if (!keyPattern.hasMatch(key) || texts.containsKey(key)) {
      throw const FormatException('Duplicate or invalid verse key');
    }
    parseTajweedMarkup(markup);
    texts[key] = markup;
  }
  return texts;
}

class OfflineTajweed extends ChangeNotifier {
  OfflineTajweed({http.Client? client, Future<Directory> Function()? root})
    : _client = client ?? http.Client(),
      _rootProvider = root ?? getApplicationSupportDirectory;

  static final OfflineTajweed instance = OfflineTajweed();
  final http.Client _client;
  final Future<Directory> Function() _rootProvider;
  Future<void>? _ready;
  File? _file;
  Map<String, String>? _verses;
  final Map<String, List<TajweedPiece>> _pieces = {};
  Future<void>? _running;
  int receivedBytes = 0;
  int? expectedBytes;

  bool get isDownloaded => _verses != null;
  bool get isDownloading => _running != null;
  List<TajweedPiece>? pieces(String key) {
    final markup = _verses?[key];
    if (markup == null) return null;
    return _pieces.putIfAbsent(key, () => parseTajweedMarkup(markup));
  }

  Future<void> ready() => _ready ??= _load().catchError((Object error) {
    _ready = null;
    throw error;
  });

  Future<void> _load() async {
    final root = await _rootProvider();
    _file = File('${root.path}/tajweed/uthmani_tajweed.json.gz');
    if (!await _file!.exists()) return;
    try {
      final compressed = await _file!.readAsBytes();
      if (compressed.length > tajweedMaxBytes) {
        throw const FormatException('Oversized cache');
      }
      _verses = await compute(_parseGzip, compressed);
    } on FormatException {
      await _file!.delete();
    }
    notifyListeners();
  }

  Future<int> size() async {
    await ready();
    return isDownloaded ? _file!.length() : 0;
  }

  Future<void> download() => _running ??= _download().whenComplete(() {
    _running = null;
    receivedBytes = 0;
    expectedBytes = null;
    notifyListeners();
  });

  Future<void> _download() async {
    await ready();
    final uri = Uri.parse(tajweedSourceUrl);
    if (uri.scheme != 'https' || uri.host != 'api.quran.com') {
      throw const TajweedDownloadException('مصدر التنزيل غير موثوق');
    }
    notifyListeners();
    try {
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 ||
          response.request?.url.host != uri.host) {
        throw const FormatException('Invalid download response');
      }
      expectedBytes = response.contentLength;
      if (expectedBytes != null && expectedBytes! > tajweedMaxBytes) {
        throw const FormatException('Oversized download');
      }
      final chunks = <int>[];
      final watch = Stopwatch()..start();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        receivedBytes += chunk.length;
        if (receivedBytes > tajweedMaxBytes ||
            watch.elapsed > const Duration(minutes: 3)) {
          throw const FormatException('Download limit exceeded');
        }
        chunks.addAll(chunk);
        notifyListeners();
      }
      if (expectedBytes != null && receivedBytes != expectedBytes) {
        throw const FormatException('Truncated download');
      }
      final verses = await compute(parseTajweedVerses, chunks);
      final part = File('${_file!.path}.part');
      await part.parent.create(recursive: true);
      try {
        await part.writeAsBytes(await compute(_gzip, chunks), flush: true);
        await part.rename(_file!.path);
      } finally {
        if (await part.exists()) await part.delete();
      }
      _verses = verses;
      _pieces.clear();
      await DownloadUpdates.instance.record(
        'tajweed',
        tajweedSourceUrl,
        response.headers,
      );
      notifyListeners();
    } on Object {
      throw const TajweedDownloadException(
        'تعذّر تنزيل نص التجويد أو التحقق منه. أعد المحاولة.',
      );
    }
  }

  Future<void> delete() async {
    await ready();
    try {
      await _running;
    } on TajweedDownloadException {
      // A failed download has no completed file to retain.
    }
    if (await _file!.exists()) await _file!.delete();
    final part = File('${_file!.path}.part');
    if (await part.exists()) await part.delete();
    _verses = null;
    await DownloadUpdates.instance.remove('tajweed');
    _pieces.clear();
    notifyListeners();
  }
}

List<int> _gzip(List<int> bytes) => gzip.encode(bytes);

Map<String, String> _parseGzip(List<int> compressed) =>
    parseTajweedVerses(gzip.decode(compressed));
