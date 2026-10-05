import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'quran_data.dart';

/// A user-facing failure of a local operation (message is Arabic).
class LocalDataException implements Exception {
  LocalDataException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Device-only user data used when no backend is configured: tasbeeh dhikrs
/// and daily counts, khatma plans with their reading log, and bookmarks.
///
/// Every method returns the same map shapes as the matching `/me/...` API
/// response, so screens can switch source without changing their UI code.
class LocalUserData {
  LocalUserData({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static final LocalUserData instance = LocalUserData();

  final DateTime Function() _clock;

  static const _dhikrsKey = 'fadl.local.tasbeeh.dhikrs';
  static const _countsKey = 'fadl.local.tasbeeh.counts';
  static const _plansKey = 'fadl.local.khatma.plans';
  static const _logsKey = 'fadl.local.khatma.logs';
  static const _bookmarksKey = 'fadl.local.bookmarks';

  static const mushafPages = 604;
  static const _dailyPrayers = 5;

  /// Same defaults as a new server account.
  static const defaultDhikrs = [
    ('سُبْحَانَ اللَّهِ', 33),
    ('الْحَمْدُ لِلَّهِ', 33),
    ('اللَّهُ أَكْبَرُ', 34),
    ('لَا إِلَٰهَ إِلَّا اللَّهُ', 100),
    ('أَسْتَغْفِرُ اللَّهَ', 70),
    ('اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ', 100),
  ];

  /// Same presets as `GET /khatma/presets`.
  static final List<Map<String, dynamic>> khatmaPresets = [
    for (final (key, title, days, count) in const [
      ('30-days', 'ختمة في شهر', 30, 1),
      ('60-days', 'ختمة في شهرين', 60, 1),
      ('ramadan-double', 'ختمتان في رمضان', 30, 2),
      ('15-days', 'ختمة في ١٥ يوماً', 15, 1),
      ('7-days', 'ختمة في أسبوع', 7, 1),
    ])
      () {
        final perDay = (mushafPages * count / days).ceil();
        return <String, dynamic>{
          'key': key,
          'title': title,
          'durationDays': days,
          'khatmaCount': count,
          'pagesPerDay': perDay,
          'pagesPerPrayer': (perDay / _dailyPrayers).ceil(),
        };
      }(),
  ];

  // ───────────────────────────── Helpers ─────────────────────────────

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _date(String ymd) {
    final p = ymd.split('-').map(int.parse).toList();
    return DateTime.utc(p[0], p[1], p[2]);
  }

  static DateTime _addDays(DateTime d, int days) =>
      DateTime.utc(d.year, d.month, d.day + days);

  static int _diffDays(DateTime a, DateTime b) => DateTime.utc(
    a.year,
    a.month,
    a.day,
  ).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

  DateTime get _today {
    final now = _clock();
    return DateTime.utc(now.year, now.month, now.day);
  }

  static String _id() {
    final r = math.Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static Future<List<Map<String, dynamic>>> _readList(String key) async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          Map<String, dynamic>.from(e as Map),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(String key, Object value) async =>
      (await SharedPreferences.getInstance()).setString(key, jsonEncode(value));

  // ───────────────────────────── Tasbeeh ─────────────────────────────

  Future<List<Map<String, dynamic>>> _dhikrs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_dhikrsKey)) {
      final seeded = [
        for (final (text, target) in defaultDhikrs)
          {'id': _id(), 'text': text, 'target': target},
      ];
      await _write(_dhikrsKey, seeded);
      return seeded;
    }
    return _readList(_dhikrsKey);
  }

  /// `{ 'YYYY-MM-DD': { dhikrId: count } }`
  Future<Map<String, Map<String, int>>> _counts() async {
    final raw = (await SharedPreferences.getInstance()).getString(_countsKey);
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map).entries)
          e.key as String: {
            for (final c in (e.value as Map).entries)
              c.key as String: (c.value as num).toInt(),
          },
      };
    } catch (_) {
      return {};
    }
  }

  /// Keeps one year of history, like the server summary window.
  Future<void> _saveCounts(Map<String, Map<String, int>> counts) async {
    final oldest = ymd(_addDays(_today, -366));
    counts.removeWhere(
      (day, byDhikr) => day.compareTo(oldest) < 0 || byDhikr.isEmpty,
    );
    await _write(_countsKey, counts);
  }

  /// Same shape as `GET /me/tasbeeh`.
  Future<Map<String, dynamic>> tasbeehSummary({int dailyGoal = 100}) async {
    final dhikrs = await _dhikrs();
    final counts = await _counts();
    final today = _today;
    final todayKey = ymd(today);
    final todayCounts = counts[todayKey] ?? const <String, int>{};
    int total(String day) =>
        (counts[day]?.values ?? const <int>[]).fold(0, (a, b) => a + b);
    final todayTotal = total(todayKey);
    var cursor = todayTotal > 0 ? today : _addDays(today, -1);
    var streak = 0;
    while (total(ymd(cursor)) > 0) {
      streak++;
      cursor = _addDays(cursor, -1);
    }
    final goal = dailyGoal < 1 ? 100 : dailyGoal;
    return {
      'date': todayKey,
      'dailyGoal': goal,
      'todayTotal': todayTotal,
      'goalPercent': math.min(100, (todayTotal / goal * 100).floor()),
      'streakDays': streak,
      'week': [
        for (var i = -6; i <= 0; i++)
          {
            'date': ymd(_addDays(today, i)),
            'total': total(ymd(_addDays(today, i))),
          },
      ],
      'dhikrs': [
        for (final d in dhikrs)
          () {
            final count = todayCounts[d['id']] ?? 0;
            final target = d['target'] as int;
            return {
              ...d,
              'todayCount': count,
              'rounds': count ~/ target,
              'remainingInRound': target - count % target,
            };
          }(),
      ],
    };
  }

  /// Adds today's taps per dhikr id; unknown ids are ignored.
  Future<Map<String, dynamic>> addTasbeehCounts(
    Map<String, int> byDhikr, {
    int dailyGoal = 100,
  }) async {
    final ids = (await _dhikrs()).map((d) => d['id']).toSet();
    final counts = await _counts();
    final today = counts.putIfAbsent(ymd(_today), () => {});
    for (final e in byDhikr.entries) {
      if (e.value > 0 && ids.contains(e.key)) {
        today[e.key] = (today[e.key] ?? 0) + e.value;
      }
    }
    await _saveCounts(counts);
    return tasbeehSummary(dailyGoal: dailyGoal);
  }

  /// "تصفير": removes today's count of one dhikr.
  Future<void> resetTasbeehToday(String dhikrId) async {
    final counts = await _counts();
    counts[ymd(_today)]?.remove(dhikrId);
    await _saveCounts(counts);
  }

  Future<Map<String, dynamic>> addDhikr(String text, int target) async {
    final value = text.trim();
    if (value.isEmpty) throw LocalDataException('نص الذكر مطلوب');
    final dhikr = {
      'id': _id(),
      'text': value,
      'target': target.clamp(1, 10000),
    };
    await _write(_dhikrsKey, [...await _dhikrs(), dhikr]);
    return dhikr;
  }

  Future<Map<String, dynamic>> updateDhikr(
    String id, {
    String? text,
    int? target,
  }) async {
    final dhikrs = await _dhikrs();
    final index = dhikrs.indexWhere((d) => d['id'] == id);
    if (index < 0) throw LocalDataException('الذكر غير موجود');
    final value = text?.trim();
    dhikrs[index] = {
      ...dhikrs[index],
      if (value != null && value.isNotEmpty) 'text': value,
      if (target != null) 'target': target.clamp(1, 10000),
    };
    await _write(_dhikrsKey, dhikrs);
    return dhikrs[index];
  }

  /// Removes the dhikr and its counts (as the server cascade does).
  Future<void> deleteDhikr(String id) async {
    final dhikrs = await _dhikrs();
    await _write(_dhikrsKey, dhikrs.where((d) => d['id'] != id).toList());
    final counts = await _counts();
    for (final day in counts.values) {
      day.remove(id);
    }
    await _saveCounts(counts);
  }

  // ───────────────────────────── Khatma ─────────────────────────────

  /// Port of the server's `computeProgress` (backend/src/modules/khatma/plan.ts).
  static Map<String, dynamic> khatmaProgress({
    required int khatmaCount,
    required int durationDays,
    required DateTime startDate,
    required int currentPage,
    required DateTime today,
    required int pagesReadToday,
  }) {
    final totalPages = mushafPages * khatmaCount;
    final pagesRead = math.min(currentPage - 1, totalPages);
    final remainingPages = totalPages - pagesRead;
    final endDate = _addDays(startDate, durationDays - 1);
    final dayIndex = math.max(0, _diffDays(today, startDate));
    final daysLeft = math.max(1, durationDays - dayIndex);
    final remainingAtStartOfDay = remainingPages + pagesReadToday;
    final dailyTarget = remainingPages == 0
        ? 0
        : (remainingAtStartOfDay / daysLeft).ceil();
    final todayRemaining = math.max(0, dailyTarget - pagesReadToday);
    final expectedByEndOfToday = math.min(
      totalPages,
      (totalPages * math.min(dayIndex + 1, durationDays) / durationDays).ceil(),
    );
    return {
      'totalPages': totalPages,
      'pagesRead': pagesRead,
      'remainingPages': remainingPages,
      'remainingJuz': (remainingPages / 20 * 10).round() / 10,
      'percent': (pagesRead / totalPages * 100).floor(),
      'startDate': ymd(startDate),
      'endDate': ymd(endDate),
      'dayNumber': math.min(dayIndex + 1, durationDays),
      'daysLeft': remainingPages == 0 ? 0 : daysLeft,
      'overdue': _diffDays(today, endDate) > 0 && remainingPages > 0,
      'currentKhatma': math.min(pagesRead ~/ mushafPages + 1, khatmaCount),
      'nextPage': remainingPages == 0
          ? null
          : (currentPage - 1) % mushafPages + 1,
      'today': {
        'target': dailyTarget,
        'read': pagesReadToday,
        'remaining': todayRemaining,
        'perPrayer': (dailyTarget / _dailyPrayers).ceil(),
        'done': dailyTarget > 0 && todayRemaining == 0,
      },
      'scheduleDelta': pagesRead - expectedByEndOfToday,
    };
  }

  Future<Map<String, dynamic>> _serialize(
    Map<String, dynamic> plan,
    List<Map<String, dynamic>> logs,
  ) async {
    final today = _today;
    final todayKey = ymd(today);
    final readToday = logs
        .where((l) => l['planId'] == plan['id'] && l['date'] == todayKey)
        .fold<int>(0, (s, l) => s + (l['pages'] as int));
    final progress = khatmaProgress(
      khatmaCount: plan['khatmaCount'] as int,
      durationDays: plan['durationDays'] as int,
      startDate: _date(plan['startDate'] as String),
      currentPage: plan['currentPage'] as int,
      today: today,
      pagesReadToday: readToday,
    );
    Map<String, dynamic>? position;
    final nextPage = progress['nextPage'] as int?;
    if (nextPage != null) {
      try {
        final quran = await QuranData.load();
        final first = (quran.page(nextPage)['ayahs'] as List).first as Map;
        position = {
          'page': nextPage,
          'ayahKey': first['key'],
          'surahNameAr': quran.surahs[(first['surahId'] as int) - 1]['nameAr'],
          'juz': first['juz'],
        };
      } catch (_) {
        position = null;
      }
    }
    return {
      'id': plan['id'],
      'title': plan['title'],
      'status': plan['status'],
      'khatmaCount': plan['khatmaCount'],
      'durationDays': plan['durationDays'],
      'reminderTime': plan['reminderTime'],
      'dedicated': plan['dedicated'] == true,
      'createdAt': plan['createdAt'],
      ...progress,
      'position': position,
    };
  }

  /// Same shape as `GET /me/khatmas` → `plans`, newest first.
  Future<List<Map<String, dynamic>>> khatmas({String? status}) async {
    final plans = await _readList(_plansKey);
    final logs = await _readList(_logsKey);
    final selected =
        plans.where((p) => status == null || p['status'] == status).toList()
          ..sort(
            (a, b) =>
                (b['createdAt'] as String).compareTo(a['createdAt'] as String),
          );
    return [for (final p in selected) await _serialize(p, logs)];
  }

  /// Starts a plan from a preset; any other active plan is archived.
  Future<Map<String, dynamic>> createKhatma({
    required String preset,
    String? reminderTime,
    bool dedicated = false,
    int startPage = 1,
  }) async {
    final p = khatmaPresets.firstWhere(
      (e) => e['key'] == preset,
      orElse: () => throw LocalDataException('خطة غير معروفة'),
    );
    final plans = [
      for (final plan in await _readList(_plansKey))
        plan['status'] == 'ACTIVE' ? {...plan, 'status': 'ARCHIVED'} : plan,
    ];
    final plan = <String, dynamic>{
      'id': _id(),
      'title': p['title'],
      'status': 'ACTIVE',
      'khatmaCount': p['khatmaCount'],
      'durationDays': p['durationDays'],
      'startDate': ymd(_today),
      'currentPage': startPage.clamp(1, mushafPages),
      'reminderTime': reminderTime,
      'dedicated': dedicated,
      'createdAt': _clock().toUtc().toIso8601String(),
    };
    await _write(_plansKey, [...plans, plan]);
    return _serialize(plan, await _readList(_logsKey));
  }

  Future<(List<Map<String, dynamic>>, int)> _plan(String id) async {
    final plans = await _readList(_plansKey);
    final index = plans.indexWhere((p) => p['id'] == id);
    if (index < 0) throw LocalDataException('الختمة غير موجودة');
    return (plans, index);
  }

  /// Updates `title`, `reminderTime`, `dedicated` or `status`.
  Future<Map<String, dynamic>> patchKhatma(
    String id,
    Map<String, Object?> patch,
  ) async {
    final (plans, index) = await _plan(id);
    const allowed = {'title', 'reminderTime', 'dedicated', 'status'};
    if (patch['status'] == 'ACTIVE') {
      for (var i = 0; i < plans.length; i++) {
        if (i != index && plans[i]['status'] == 'ACTIVE') {
          plans[i] = {...plans[i], 'status': 'ARCHIVED'};
        }
      }
    }
    plans[index] = {
      ...plans[index],
      for (final e in patch.entries)
        if (allowed.contains(e.key)) e.key: e.value,
    };
    await _write(_plansKey, plans);
    return _serialize(plans[index], await _readList(_logsKey));
  }

  /// Records either [pages] read now or [toPage] (last mushaf page finished
  /// in the current khatma). Same result shape as the progress endpoint.
  Future<Map<String, dynamic>> recordKhatma(
    String id, {
    int? pages,
    int? toPage,
  }) async {
    if ((pages == null) == (toPage == null)) {
      throw LocalDataException('حدد عدد الصفحات أو الصفحة التي وصلت إليها');
    }
    final (plans, index) = await _plan(id);
    final plan = plans[index];
    if (plan['status'] != 'ACTIVE') {
      throw LocalDataException('لا يمكن التسجيل إلا في ختمة نشطة');
    }
    final current = plan['currentPage'] as int;
    final totalPages = mushafPages * (plan['khatmaCount'] as int);
    var count = pages ?? 0;
    if (toPage != null) {
      if (toPage < 1 || toPage > mushafPages) {
        throw LocalDataException('رقم الصفحة يجب أن يكون بين ١ و٦٠٤');
      }
      final offset = (current - 1) ~/ mushafPages * mushafPages;
      count = offset + toPage + 1 - current;
      if (count <= 0) throw LocalDataException('سبق تسجيل هذه الصفحة');
    }
    count = math.min(count, totalPages - (current - 1));
    if (count <= 0) throw LocalDataException('اكتملت هذه الختمة');

    final next = current + count;
    final completed = next > totalPages;
    final logs = await _readList(_logsKey);
    logs.add({
      'planId': id,
      'date': ymd(_today),
      'fromPage': current,
      'toPage': next - 1,
      'pages': count,
      'createdAt': _clock().toUtc().toIso8601String(),
    });
    plans[index] = {
      ...plan,
      'currentPage': next,
      'status': completed ? 'COMPLETED' : 'ACTIVE',
    };
    await _write(_logsKey, logs);
    await _write(_plansKey, plans);
    return {
      'recordedPages': count,
      'completed': completed,
      'plan': await _serialize(plans[index], logs),
    };
  }

  /// Same shape as `GET /me/khatmas/{id}/logs` → `days`, newest first.
  Future<List<Map<String, dynamic>>> khatmaLogs(String id) async {
    final logs = (await _readList(
      _logsKey,
    )).where((l) => l['planId'] == id).toList().reversed;
    final days = <String, Map<String, dynamic>>{};
    for (final log in logs) {
      final day = days.putIfAbsent(
        log['date'] as String,
        () => {'date': log['date'], 'pages': 0, 'entries': <Map>[]},
      );
      day['pages'] = (day['pages'] as int) + (log['pages'] as int);
      (day['entries'] as List).add(log);
    }
    return days.values.toList();
  }

  Future<void> deleteKhatma(String id) async {
    final plans = await _readList(_plansKey);
    await _write(_plansKey, plans.where((p) => p['id'] != id).toList());
    final logs = await _readList(_logsKey);
    await _write(_logsKey, logs.where((l) => l['planId'] != id).toList());
  }

  // ───────────────────────────── Bookmarks ─────────────────────────────

  /// Saved ayahs (`{ayahKey, note?, createdAt}`), newest first.
  Future<List<Map<String, dynamic>>> bookmarks() async =>
      (await _readList(_bookmarksKey)).reversed.toList();

  Future<bool> isBookmarked(String ayahKey) async =>
      (await _readList(_bookmarksKey)).any((b) => b['ayahKey'] == ayahKey);

  /// Adds (or refreshes) a bookmark; re-saving moves it to the top.
  Future<void> addBookmark(String ayahKey, {String? note}) async {
    if (!RegExp(r'^\d{1,3}:\d{1,3}$').hasMatch(ayahKey)) {
      throw LocalDataException('مرجع الآية غير صالح');
    }
    final list = (await _readList(
      _bookmarksKey,
    )).where((b) => b['ayahKey'] != ayahKey).toList();
    list.add({
      'ayahKey': ayahKey,
      'note': ?note,
      'createdAt': _clock().toUtc().toIso8601String(),
    });
    await _write(_bookmarksKey, list);
  }

  Future<void> removeBookmark(String ayahKey) async {
    final list = await _readList(_bookmarksKey);
    await _write(
      _bookmarksKey,
      list.where((b) => b['ayahKey'] != ayahKey).toList(),
    );
  }

  // ───────────────────────────── All ─────────────────────────────

  /// "حذف بياناتي" for the local store; default dhikrs return on next use.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _dhikrsKey,
      _countsKey,
      _plansKey,
      _logsKey,
      _bookmarksKey,
    ]) {
      await prefs.remove(key);
    }
  }
}
