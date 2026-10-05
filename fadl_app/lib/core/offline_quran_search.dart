import 'offline_athkar.dart';
import 'quran_data.dart';

/// Searches bundled scripture and configured athkar without generating answers.
class OfflineQuranSearch {
  OfflineQuranSearch._(this._quran, this._athkar);

  static Future<OfflineQuranSearch>? _cached;

  static Future<OfflineQuranSearch> load() =>
      _cached ??= _read().catchError((Object error) {
        _cached = null;
        throw error;
      });

  static Future<OfflineQuranSearch> _read() async =>
      OfflineQuranSearch._(await QuranData.load(), await OfflineAthkar.load());

  static const disclaimer =
      'هذا بحث نصي موضعي في القرآن والأذكار المحفوظة، وليس فتوى أو إجابة من نموذج ذكاء اصطناعي. لا تتوفر الإجابات التوليدية دون اتصال بالخادم.';

  final QuranData _quran;
  final OfflineAthkar _athkar;

  Map<String, dynamic> search(String query, {int limit = 20}) {
    final terms = searchTerms(query);
    final surahs = <Map<String, dynamic>>[];
    final verses = <Map<String, dynamic>>[];
    if (terms.isNotEmpty && limit > 0) {
      for (final surah in _quran.surahs) {
        if (terms.every(normalizeArabic(surah['nameAr'] as String).contains)) {
          surahs.add(surah);
          if (surahs.length == limit) break;
        }
      }
      for (final surah in _quran.surahs) {
        if (surahs.length + verses.length >= limit) break;
        for (final ayah in _quran.surahAyahs(surah['id'] as int)) {
          if (terms.every(normalizeArabic(ayah['text'] as String).contains)) {
            verses.add({...ayah, 'surahNameAr': surah['nameAr']});
            if (surahs.length + verses.length >= limit) break;
          }
        }
      }
    }
    final remaining = limit - surahs.length - verses.length;
    return {
      'surahs': surahs,
      'verses': {'hits': verses},
      'athkar': terms.isEmpty || remaining <= 0
          ? <Map<String, dynamic>>[]
          : _athkar.search(query, limit: remaining),
    };
  }

  Map<String, dynamic> assistantResponse(String query) {
    final matches = search(query);
    return {
      'mode': 'offline-search',
      'answer':
          (matches['surahs'] as List).isEmpty &&
              ((matches['verses'] as Map<String, dynamic>)['hits'] as List)
                  .isEmpty &&
              (matches['athkar'] as List).isEmpty
          ? 'لا توجد نتائج نصية مطابقة في المصادر المحفوظة على جهازك.'
          : 'نتائج بحث نصي مطابق في المصادر المحفوظة على جهازك فقط.',
      'disclaimer': disclaimer,
      'sources': {
        'surahs': matches['surahs'],
        'verses': (matches['verses'] as Map<String, dynamic>)['hits'],
        'athkar': matches['athkar'],
      },
    };
  }
}
