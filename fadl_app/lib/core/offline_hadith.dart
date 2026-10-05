import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'api.dart';
import 'download_updates.dart';

// Paths and editions mirror backend/scripts/seed-data.ts. Source texts:
// AhmedBaset/hadith-json; Sunan grades: fawazahmed0/hadith-api.
class _PublicBook {
  const _PublicBook(
    this.path,
    this.group, {
    this.gradeEdition,
    this.defaultSource,
  });
  final String path;
  final String group;
  final String? gradeEdition;
  final String? defaultSource;
}

const _publicBooks = <String, _PublicBook>{
  'bukhari': _PublicBook(
    'the_9_books/bukhari',
    'nine',
    defaultSource: 'صحيح البخاري',
  ),
  'muslim': _PublicBook(
    'the_9_books/muslim',
    'nine',
    defaultSource: 'صحيح مسلم',
  ),
  'abudawud': _PublicBook(
    'the_9_books/abudawud',
    'nine',
    gradeEdition: 'ara-abudawud',
  ),
  'tirmidhi': _PublicBook(
    'the_9_books/tirmidhi',
    'nine',
    gradeEdition: 'ara-tirmidhi',
  ),
  'nasai': _PublicBook('the_9_books/nasai', 'nine', gradeEdition: 'ara-nasai'),
  'ibnmajah': _PublicBook(
    'the_9_books/ibnmajah',
    'nine',
    gradeEdition: 'ara-ibnmajah',
  ),
  'malik': _PublicBook('the_9_books/malik', 'nine'),
  'ahmed': _PublicBook('the_9_books/ahmed', 'nine'),
  'darimi': _PublicBook('the_9_books/darimi', 'nine'),
  'nawawi40': _PublicBook('forties/nawawi40', 'forties'),
  'qudsi40': _PublicBook('forties/qudsi40', 'forties'),
  'riyad': _PublicBook('other_books/riyad_assalihin', 'other'),
  'bulugh': _PublicBook('other_books/bulugh_almaram', 'other'),
  'adab': _PublicBook('other_books/aladab_almufrad', 'other'),
  'shamail': _PublicBook('other_books/shamail_muhammadiyah', 'other'),
  'mishkat': _PublicBook('other_books/mishkat_almasabih', 'other'),
};

// Approximate source transfer sizes in KiB; Sunan include their grade feeds.
const hadithApproxDownloadBytes = <String, int>{
  'bukhari': 12452 * 1024,
  'muslim': 11185 * 1024,
  'abudawud': (7692 + 7173) * 1024,
  'tirmidhi': (7481 + 6954) * 1024,
  'nasai': (7702 + 6985) * 1024,
  'ibnmajah': (5590 + 5452) * 1024,
  'malik': 3190 * 1024,
  'ahmed': 2321 * 1024,
  'darimi': 2983 * 1024,
  'nawawi40': 70 * 1024,
  'qudsi40': 81 * 1024,
  'riyad': 2150 * 1024,
  'bulugh': 2002 * 1024,
  'adab': 1710 * 1024,
  'shamail': 519 * 1024,
  'mishkat': 5101 * 1024,
};

const _gradeAr = <String, String>{
  'sahih': 'صحيح',
  'hasan': 'حسن',
  'hasan sahih': 'حسن صحيح',
  'sahih lighairihi': 'صحيح لغيره',
  'hasan lighairihi': 'حسن لغيره',
  "da'if": 'ضعيف',
  'daif': 'ضعيف',
  'da`if': 'ضعيف',
  'da’if': 'ضعيف',
  'daif jiddan': 'ضعيف جداً',
  "da'if jiddan": 'ضعيف جداً',
  'munkar': 'منكر',
  'shadh': 'شاذ',
  "mawdu'": 'موضوع',
  'maudu': 'موضوع',
  'mawdu': 'موضوع',
  'sahih mauquf': 'صحيح موقوف',
  'sahih maqtu': 'صحيح مقطوع',
  "da'if mauquf": 'ضعيف موقوف',
  'hasan mauquf': 'حسن موقوف',
  'sahih muquf': 'صحيح موقوف',
  'sahih hadith': 'صحيح',
  'sahih mutawatir': 'صحيح متواتر',
  'very daif': 'ضعيف جداً',
  'sahih isnaad': 'صحيح الإسناد',
  'hasan isnaad': 'حسن الإسناد',
  'daif isnaad': 'ضعيف الإسناد',
  'sahih isnaad maqtu': 'صحيح الإسناد مقطوع',
  'sahih isnaad mauquf': 'صحيح الإسناد موقوف',
};

class OfflineHadith {
  OfflineHadith({
    http.Client? client,
    http.Client? publicClient,
    Uri? base,
    Future<Directory> Function()? root,
  }) : _client = client,
       _publicClient = publicClient,
       _base = base,
       _root = root ?? getApplicationSupportDirectory;

  static final instance = OfflineHadith();
  static const _pageSize = 20;
  static const _maxPageBytes = 1024 * 1024;
  final http.Client? _client;
  final http.Client? _publicClient;
  final Uri? _base;
  final Future<Directory> Function() _root;
  final Map<String, Map<String, dynamic>> _books = {};
  final Map<String, Future<void>> _running = {};
  Future<void>? _ready;
  Directory? _directory;

  Future<void> ready() => _ready ??= _scan().catchError((Object error) {
    _ready = null;
    throw error;
  });

  Future<void> _scan() async {
    _directory = Directory('${(await _root()).path}/hadith');
    _books.clear();
    if (!await _directory!.exists()) return;
    for (final file in _directory!.listSync().whereType<File>()) {
      if (!file.path.endsWith('.jsonl')) continue;
      try {
        final header = await file
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first;
        final book =
            (jsonDecode(header) as Map<String, dynamic>)['book']
                as Map<String, dynamic>;
        if (file.path.endsWith('/${book['slug']}.jsonl') ||
            file.path.endsWith('\\${book['slug']}.jsonl')) {
          final catalog =
              (jsonDecode(header) as Map<String, dynamic>)['catalog']
                  as Map<String, dynamic>;
          _books[book['slug'] as String] = {...book, ...catalog};
        }
      } on FormatException {
        // Ignore interrupted or damaged downloads; never display them as books.
      } on TypeError {
        // Ignore files with an invalid header.
      }
    }
  }

  File _file(String slug) => File('${_directory!.path}/$slug.jsonl');
  bool isDownloaded(String slug) => _books.containsKey(slug);
  bool isDownloading(String slug) => _running.containsKey(slug);
  List<Map<String, dynamic>> get downloadedBooks => _books.values.toList();
  List<Map<String, dynamic>> get availableBooks => [
    for (final entry in _publicBooks.entries)
      {
        'slug': entry.key,
        'nameAr': _books[entry.key]?['nameAr'] ?? entry.key,
        'group': entry.value.group,
        'groupAr': switch (entry.value.group) {
          'nine' => 'الكتب التسعة',
          'forties' => 'الأربعينيات',
          _ => 'كتب أخرى',
        },
        if (_books[entry.key] != null) ..._books[entry.key]!,
      },
  ];

  Future<int> size(String slug) async {
    await ready();
    return isDownloaded(slug) ? _file(slug).length() : 0;
  }

  Future<void> delete(String slug) async {
    await ready();
    if (_running.containsKey(slug)) throw StateError('انتظر اكتمال التنزيل');
    final file = _file(slug);
    if (await file.exists()) await file.delete();
    _books.remove(slug);
    await DownloadUpdates.instance.remove('hadith:$slug');
    await DownloadUpdates.instance.remove('grade:$slug');
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, Object?>? query,
  ]) async {
    if (_client == null) {
      return (await Api.instance.get(path, query)) as Map<String, dynamic>;
    }
    final uri = _base!
        .resolve(path)
        .replace(
          queryParameters: {
            for (final entry in (query ?? {}).entries)
              if (entry.value != null) entry.key: '${entry.value}',
          },
        );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 ||
        response.bodyBytes.length > _maxPageBytes) {
      throw const FormatException('Invalid hadith response status or size');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<void> download(String slug, Map<String, dynamic> catalogBook) {
    if ((Api.hasBackend
            ? !RegExp(r'^[a-z0-9]+$').hasMatch(slug)
            : !_publicBooks.containsKey(slug)) ||
        catalogBook['slug'] != slug ||
        (_client != null && _base == null && Api.hasBackend)) {
      throw StateError('كتاب غير متاح للتنزيل');
    }
    return _running.putIfAbsent(slug, () async {
      try {
        if (Api.hasBackend) {
          await _download(slug, catalogBook);
        } else {
          await _downloadPublic(slug);
        }
      } finally {
        _running.remove(slug);
      }
    });
  }

  static String? sourceUrl(String slug) {
    final definition = _publicBooks[slug];
    if (definition == null) return null;
    return 'https://raw.githubusercontent.com/AhmedBaset/hadith-json/main/db/by_book/${definition.path}.json';
  }

  static String? gradeSourceUrl(String slug) {
    final edition = _publicBooks[slug]?.gradeEdition;
    return edition == null
        ? null
        : 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/$edition.json';
  }

  Future<({Map<String, dynamic> json, Map<String, String> headers})>
  _publicJson(http.Client client, Uri uri, int maxBytes) async {
    if (uri.scheme != 'https' ||
        !{'raw.githubusercontent.com', 'cdn.jsdelivr.net'}.contains(uri.host)) {
      throw const FormatException('Invalid hadith source');
    }
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 ||
        response.contentLength != null && response.contentLength! > maxBytes) {
      throw const FormatException('Invalid hadith source status or size');
    }
    final bytes = BytesBuilder(copy: false);
    await response.stream
        .forEach((chunk) {
          bytes.add(chunk);
          if (bytes.length > maxBytes) {
            throw const FormatException('Hadith source too large');
          }
        })
        .timeout(const Duration(minutes: 3));
    final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid hadith JSON');
    }
    return (json: decoded, headers: response.headers);
  }

  static String _prefix(String text) {
    final normalized = normalize(text).replaceAll(RegExp(r'\s'), '');
    return normalized.substring(0, normalized.length.clamp(0, 120));
  }

  Map<String, Map<String, String>> _grades(
    List<dynamic> ownHadiths,
    Map<String, dynamic> feed,
  ) {
    final entries = feed['hadiths'];
    if (entries is! List || entries.isEmpty || entries.length > 100000) {
      throw const FormatException('Invalid grade feed');
    }
    final byPrefix = <String, Map<String, dynamic>?>{};
    for (final entry in entries) {
      if (entry is! Map<String, dynamic> ||
          entry['text'] is! String ||
          entry['grades'] is! List) {
        throw const FormatException('Invalid grade schema');
      }
      final key = _prefix(entry['text'] as String);
      byPrefix[key] = byPrefix.containsKey(key) ? null : entry;
    }
    final counts = <String, int>{};
    for (final entry in ownHadiths) {
      if (entry is! Map<String, dynamic> || entry['arabic'] is! String) {
        throw const FormatException('Invalid hadith schema');
      }
      final key = _prefix(entry['arabic'] as String);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final matched = <String, Map<String, String>>{};
    for (final entry in ownHadiths.cast<Map<String, dynamic>>()) {
      final key = _prefix(entry['arabic'] as String);
      final candidates = byPrefix[key]?['grades'];
      if (key.length < 60 ||
          counts[key] != 1 ||
          candidates is! List ||
          candidates.isEmpty) {
        continue;
      }
      if (candidates.any(
        (grade) =>
            grade is! Map<String, dynamic> ||
            grade['name'] is! String ||
            grade['grade'] is! String,
      )) {
        throw const FormatException('Invalid grade schema');
      }
      final picked = candidates.cast<Map<String, dynamic>>().firstWhere(
        (grade) => RegExp(
          'albani',
          caseSensitive: false,
        ).hasMatch(grade['name'] as String),
        orElse: () => candidates.first as Map<String, dynamic>,
      );
      final label = (picked['grade'] as String)
          .toLowerCase()
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final arabic = _gradeAr[label];
      if (arabic != null) {
        matched[key] = {
          'grade': arabic,
          'source':
              RegExp(
                'albani',
                caseSensitive: false,
              ).hasMatch(picked['name'] as String)
              ? 'الألباني'
              : picked['name'] as String,
        };
      }
    }
    return matched;
  }

  Future<void> _downloadPublic(String slug) async {
    await ready();
    final definition = _publicBooks[slug]!;
    final client = _publicClient ?? http.Client();
    final target = _file(slug);
    final part = File('${target.path}.part');
    IOSink? sink;
    try {
      final sourceResponse = await _publicJson(
        client,
        Uri.parse(sourceUrl(slug)!),
        20 * 1024 * 1024,
      );
      final source = sourceResponse.json;
      final metadata = source['metadata'];
      final chapters = source['chapters'];
      final hadiths = source['hadiths'];
      if (metadata is! Map<String, dynamic> ||
          metadata['arabic'] is! Map ||
          metadata['english'] is! Map ||
          chapters is! List ||
          hadiths is! List ||
          hadiths.isEmpty ||
          hadiths.length > 100000 ||
          chapters.length > 10000) {
        throw const FormatException('Invalid hadith book schema');
      }
      final arabic = metadata['arabic'] as Map;
      final english = metadata['english'] as Map;
      if (arabic['title'] is! String ||
          (arabic['title'] as String).trim().isEmpty ||
          arabic['author'] is! String ||
          english['title'] is! String) {
        throw const FormatException('Invalid hadith metadata');
      }
      final gradeUrl = gradeSourceUrl(slug);
      final gradeResponse = gradeUrl == null
          ? null
          : await _publicJson(client, Uri.parse(gradeUrl), 12 * 1024 * 1024);
      final grades = gradeResponse == null
          ? <String, Map<String, String>>{}
          : _grades(hadiths, gradeResponse.json);
      final chapterByNumber = <int, Map<String, dynamic>>{};
      for (final entry in chapters) {
        if (entry is! Map<String, dynamic> ||
            entry['id'] is! int ||
            entry['arabic'] is! String ||
            entry['english'] != null && entry['english'] is! String) {
          throw const FormatException('Invalid chapter schema');
        }
        final title = (entry['arabic'] as String).trim();
        if (title.isEmpty || chapterByNumber.containsKey(entry['id'])) continue;
        chapterByNumber[entry['id'] as int] = {
          'id':
              _publicBooks.keys.toList().indexOf(slug) * 10000 +
              chapterByNumber.length +
              1,
          'number': entry['id'],
          'nameAr': title,
          'nameEn': (entry['english'] as String?)?.trim().isNotEmpty == true
              ? (entry['english'] as String).trim()
              : null,
          'count': 0,
        };
      }
      final name = (arabic['title'] as String).trim();
      final bookRef = {'slug': slug, 'nameAr': name};
      final bookRows = <Map<String, dynamic>>[];
      final seen = <int>{};
      for (final entry in hadiths) {
        if (entry is! Map<String, dynamic> ||
            entry['idInBook'] is! int ||
            entry['arabic'] is! String ||
            entry['chapterId'] != null && entry['chapterId'] is! int ||
            entry['english'] != null && entry['english'] is! Map) {
          throw const FormatException('Invalid hadith schema');
        }
        final number = entry['idInBook'] as int;
        final text = (entry['arabic'] as String).trim();
        if (text.isEmpty || !seen.add(number)) continue;
        final chapter = chapterByNumber[entry['chapterId']];
        if (chapter != null) chapter['count'] = (chapter['count'] as int) + 1;
        final translation = entry['english'] as Map?;
        if (translation != null &&
            (translation['text'] != null && translation['text'] is! String ||
                translation['narrator'] != null &&
                    translation['narrator'] is! String)) {
          throw const FormatException('Invalid translation schema');
        }
        final grade = grades[_prefix(text)];
        final normalized = normalize(text);
        const prophet = 'صلي الله عليه وسلم';
        final start = normalized.indexOf(prophet);
        final words =
            (start >= 0
                    ? normalized.substring(start + prophet.length)
                    : normalized)
                .split(' ')
                .where(
                  (word) =>
                      word.isNotEmpty &&
                      !['قال', 'يقول', 'انه', 'ان'].contains(word),
                )
                .toList();
        final excerpt =
            (start >= 0
                    ? words.take(10)
                    : words.skip((words.length - 10).clamp(0, words.length)))
                .join(' ');
        final query = Uri.encodeComponent(excerpt);
        bookRows.add({
          'id':
              _publicBooks.keys.toList().indexOf(slug) * 100000 +
              bookRows.length +
              1,
          'number': number,
          'book': bookRef,
          'chapterAr': chapter?['nameAr'],
          'textAr': text,
          'textEn': (translation?['text'] as String?)?.trim().isNotEmpty == true
              ? (translation!['text'] as String).trim()
              : null,
          'narratorEn':
              (translation?['narrator'] as String?)?.trim().isNotEmpty == true
              ? (translation!['narrator'] as String).trim()
              : null,
          'grade': definition.defaultSource != null ? 'صحيح' : grade?['grade'],
          'gradeSource': definition.defaultSource ?? grade?['source'],
          'reference': '$name ($number)',
          'links': {
            'dorar': 'https://dorar.net/hadith/search?q=$query',
            'sunnah': 'https://sunnah.com/search?q=$query',
          },
        });
      }
      if (bookRows.isEmpty ||
          bookRows.length !=
              hadiths
                  .where(
                    (entry) =>
                        entry is Map &&
                        entry['arabic'] is String &&
                        (entry['arabic'] as String).trim().isNotEmpty,
                  )
                  .map((entry) => (entry as Map)['idInBook'])
                  .toSet()
                  .length) {
        throw const FormatException('Incomplete hadith book');
      }
      final book = {
        'slug': slug,
        'nameAr': name,
        'authorAr': (arabic['author'] as String).trim(),
        'hadithCount': bookRows.length,
        'chapters': chapterByNumber.values.toList()
          ..sort((a, b) => (a['number'] as int).compareTo(b['number'] as int)),
      };
      final catalog = {
        'slug': slug,
        'nameAr': name,
        'nameEn': (english['title'] as String).trim(),
        'authorAr': book['authorAr'],
        'group': definition.group,
        'groupAr': switch (definition.group) {
          'nine' => 'الكتب التسعة',
          'forties' => 'الأربعينيات',
          _ => 'كتب أخرى',
        },
        'hadithCount': bookRows.length,
      };
      await target.parent.create(recursive: true);
      sink = part.openWrite();
      sink.writeln(jsonEncode({'book': book, 'catalog': catalog}));
      for (final row in bookRows) {
        sink.writeln(jsonEncode(row));
      }
      sink.writeln(jsonEncode({'complete': bookRows.length}));
      await sink.flush();
      await sink.close();
      sink = null;
      if (await target.exists()) await target.delete();
      await part.rename(target.path);
      _books[slug] = {...book, ...catalog};
      await DownloadUpdates.instance.record(
        'hadith:$slug',
        sourceUrl(slug)!,
        sourceResponse.headers,
      );
      if (gradeResponse != null) {
        await DownloadUpdates.instance.record(
          'grade:$slug',
          gradeUrl!,
          gradeResponse.headers,
        );
      }
    } finally {
      if (sink != null) await sink.close();
      if (await part.exists()) await part.delete();
      if (_publicClient == null) client.close();
    }
  }

  Future<void> _download(String slug, Map<String, dynamic> catalogBook) async {
    await ready();
    final book = await _get('/hadith/books/$slug');
    if (book['slug'] != slug ||
        book['chapters'] is! List ||
        book['hadithCount'] is! int) {
      throw const FormatException('Invalid hadith book');
    }
    final target = _file(slug);
    await target.parent.create(recursive: true);
    final part = File('${target.path}.part');
    IOSink? sink;
    try {
      sink = part.openWrite();
      sink.writeln(jsonEncode({'book': book, 'catalog': catalogBook}));
      var offset = 0;
      int? total;
      do {
        final response = await _get('/hadith/books/$slug/hadiths', {
          'limit': _pageSize,
          'offset': offset,
        });
        final hadiths = response['hadiths'];
        final count = response['total'];
        if (hadiths is! List ||
            count is! int ||
            count < 0 ||
            count > 100000 ||
            (total != null && count != total) ||
            hadiths.length > _pageSize ||
            (offset < count && hadiths.isEmpty) ||
            offset + hadiths.length > count) {
          throw const FormatException('Incomplete hadith download');
        }
        total = count;
        for (final entry in hadiths) {
          final hadith = entry as Map<String, dynamic>;
          if (hadith['textAr'] is! String ||
              hadith['number'] is! int ||
              (hadith['book'] as Map?)?['slug'] != slug) {
            throw const FormatException('Invalid hadith schema');
          }
          sink.writeln(jsonEncode(hadith));
        }
        offset += hadiths.length;
      } while (offset < total);
      sink.writeln(jsonEncode({'complete': total}));
      await sink.flush();
      await sink.close();
      sink = null;
      if (await target.exists()) await target.delete();
      await part.rename(target.path);
      _books[slug] = {...book, ...catalogBook};
    } finally {
      if (sink != null) await sink.close();
      if (await part.exists()) await part.delete();
    }
  }

  Future<Map<String, dynamic>?> book(String slug) async {
    await ready();
    if (!isDownloaded(slug)) return null;
    final line = await _file(
      slug,
    ).openRead().transform(utf8.decoder).transform(const LineSplitter()).first;
    return (jsonDecode(line) as Map<String, dynamic>)['book']
        as Map<String, dynamic>;
  }

  Stream<Map<String, dynamic>> _rows(String slug) async* {
    await ready();
    if (!isDownloaded(slug)) return;
    var first = true;
    await for (final line in _file(
      slug,
    ).openRead().transform(utf8.decoder).transform(const LineSplitter())) {
      if (first) {
        first = false;
        continue;
      }
      final row = jsonDecode(line) as Map<String, dynamic>;
      if (row.containsKey('complete')) break;
      yield row;
    }
  }

  Future<Map<String, dynamic>> hadiths(
    String slug, {
    int? chapterId,
    int limit = 20,
    int offset = 0,
  }) async {
    final chapter = (await book(slug))?['chapters'] as List?;
    if (chapter == null) {
      return {'total': 0, 'hadiths': <Map<String, dynamic>>[]};
    }
    final chapterName = chapterId == null
        ? null
        : chapter
              .cast<Map<String, dynamic>>()
              .where((c) => c['id'] == chapterId)
              .firstOrNull;
    final total = chapterId == null
        ? ((await book(slug))!['hadithCount'] as int)
        : (chapterName?['count'] as int? ?? 0);
    final matches = <Map<String, dynamic>>[];
    var seen = 0;
    await for (final row in _rows(slug)) {
      if (chapterId != null && row['chapterAr'] != chapterName?['nameAr']) {
        continue;
      }
      if (seen >= offset && matches.length < limit) matches.add(row);
      seen++;
      if (matches.length == limit) break;
    }
    return {'total': total, 'hadiths': matches};
  }

  static String normalize(String text) => text
      .replaceAll(
        RegExp(
          r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u08D3-\u08FF\u0640]',
        ),
        '',
      )
      .replaceAll(RegExp('[آأإٱٲٳ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll(RegExp(r'[^\u0621-\u064A0-9a-zA-Z\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();

  Future<Map<String, dynamic>> search(
    String query, {
    String? bookSlug,
    int limit = 20,
    int offset = 0,
  }) async {
    await ready();
    final words = normalize(query).split(' ').where((word) => word.isNotEmpty);
    final terms = words
        .map(
          (word) => word.startsWith('ال') && word.length >= 5
              ? word.substring(2)
              : word,
        )
        .where((word) => word.length >= 2)
        .toSet()
        .toList();
    final selected = terms.where((term) => term.length >= 3).toList();
    final searchTerms = selected.isEmpty ? terms : selected;
    final matches = <Map<String, dynamic>>[];
    if (searchTerms.isEmpty) {
      return {'query': query, 'total': 0, 'results': matches};
    }
    int rank(Map<String, dynamic> row) {
      final grade = row['grade'] as String?;
      if (grade?.startsWith('صحيح') ?? false) return 0;
      if (grade?.startsWith('حسن') ?? false) return 1;
      return grade == null ? 2 : 3;
    }

    final bookOrder = {
      for (var i = 0; i < _books.length; i++) _books.keys.elementAt(i): i,
    };
    int compare(Map<String, dynamic> a, Map<String, dynamic> b) {
      final gradeOrder = rank(a).compareTo(rank(b));
      if (gradeOrder != 0) return gradeOrder;
      final collectionOrder = (bookOrder[(a['book'] as Map)['slug']] ?? 0)
          .compareTo(bookOrder[(b['book'] as Map)['slug']] ?? 0);
      if (collectionOrder != 0) return collectionOrder;
      final lengthOrder = (a['textAr'] as String).length.compareTo(
        (b['textAr'] as String).length,
      );
      return lengthOrder != 0
          ? lengthOrder
          : (a['number'] as int).compareTo(b['number'] as int);
    }

    var total = 0;
    final capacity = (offset + limit).clamp(0, 1000);
    for (final slug in bookSlug == null ? _books.keys : [bookSlug]) {
      await for (final row in _rows(slug)) {
        final text = normalize(row['textAr'] as String);
        if (!searchTerms.every(text.contains)) continue;
        total++;
        if (capacity == 0) continue;
        var index = 0;
        while (index < matches.length && compare(matches[index], row) <= 0) {
          index++;
        }
        if (index >= capacity) continue;
        matches.insert(index, row);
        if (matches.length > capacity) matches.removeLast();
      }
    }
    return {
      'query': query,
      'total': total,
      'results': matches.skip(offset).take(limit).toList(),
    };
  }
}
