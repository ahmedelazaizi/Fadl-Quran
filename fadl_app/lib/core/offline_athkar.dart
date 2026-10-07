import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'athkar_repeats.dart';
import 'quran_data.dart';

/// Hisn al-Muslim category name → stable slug and order; mirrors
/// FEATURED_CATEGORIES in backend/scripts/seed-data.ts.
const Map<String, ({String slug, int order})> featuredAthkarCategories = {
  'أذكار الصباح': (slug: 'morning', order: 1),
  'أذكار المساء': (slug: 'evening', order: 2),
  'الأذكار بعد السلام من الصلاة': (slug: 'after-prayer', order: 3),
  'أذكار النوم': (slug: 'sleep', order: 4),
  'أذكار الاستيقاظ من النوم': (slug: 'waking', order: 5),
  'دعاء السفر': (slug: 'travel', order: 6),
  'دعاء الكرب': (slug: 'distress', order: 7),
  'دعاء الهم والحزن': (slug: 'grief', order: 8),
  'الاستغفار و التوبة': (slug: 'istighfar', order: 9),
  'التسبيح، التحميد، التهليل، التكبير': (slug: 'tasbih', order: 10),
  'أذكار الآذان': (slug: 'adhan', order: 11),
  'الرقية الشرعية من القرآن الكريم': (slug: 'ruqyah-quran', order: 12),
  'الرقية الشرعية من السنة النبوية': (slug: 'ruqyah-sunnah', order: 13),
};

/// Dua collections; mirrors DUA_COLLECTIONS in backend/scripts/seed-data.ts.
/// `verses` reference Quranic duas, `categories` pull every dhikr of a
/// Hisn al-Muslim category.
const List<
  ({String slug, String nameAr, List<String> verses, List<String> categories})
>
duaCollections = [
  (
    slug: 'parents',
    nameAr: 'للوالدين والأب',
    verses: ['17:24', '14:41', '71:28', '46:15', '27:19'],
    categories: [],
  ),
  (
    slug: 'deceased',
    nameAr: 'للمتوفى',
    verses: ['59:10'],
    categories: [
      'الدعاء عند إغماض الميت',
      'الدعاء للميت في الصلاة عليه',
      'الدعاء بعد دفن الميت',
      'دعاء زيارة القبور',
    ],
  ),
  (
    slug: 'comprehensive',
    nameAr: 'جوامع الدعاء',
    verses: ['2:201', '2:286', '3:8', '3:193-194', '7:23', '14:40', '25:74'],
    categories: [],
  ),
  (
    slug: 'healing',
    nameAr: 'الشفاء',
    verses: ['26:80', '21:83'],
    categories: ['الدعاء للمريض في عيادته', 'ما يقول من أحس وجعا في جسده'],
  ),
  (
    slug: 'relief',
    nameAr: 'تفريج الكرب',
    verses: ['21:87'],
    categories: ['دعاء الكرب', 'دعاء الهم والحزن'],
  ),
  (
    slug: 'provision',
    nameAr: 'الرزق',
    verses: ['5:114', '28:24', '71:10-12'],
    categories: ['دعاء قضاء الدين'],
  ),
  (
    slug: 'ramadan',
    nameAr: 'أدعية رمضان والصيام',
    verses: ['2:186'],
    categories: [
      'دعاء رؤية الهلال',
      'الدعاء عند إفطار الصائم',
      'دعاء الصائم إذا حضر الطعام ولم يفطر',
      'ما يقول الصائم إذا سابه أحد',
      'دعاء قنوت الوتر',
    ],
  ),
];

class _Category {
  _Category(this.id, this.slug, this.nameAr, this.featured, this.sortOrder);
  final int id;
  final String slug;
  final String nameAr;
  final bool featured;
  final int sortOrder;
  final List<Map<String, dynamic>> items = [];
}

/// Local Hisn al-Muslim athkar (assets/athkar/azkar.json). Ids, slugs and
/// response maps follow the backend seed and athkar routes so the screens
/// can use either source.
class OfflineAthkar {
  OfflineAthkar._(this._categories, this._dhikr, this._searchText);

  static const assetPath = 'assets/athkar/azkar.json';
  static Future<OfflineAthkar>? _cached;

  /// Reads and indexes the asset once; a failure is not cached.
  static Future<OfflineAthkar> load() =>
      _cached ??= _read().catchError((Object error) {
        _cached = null;
        throw error;
      });

  static Future<OfflineAthkar> _read() async => OfflineAthkar.fromAsset(
    jsonDecode(await rootBundle.loadString(assetPath)) as Map<String, dynamic>,
  );

  /// Builds the index from `{columns: [...], rows: [[...]]}` exactly like
  /// seedAthkar(): categories in first-appearance order, sequential ids.
  factory OfflineAthkar.fromAsset(Map<String, dynamic> json) {
    final columns = (json['columns'] as List).cast<String>();
    final category = columns.indexOf('category');
    final zekr = columns.indexOf('zekr');
    final description = columns.indexOf('description');
    final count = columns.indexOf('count');
    final reference = columns.indexOf('reference');
    final rows = (json['rows'] as List).cast<List>();

    final byRawName = <String, _Category>{};
    final dhikr = <int, Map<String, dynamic>>{};
    final searchText = <int, String>{};
    for (final row in rows) {
      final raw = row[category] as String;
      final cat = byRawName.putIfAbsent(raw, () {
        final index = byRawName.length;
        final name = raw.trim();
        final featured = featuredAthkarCategories[name];
        return _Category(
          index + 1,
          featured?.slug ?? 'hisn-${index + 1}',
          name,
          featured != null,
          featured?.order ?? 100 + index,
        );
      });
      final id = dhikr.length + 1;
      final text = row[zekr] as String;
      final repeat = row[count];
      final item = <String, dynamic>{
        'id': id,
        'categoryId': cat.id,
        'text': text.trim(),
        'virtue': _nonBlank(row[description]),
        'repeat': repeat is int && repeat > 0
            ? repeat
            : statedAthkarRepeat(text) ?? 1,
        'reference': _nonBlank(row[reference]),
        'amenKey': 'dhikr:$id',
      };
      cat.items.add(item);
      dhikr[id] = item;
      searchText[id] = normalizeArabic(text);
    }
    final categories = byRawName.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return OfflineAthkar._(categories, dhikr, searchText);
  }

  static String? _nonBlank(Object? value) {
    final text = (value as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  final List<_Category> _categories;
  final Map<int, Map<String, dynamic>> _dhikr;
  final Map<int, String> _searchText;

  _Category? _byName(String nameAr) =>
      _categories.where((c) => c.nameAr == nameAr).firstOrNull;

  /// Same entries as GET /athkar/categories (sorted, optionally filtered).
  List<Map<String, dynamic>> categories({bool? featured}) => [
    for (final c in _categories)
      if (featured == null || c.featured == featured)
        {
          'id': c.id,
          'slug': c.slug,
          'nameAr': c.nameAr,
          'featured': c.featured,
          'count': c.items.length,
        },
  ];

  /// Same map as GET /athkar/categories/:slug, or null when unknown.
  Map<String, dynamic>? category(String slug) {
    final c = _categories.where((c) => c.slug == slug).firstOrNull;
    if (c == null) return null;
    return {
      'id': c.id,
      'slug': c.slug,
      'nameAr': c.nameAr,
      'totalRepeats': c.items.fold<int>(0, (s, d) => s + (d['repeat'] as int)),
      'items': [for (final d in c.items) Map<String, dynamic>.of(d)],
    };
  }

  Map<String, dynamic>? dhikr(int id) {
    final d = _dhikr[id];
    return d == null ? null : Map<String, dynamic>.of(d);
  }

  /// Same results as GET /athkar/search: every term must appear in the
  /// normalized dhikr text; ordered by category id then position.
  List<Map<String, dynamic>> search(String query, {int limit = 20}) {
    final terms = searchTerms(query);
    if (terms.isEmpty) return const [];
    final byId = {for (final c in _categories) c.id: c};
    final results = <Map<String, dynamic>>[];
    // Ids are assigned in category-id then sort order.
    for (final id in _dhikr.keys) {
      final text = _searchText[id]!;
      if (!terms.every(text.contains)) continue;
      final d = _dhikr[id]!;
      final cat = byId[d['categoryId']]!;
      results.add({
        ...d,
        'category': {'slug': cat.slug, 'nameAr': cat.nameAr},
      });
      if (results.length >= limit) break;
    }
    return results;
  }

  /// Same entries as GET /duas/collections.
  List<Map<String, dynamic>> duaCollectionList() => [
    for (final c in duaCollections)
      {
        'slug': c.slug,
        'nameAr': c.nameAr,
        'count':
            c.verses.length +
            c.categories.fold<int>(
              0,
              (s, name) => s + (_byName(name)?.items.length ?? 0),
            ),
      },
  ];

  /// Same map as GET /duas/collections/:slug; verse text comes from the local
  /// mushaf and "آمين" counts from [amenCounts]. Null when [slug] is unknown.
  Map<String, dynamic>? duaCollection(
    String slug,
    QuranData quran, {
    Map<String, int> amenCounts = const {},
  }) {
    final c = duaCollections.where((c) => c.slug == slug).firstOrNull;
    if (c == null) return null;
    final items = <Map<String, dynamic>>[
      for (final range in c.verses)
        {
          'kind': 'verse',
          ...resolveVerseRange(quran, range),
          'virtue': null,
          'repeat': 1,
        },
      for (final name in c.categories)
        for (final d
            in (_byName(name) ??
                    (throw StateError('Athkar category "$name" not found')))
                .items)
          {'kind': 'dhikr', ...d, 'repeat': math.max(1, d['repeat'] as int)},
    ];
    return {
      'slug': c.slug,
      'nameAr': c.nameAr,
      'items': [
        for (final i in items)
          {...i, 'amenCount': amenCounts[i['amenKey']] ?? 0},
      ],
    };
  }

  /// Resolves "17:24" or "3:193-194" against [quran] (backend
  /// resolveVerseRange): ayahs joined with ' ۝ ' plus "سورة X - آية N".
  static Map<String, dynamic> resolveVerseRange(QuranData quran, String range) {
    final m = RegExp(r'^(\d+):(\d+)(?:-(\d+))?$').firstMatch(range);
    if (m == null) throw ArgumentError.value(range, 'range');
    final surahId = int.parse(m[1]!);
    final from = int.parse(m[2]!);
    final to = int.parse(m[3] ?? m[2]!);
    final ayahs = [
      for (var n = from; n <= to; n++)
        quran.ayah('$surahId:$n') ??
            (throw StateError('Verse $surahId:$n not found')),
    ];
    final surah = quran.surahs.firstWhere((s) => s['id'] == surahId);
    final numbers = from == to ? 'آية $from' : 'الآيات $from-$to';
    return {
      'verseRange': range,
      'text': ayahs.map((a) => a['text'] as String).join(' ۝ '),
      'reference': 'سورة ${surah['nameAr']} - $numbers',
      'amenKey': 'verse:$range',
    };
  }
}

final _diacritics = RegExp(
  '[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u08D3-\u08FF]',
);

/// Port of normalizeArabic() in backend/src/lib/arabic.ts.
String normalizeArabic(String input) => input
    .replaceAll(_diacritics, '')
    .replaceAll('\u0640', '')
    .replaceAll(RegExp('[\u0622\u0623\u0625\u0671\u0672\u0673]'), '\u0627')
    .replaceAll('\u0649', '\u064A')
    .replaceAll('\u0629', '\u0647')
    .replaceAll('\u0624', '\u0648')
    .replaceAll('\u0626', '\u064A')
    .replaceAll(RegExp(r'[^\u0621-\u064A0-9a-zA-Z\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

/// Port of searchTerms() in backend/src/lib/arabic.ts.
List<String> searchTerms(String query) {
  final words = normalizeArabic(query).split(' ').where((w) => w.isNotEmpty);
  final terms = words.map(
    (w) => w.startsWith('ال') && w.length >= 5 ? w.substring(2) : w,
  );
  return terms.where((t) => t.length >= 2).toSet().toList();
}

/// On-device replacement for the athkar/dua user endpoints, kept in
/// SharedPreferences. Daily state (athkar progress, dua reads) is stored for
/// the current local date only and starts empty on a new day.
class OfflineAthkarStore {
  OfflineAthkarStore._();

  static const progressKey = 'fadl.offline.athkarProgress';
  static const amenKey = 'fadl.offline.duaAmen';
  static const readsKey = 'fadl.offline.duaReads';
  static const dedicationsKey = 'fadl.offline.dedications';
  static const personalDuasKey = 'fadl.offline.personalDuas';

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _readMap(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return {};
    }
  }

  /// `{key: int}` stored for [today], or empty for another day.
  static Map<String, int> _daily(
    SharedPreferences prefs,
    String key,
    String today,
  ) {
    final stored = _readMap(prefs, key);
    if (stored['date'] != today) return {};
    return {
      for (final e in ((stored['counts'] as Map?) ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    };
  }

  static Future<void> _writeDaily(
    SharedPreferences prefs,
    String key,
    String today,
    Map<String, int> counts,
  ) => prefs.setString(key, jsonEncode({'date': today, 'counts': counts}));

  // ───────────── Athkar progress ─────────────

  /// Same map as GET /me/athkar/progress.
  static Future<Map<String, dynamic>> progress(
    OfflineAthkar data, {
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = ymd(now ?? DateTime.now());
    final counts = {
      for (final e in _daily(prefs, progressKey, today).entries)
        int.parse(e.key): e.value,
    };
    return {
      'date': today,
      'categories': [
        for (final c in data._categories)
          if (c.featured) _categoryProgress(c, counts),
      ],
      'items': [
        for (final e in counts.entries) {'dhikrId': e.key, 'count': e.value},
      ],
    };
  }

  static Map<String, dynamic> _categoryProgress(
    _Category c,
    Map<int, int> counts,
  ) {
    final total = c.items.length;
    final completed = c.items
        .where((i) => (counts[i['id']] ?? 0) >= (i['repeat'] as int))
        .length;
    return {
      'slug': c.slug,
      'nameAr': c.nameAr,
      'total': total,
      'completed': completed,
      'percent': total == 0 ? 0 : (completed * 100) ~/ total,
      'status': completed == 0
          ? 'NOT_STARTED'
          : completed == total
          ? 'COMPLETED'
          : 'PARTIAL',
    };
  }

  /// Same as PUT /me/athkar/progress: sets today's absolute count.
  static Future<Map<String, dynamic>> setProgress(
    OfflineAthkar data,
    int dhikrId,
    int count, {
    DateTime? now,
  }) async {
    final dhikr = data._dhikr[dhikrId];
    if (dhikr == null) throw ArgumentError.value(dhikrId, 'dhikrId');
    final value = count.clamp(0, 10000);
    final prefs = await SharedPreferences.getInstance();
    final today = ymd(now ?? DateTime.now());
    final counts = _daily(prefs, progressKey, today);
    if (value == 0) {
      counts.remove('$dhikrId');
    } else {
      counts['$dhikrId'] = value;
    }
    await _writeDaily(prefs, progressKey, today, counts);
    final repeat = dhikr['repeat'] as int;
    return {
      'dhikrId': dhikrId,
      'count': value,
      'repeat': repeat,
      'done': value >= repeat,
    };
  }

  // ───────────── Duas: آمين and repeat counters ─────────────

  /// Number of days "آمين" was said on each dua on this device.
  static Future<Map<String, int>> amenCounts() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final e in _readMap(prefs, amenKey).entries)
        e.key: ((e.value as Map)['count'] as num).toInt(),
    };
  }

  /// Same map as POST /duas/amen: counted once per dua per day.
  static Future<Map<String, dynamic>> sayAmen(
    String targetKey, {
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = ymd(now ?? DateTime.now());
    final all = _readMap(prefs, amenKey);
    final entry = Map<String, dynamic>.from(
      (all[targetKey] as Map?) ?? const {'count': 0},
    );
    final counted = entry['last'] != today;
    if (counted) {
      entry['count'] = (entry['count'] as num).toInt() + 1;
      entry['last'] = today;
      all[targetKey] = entry;
      await prefs.setString(amenKey, jsonEncode(all));
    }
    return {
      'targetKey': targetKey,
      'counted': counted,
      'amenCount': (entry['count'] as num).toInt(),
    };
  }

  /// Today's "قراءة n/repeat" counters per amenKey.
  static Future<Map<String, int>> reads({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    return _daily(prefs, readsKey, ymd(now ?? DateTime.now()));
  }

  static Future<void> setRead(String key, int count, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = ymd(now ?? DateTime.now());
    final counts = _daily(prefs, readsKey, today);
    if (count <= 0) {
      counts.remove(key);
    } else {
      counts[key] = count;
    }
    await _writeDaily(prefs, readsKey, today, counts);
  }

  // ───────────── إهداء الثواب ─────────────

  /// Records a dedication (POST /me/dedications) as per-type totals.
  static Future<void> dedicate(String type, {int amount = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    final all = _readMap(prefs, dedicationsKey);
    final entry = Map<String, dynamic>.from(
      (all[type] as Map?) ?? const {'count': 0, 'amount': 0},
    );
    entry['count'] = (entry['count'] as num).toInt() + 1;
    entry['amount'] = (entry['amount'] as num).toInt() + math.max(1, amount);
    all[type] = entry;
    await prefs.setString(dedicationsKey, jsonEncode(all));
  }

  /// Same fields as GET /me/dedications/stats, for this device only.
  static Future<Map<String, dynamic>> dedicationStats() async {
    final prefs = await SharedPreferences.getInstance();
    final byType = {
      for (final e in _readMap(prefs, dedicationsKey).entries)
        e.key: {
          'count': ((e.value as Map)['count'] as num).toInt(),
          'amount': ((e.value as Map)['amount'] as num).toInt(),
        },
    };
    return {
      'totalDedications': byType.values.fold<int>(
        0,
        (s, t) => s + (t['count'] as int),
      ),
      'byType': byType,
    };
  }

  // ───────────── Personal duas ─────────────

  static List<Map<String, dynamic>> _personal(SharedPreferences prefs) {
    final raw = prefs.getString(personalDuasKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();
  }

  /// Same list as GET /me/duas (newest first).
  static Future<List<Map<String, dynamic>>> personalDuas() async =>
      _personal(await SharedPreferences.getInstance());

  /// Same as POST /me/duas.
  static Future<Map<String, dynamic>> savePersonalDua(
    String text, {
    DateTime? now,
  }) async {
    final value = text.trim();
    if (value.length < 2 || value.length > 2000) {
      throw ArgumentError.value(text, 'text');
    }
    final random = math.Random.secure();
    final dua = {
      'id': List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
      'text': value,
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      personalDuasKey,
      jsonEncode([dua, ..._personal(prefs)]),
    );
    return dua;
  }

  /// Same as DELETE /me/duas/:id; false when the id is unknown.
  static Future<bool> deletePersonalDua(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final duas = _personal(prefs);
    final before = duas.length;
    duas.removeWhere((d) => d['id'] == id);
    if (duas.length == before) return false;
    await prefs.setString(personalDuasKey, jsonEncode(duas));
    return true;
  }
}
