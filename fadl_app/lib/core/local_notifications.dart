import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import 'adhan_service.dart';
import 'api.dart';
import 'app_state.dart';
import 'dhikr_reminders.dart';
import 'format.dart';
import 'offline_prayer.dart';
import 'quran_learning.dart';

/// Schedules local adhan and reminder notifications, using the backend
/// when configured and locally computed times otherwise.
/// Never throws to callers.
class LocalNotifications {
  LocalNotifications._();
  static final LocalNotifications instance = LocalNotifications._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static const _adhanChannel = AndroidNotificationChannel(
    'adhan',
    'الأذان',
    description: 'تنبيهات دخول وقت الصلاة',
    importance: Importance.max,
  );
  static const _remindersChannel = AndroidNotificationChannel(
    'reminders',
    'التذكيرات',
    description: 'أذكار الصباح والمساء والسنن ووِرد الختمة',
    importance: Importance.defaultImportance,
  );

  bool _initialized = false;
  bool _exactAllowed = false;
  Future<void>? _initFuture;
  Future<void>? _running;

  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      tzdata.initializeTimeZones();
      await _setLocalLocation();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.createNotificationChannel(_adhanChannel);
        await android.createNotificationChannel(_remindersChannel);
        await android.requestNotificationsPermission();
        await _refreshExactAllowed();
      }
      _initialized = true;
    } catch (e) {
      debugPrint('LocalNotifications.init failed: $e');
    }
  }

  /// Exact alarms need the user's "Alarms & reminders" grant on Android 14+;
  /// without it reminders are scheduled inexactly.
  Future<void> _refreshExactAllowed() async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    _exactAllowed = await android.canScheduleExactNotifications() ?? false;
  }

  Future<void> _setLocalLocation() async {
    String name = 'UTC';
    try {
      name = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {}
    try {
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  /// Cancels everything and schedules the next 48 hours on the device.
  Future<void> reschedule(AppState state) {
    // Serialize concurrent calls (several settings toggles in a row).
    final next = (_running ?? Future<void>.value()).then(
      (_) => _reschedule(state),
    );
    _running = next;
    return next;
  }

  Future<void> _reschedule(AppState state) async {
    try {
      await init();
      if (!_initialized) return;
      // The user may grant or revoke exact alarms at any time.
      await _refreshExactAllowed();
      final now = DateTime.now().toUtc();
      List<Map<String, dynamic>>? items;
      if (Api.hasBackend) {
        try {
          final res =
              await Api.instance.get('/me/notifications/upcoming', {
                    'hours': 48,
                  })
                  as Map<String, dynamic>;
          items = (res['notifications'] as List? ?? const [])
              .cast<Map<String, dynamic>>()
              .toList();
        } catch (e) {
          // Offline-first: fall back to locally computed times so device-only
          // reminders still reflect the latest state.
          debugPrint('LocalNotifications: backend schedule failed: $e');
        }
      }
      items ??= state.hasLocation
          ? offlineUpcoming(state, DateTime.now())
          : <Map<String, dynamic>>[];
      // Review progress lives only on this device, so these reminders are
      // added locally whether or not a backend supplies the rest.
      items.addAll(await _reviewUpcoming(state, now));
      items.addAll(_dhikrUpcoming(state, now));
      // Adhan-mode prayers play the full adhan through native alarms on
      // Android and get no plugin notification; elsewhere they stay here.
      final adhan = AdhanService.instance;
      var split = partitionAdhan(
        items,
        state.notifications,
        now,
        android: adhan.supported,
        dua: adhan.supported ? await loadAdhanDua() : null,
      );
      await plugin.cancelAll();
      try {
        await adhan.schedule(split.native);
      } catch (e) {
        // Without native alarms, keep at least the plugin notification.
        debugPrint('LocalNotifications: adhan alarms failed: $e');
        split = partitionAdhan(items, state.notifications, now, android: false);
      }
      // iOS drops every pending notification beyond the 64 soonest.
      final pending = defaultTargetPlatform == TargetPlatform.iOS
          ? capPending(split.plugin, iosPendingLimit)
          : split.plugin;
      for (final n in pending) {
        final fireAt = DateTime.tryParse('${n['fireAt']}')?.toUtc();
        if (fireAt == null || !fireAt.isAfter(now)) continue;
        final isAdhan = n['type'] == 'adhan';
        final channel = isAdhan ? _adhanChannel : _remindersChannel;
        try {
          await plugin.zonedSchedule(
            id: _stableId('${n['key']}'),
            title: n['title'] as String?,
            body: n['body'] as String?,
            payload: n['link'] as String?,
            // fireAt is an absolute instant, so UTC is exact regardless of the device zone.
            scheduledDate: tz.TZDateTime.from(fireAt, tz.UTC),
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                importance: channel.importance,
                priority: isAdhan ? Priority.max : Priority.defaultPriority,
                category: isAdhan
                    ? AndroidNotificationCategory.alarm
                    : AndroidNotificationCategory.reminder,
                // Show a whole dhikr and its source, not one cut-off line.
                styleInformation: n['type'] == 'dhikr'
                    ? BigTextStyleInformation('${n['body']}')
                    : null,
              ),
              iOS: const DarwinNotificationDetails(),
            ),
            androidScheduleMode: _exactAllowed
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
          );
        } catch (e) {
          debugPrint('LocalNotifications: failed to schedule ${n['key']}: $e');
        }
      }
    } catch (e) {
      debugPrint('LocalNotifications.reschedule failed: $e');
    }
  }

  /// Most notifications iOS keeps pending per app.
  static const iosPendingLimit = 64;

  /// At most [limit] items, soonest first, with every prayer kept ahead of
  /// reminders so a busy dhikr schedule never pushes an adhan out.
  @visibleForTesting
  static List<Map<String, dynamic>> capPending(
    List<Map<String, dynamic>> items,
    int limit,
  ) {
    DateTime at(Map item) =>
        DateTime.tryParse('${item['fireAt']}') ?? DateTime(9999);
    final sorted = [...items]..sort((a, b) => at(a).compareTo(at(b)));
    final prayers = [
      for (final item in sorted)
        if (item['type'] == 'adhan') item,
    ];
    final kept = {
      ...prayers.take(limit),
      for (final item in sorted)
        if (item['type'] != 'adhan') item,
    }.take(limit).toList();
    return kept..sort((a, b) => at(a).compareTo(at(b)));
  }

  static Future<List<Map<String, dynamic>>> _reviewUpcoming(
    AppState state,
    DateTime now,
  ) async {
    final time = state.notifications['quranReviewTime'] as String?;
    if (time == null || state.notifications['enabled'] == false) return [];
    try {
      final store = QuranReviewStore(await SharedPreferences.getInstance())
        ..load();
      return reviewReminders(
        time: time,
        location: OfflinePrayer.location(state.timezone),
        now: now,
        dueAt: store.dueCount,
        l: lookupAppLocalizations(state.locale),
      );
    } catch (e) {
      debugPrint('LocalNotifications: review reminders failed: $e');
      return [];
    }
  }

  static List<Map<String, dynamic>> _dhikrUpcoming(
    AppState state,
    DateTime now,
  ) {
    final hours = (state.notifications['dhikrReminderHours'] as num?)?.toInt();
    if (hours == null ||
        !dhikrReminderIntervals.contains(hours) ||
        state.notifications['enabled'] == false) {
      return [];
    }
    try {
      return dhikrReminderItems(
        intervalHours: hours,
        location: OfflinePrayer.location(state.timezone),
        now: now,
        l: lookupAppLocalizations(state.locale),
      );
    } catch (e) {
      debugPrint('LocalNotifications: dhikr reminders failed: $e');
      return [];
    }
  }

  /// A dhikr every [intervalHours] from 08:00 until before 22:00 local time
  /// within 48 hours of [now]. Texts rotate through [dhikrReminders] by
  /// slot, so consecutive reminders differ and reschedules stay stable.
  @visibleForTesting
  static List<Map<String, dynamic>> dhikrReminderItems({
    required int intervalHours,
    required tz.Location location,
    required DateTime now,
    required AppLocalizations l,
  }) {
    final today = tz.TZDateTime.from(now, location);
    final end = now.add(const Duration(hours: 48));
    final items = <Map<String, dynamic>>[];
    for (var offset = 0; offset <= 2; offset++) {
      for (
        var hour = dhikrReminderStartHour;
        hour < dhikrReminderEndHour;
        hour += intervalHours
      ) {
        final at = tz.TZDateTime(
          location,
          today.year,
          today.month,
          today.day + offset,
          hour,
        );
        if (!at.isAfter(now) || at.isAfter(end)) continue;
        // Days since the epoch keep the rotation moving from day to day.
        final day = DateTime.utc(
          at.year,
          at.month,
          at.day,
        ).difference(DateTime.utc(1970)).inDays;
        final dhikr = dhikrReminders[(day * 24 + hour) % dhikrReminders.length];
        final date =
            '${at.year}-${'${at.month}'.padLeft(2, '0')}-${'${at.day}'.padLeft(2, '0')}';
        items.add({
          'key': 'dhikr:$date:$hour',
          'type': 'dhikr',
          'fireAt': at.toUtc().toIso8601String(),
          'title': l.dhikrReminderTitle,
          'body': '${dhikr.text}\n${dhikr.source}',
          'link': 'fadl://athkar',
        });
      }
    }
    return items;
  }

  /// Daily reminders at [time] ("HH:mm" in [location]) within 48 hours of
  /// [now], skipping days when [dueAt] reports no memorized page due by the
  /// end of that local day.
  @visibleForTesting
  static List<Map<String, dynamic>> reviewReminders({
    required String time,
    required tz.Location location,
    required DateTime now,
    required int Function(DateTime at) dueAt,
    required AppLocalizations l,
  }) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final today = tz.TZDateTime.from(now, location);
    final end = now.add(const Duration(hours: 48));
    final reminders = <Map<String, dynamic>>[];
    for (var offset = 0; offset <= 2; offset++) {
      final at = tz.TZDateTime(
        location,
        today.year,
        today.month,
        today.day + offset,
        hour,
        minute,
      );
      if (!at.isAfter(now) || at.isAfter(end)) continue;
      final endOfDay = tz.TZDateTime(
        location,
        at.year,
        at.month,
        at.day + 1,
      ).subtract(const Duration(milliseconds: 1));
      final due = dueAt(endOfDay);
      if (due <= 0) continue;
      final day =
          '${at.year}-${'${at.month}'.padLeft(2, '0')}-${'${at.day}'.padLeft(2, '0')}';
      reminders.add({
        'key': 'quran_review:$day',
        'type': 'quran_review',
        'fireAt': at.toUtc().toIso8601String(),
        'title': l.quranReviewNotificationTitle,
        'body': l.quranReviewNotificationBody(
          due,
          l.localeName == 'ar' ? arNum(due) : '$due',
        ),
        'link': 'fadl://quran/review',
      });
    }
    return reminders;
  }

  @visibleForTesting
  static List<Map<String, dynamic>> offlineUpcoming(
    AppState state,
    DateTime now,
  ) {
    if (state.notifications['enabled'] == false) return [];
    final start = OfflinePrayer.today(state.timezone, now);
    final end = now.add(const Duration(hours: 48));
    final upcoming = <Map<String, dynamic>>[];
    for (var offset = -1; offset <= 2; offset++) {
      final date = start.add(Duration(days: offset));
      final daily = OfflinePrayer.day(state.settings, date);
      final keyDate = daily['date'] as String;
      void add(
        String type,
        DateTime at,
        String title,
        String body,
        String link,
      ) {
        if (!at.isAfter(now) || at.isAfter(end)) return;
        upcoming.add({
          'key': '$type:$keyDate',
          'type': type.startsWith('adhan:') ? 'adhan' : type,
          'fireAt': at.toUtc().toIso8601String(),
          'title': title,
          'body': body,
          'link': link,
        });
      }

      final adhan = (state.notifications['adhan'] as Map?) ?? const {};
      final preMinutes =
          (state.notifications['preAlertMinutes'] as num?)?.toInt() ?? 15;
      final where = state.settings['locationName'] == null
          ? ''
          : ' حسب توقيت ${state.settings['locationName']}';
      final prayers = (daily['prayers'] as List).cast<Map<String, dynamic>>();
      for (final prayer in prayers) {
        final name = prayer['name'] as String;
        if (adhan[name] != true &&
            !(adhan[name] == null && name != 'sunrise')) {
          continue;
        }
        final time = DateTime.parse(prayer['time'] as String);
        final nameAr = prayer['nameAr'] as String;
        add(
          'adhan:$name',
          time,
          name == 'sunrise' ? 'حان وقت الشروق' : 'حان الآن وقت صلاة $nameAr',
          name == 'sunrise'
              ? 'انتهى وقت صلاة الفجر$where'
              : 'حيّ على الصلاة، حيّ على الفلاح$where',
          'fadl://prayer-times',
        );
        if (preMinutes > 0 && name != 'sunrise') {
          add(
            'pre_adhan:$name',
            time.subtract(Duration(minutes: preMinutes)),
            'اقترب وقت صلاة $nameAr',
            'بقي ${arabicMinutes(preMinutes)} على الأذان',
            'fadl://prayer-times',
          );
        }
      }
      final location = OfflinePrayer.location(state.timezone);
      void athkar(String setting, String type, String title, String body) {
        final hm = state.notifications[setting] as String?;
        if (hm == null) return;
        final parts = hm.split(':');
        final at = tz.TZDateTime(
          location,
          date.year,
          date.month,
          date.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        add(type, at, title, body, 'fadl://athkar/$type');
      }

      athkar(
        'morningAthkarTime',
        'morning',
        'أذكار الصباح',
        'ابدأ يومك بذكر الله، حصّن نفسك بأذكار الصباح',
      );
      athkar(
        'eveningAthkarTime',
        'evening',
        'أذكار المساء',
        'لا تنسَ أذكار المساء',
      );
      athkar(
        'sleepAthkarTime',
        'sleep',
        'أذكار النوم',
        'اختم يومك بأذكار النوم',
      );
      if (state.notifications['qiyamEnabled'] == true) {
        add(
          'qiyam',
          DateTime.parse((daily['lastThirdOfNight'] as Map)['time'] as String),
          'الثلث الأخير من الليل',
          'حان وقت قيام الليل والدعاء',
          'fadl://duas',
        );
      }
      DateTime prayerAt(String name) => DateTime.parse(
        prayers.firstWhere((prayer) => prayer['name'] == name)['time']
            as String,
      );
      if (state.notifications['duhaEnabled'] == true) {
        final sunrise = prayerAt('sunrise');
        add(
          'duha',
          sunrise.add(prayerAt('dhuhr').difference(sunrise) ~/ 2),
          'صلاة الضحى',
          'صلاة الأوّابين، ركعتان تجزئان عن صدقة كل مفصل',
          'fadl://home',
        );
      }
      final hijri = daily['hijri'] as Map<String, dynamic>;
      final nextHijri = OfflinePrayer.hijri(
        date.add(const Duration(days: 1)),
        (state.settings['hijriAdjustment'] as num?)?.toInt() ?? 0,
      );
      final nextMonth = nextHijri['month'] as int;
      final nextDay = nextHijri['day'] as int;
      final fastable =
          nextMonth != 9 &&
          !(nextMonth == 10 && nextDay == 1) &&
          !(nextMonth == 12 && nextDay >= 10 && nextDay <= 13);
      if (state.notifications['mondayThursdayFast'] == true &&
          (date.weekday == DateTime.sunday ||
              date.weekday == DateTime.wednesday) &&
          fastable) {
        add(
          'fast_mon_thu',
          prayerAt('isha'),
          date.weekday == DateTime.sunday ? 'غداً الاثنين' : 'غداً الخميس',
          'تُعرض الأعمال يومي الاثنين والخميس، فهل تنوي الصيام؟',
          'fadl://home',
        );
      }
      // In Dhul-Hijjah the 13th is a day of tashreeq, when fasting is
      // forbidden, so that month's white days start on the 14th.
      final dhulHijjah = hijri['month'] == 12;
      if (state.notifications['whiteDaysFast'] == true &&
          hijri['month'] != 9 &&
          hijri['day'] == (dhulHijjah ? 13 : 12)) {
        add(
          'fast_white_days',
          prayerAt('isha'),
          'الأيام البيض',
          dhulHijjah
              ? 'يبدأ غداً صيام الأيام البيض (١٤، ١٥ ${hijri['monthNameAr']})؛ أما الثالث عشر فمن أيام التشريق فلا يُصام'
              : 'تبدأ غداً الأيام البيض (١٣، ١٤، ١٥ ${hijri['monthNameAr']})، وصيامها كصيام الدهر',
          'fadl://home',
        );
      }
      if (date.weekday == DateTime.friday) {
        if (state.notifications['fridayKahf'] == true) {
          add(
            'friday_kahf',
            prayerAt('fajr').add(const Duration(minutes: 30)),
            'جمعة مباركة',
            'لا تنسَ قراءة سورة الكهف والإكثار من الصلاة على النبي ﷺ',
            'fadl://quran/surah/18',
          );
        }
        if (state.notifications['fridayHour'] == true) {
          // The last hour before maghrib, never before asr has begun.
          final lastHour = prayerAt(
            'maghrib',
          ).subtract(const Duration(hours: 1));
          final asr = prayerAt('asr');
          add(
            'friday_hour',
            lastHour.isBefore(asr) ? asr : lastHour,
            'ساعة الإجابة يوم الجمعة',
            'آخر ساعة بعد العصر من يوم الجمعة، أكثر من الدعاء',
            'fadl://duas',
          );
        }
      }
    }
    upcoming.sort(
      (a, b) => (a['fireAt'] as String).compareTo(b['fireAt'] as String),
    );
    return upcoming;
  }

  /// "٥ دقائق", "١٥ دقيقة": Arabic counted-noun agreement for [minutes].
  @visibleForTesting
  static String arabicMinutes(int minutes) => switch (minutes) {
    1 => 'دقيقة واحدة',
    2 => 'دقيقتان',
    >= 3 && <= 10 => '${arNum(minutes)} دقائق',
    _ => '${arNum(minutes)} دقيقة',
  };

  /// FNV-1a hash of the notification key, kept within a positive 31-bit int.
  static int _stableId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
