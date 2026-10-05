import 'dart:convert';

import 'package:fadl/core/adhan_service.dart';
import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/local_notifications.dart';
import 'package:fadl/core/offline_athkar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pluginChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

Map<String, dynamic> _item(String key, DateTime at, {String? type}) => {
  'key': key,
  'type': type ?? key.split(':').first,
  'fireAt': at.toUtc().toIso8601String(),
  'title': 'title $key',
  'body': 'body $key',
  'link': 'fadl://prayer-times',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> adhanCalls;

  setUp(() {
    adhanCalls = [];
    messenger.setMockMethodCallHandler(AdhanService.channel, (call) async {
      adhanCalls.add(call);
      return switch (call.method) {
        'pickAndImport' => {
          'id': 'fajr_1.audio',
          'name': 'fajr.mp3',
          'kind': 'fajr',
        },
        'listImported' => [
          {'id': 'regular_2.audio', 'name': 'makkah.mp3', 'kind': 'regular'},
        ],
        'isIgnoringBatteryOptimizations' => false,
        _ => null,
      };
    });
  });

  tearDown(
    () => messenger.setMockMethodCallHandler(AdhanService.channel, null),
  );

  group('legacy migration', () {
    test('legacy true maps to adhan for dhuhr…isha, notify for fajr and '
        'sunrise; false maps to silent', () {
      final legacy = {
        'adhan': {
          'fajr': true,
          'sunrise': true,
          'dhuhr': true,
          'asr': true,
          'maghrib': true,
          'isha': true,
        },
      };
      expect(prayerMode(legacy, 'fajr'), 'notify');
      expect(prayerMode(legacy, 'sunrise'), 'notify');
      for (final p in ['dhuhr', 'asr', 'maghrib', 'isha']) {
        expect(prayerMode(legacy, p), 'adhan');
      }
      final off = {
        'adhan': {for (final p in prayerNames.keys) p: false},
      };
      for (final p in prayerNames.keys) {
        expect(prayerMode(off, p), 'silent');
      }
    });

    test('missing entries follow the old defaults; explicit modes apply '
        'only while the legacy flag is on', () {
      expect(prayerMode(const {}, 'sunrise'), 'silent');
      expect(prayerMode(const {}, 'asr'), 'adhan');
      final n = {
        'adhan': {'asr': true, 'isha': false},
        'adhanModes': {'asr': 'notify', 'isha': 'adhan', 'dhuhr': 'silent'},
      };
      expect(prayerMode(n, 'asr'), 'notify');
      expect(prayerMode(n, 'isha'), 'silent');
      // A stale explicit "silent" yields to a legacy flag turned back on.
      expect(prayerMode(n, 'dhuhr'), 'adhan');
    });

    test(
      'AppState keeps stored legacy maps and adhan settings on reload',
      () async {
        SharedPreferences.setMockInitialValues({
          'fadl.notifications': jsonEncode({
            'adhan': {'fajr': true, 'asr': false},
          }),
        });
        final state = AppState();
        await state.load();
        expect(state.notifications['regularSound'], defaultAdhanSound);
        expect(state.notifications['fajrSound'], isNull);
        expect(state.notifications['respectSilent'], isFalse);
        expect(prayerMode(state.notifications, 'fajr'), 'notify');
        expect(prayerMode(state.notifications, 'asr'), 'silent');
        expect(prayerMode(state.notifications, 'dhuhr'), 'adhan');

        await state.updateNotifications({
          'adhanModes': {'maghrib': 'notify'},
          'regularSound': 'regular_x.audio',
          'respectSilent': true,
        });
        final restored = AppState();
        await restored.load();
        expect(restored.notifications['regularSound'], 'regular_x.audio');
        expect(restored.notifications['respectSilent'], isTrue);
        expect(prayerMode(restored.notifications, 'maghrib'), 'notify');
        expect(restored.notifications['adhan']['asr'], isFalse);
      },
    );
  });

  group('Fajr rule', () {
    test('Fajr never resolves to the bundled adhan', () {
      for (final sound in [
        null,
        defaultAdhanSound,
        'regular_1.audio',
        '../adhan_default',
        'fajr_1.audio',
      ]) {
        final n = {
          'fajrSound': sound,
          'regularSound': sound,
          'adhanModes': {'fajr': 'adhan'},
        };
        expect(soundForPrayer(n, 'fajr'), isNot(defaultAdhanSound));
      }
      expect(
        soundForPrayer({'fajrSound': 'fajr_1.audio'}, 'fajr'),
        'fajr_1.audio',
      );
      expect(soundForPrayer(const {}, 'dhuhr'), defaultAdhanSound);
    });

    test('Fajr in adhan mode without an imported Fajr adhan is a plugin '
        'notification, never a native event', () {
      final now = DateTime.utc(2026, 5, 1, 0);
      final fajr = _item(
        'adhan:fajr:2026-05-01',
        now.add(const Duration(hours: 4)),
      );
      final n = {
        'adhanModes': {'fajr': 'adhan'},
        'fajrSound': defaultAdhanSound,
      };
      expect(effectivePrayerMode(n, 'fajr'), 'notify');
      final split = partitionAdhan([fajr], n, now);
      expect(split.native, isEmpty);
      expect(split.plugin, [fajr]);

      final imported = partitionAdhan(
        [fajr],
        {...n, 'fajrSound': 'fajr_1.audio'},
        now,
      );
      expect(imported.native.single.sound, 'fajr_1.audio');
      expect(imported.native.single.prayer, 'fajr');
      expect(imported.plugin, isEmpty);
    });
  });

  group('partition', () {
    final now = DateTime.utc(2026, 5, 1, 12);
    final items = [
      _item('adhan:dhuhr:2026-05-01', now.subtract(const Duration(minutes: 1))),
      _item('adhan:asr:2026-05-01', now.add(const Duration(hours: 3))),
      _item(
        'pre_adhan:asr:2026-05-01',
        now.add(const Duration(hours: 2, minutes: 45)),
      ),
      _item('adhan:maghrib:2026-05-01', now.add(const Duration(hours: 6))),
      _item('adhan:isha:2026-05-01', now.add(const Duration(hours: 8))),
      _item('adhan:fajr:2026-05-02', now.add(const Duration(hours: 16))),
      _item('adhan:sunrise:2026-05-02', now.add(const Duration(hours: 17))),
      _item('morning:2026-05-02', now.add(const Duration(hours: 18))),
      _item('adhan:dhuhr:2026-05-03', now.add(const Duration(hours: 47))),
      _item('adhan:asr:2026-05-03', now.add(const Duration(hours: 49))),
    ];
    final n = {
      'adhan': {'sunrise': true, 'isha': false},
      'adhanModes': {'maghrib': 'notify'},
      'respectSilent': true,
    };

    test('only future adhan-mode prayers within 48h become native events', () {
      final split = partitionAdhan(items, n, now, dua: 'dua');
      expect(split.native.map((e) => e.key), [
        'adhan:asr:2026-05-01',
        'adhan:dhuhr:2026-05-03',
      ]);
      for (final e in split.native) {
        expect(e.at.isAfter(now), isTrue);
        expect(e.at.difference(now), lessThanOrEqualTo(adhanScheduleWindow));
        expect(e.sound, defaultAdhanSound);
        expect(e.respectSilent, isTrue);
        expect(e.body, 'dua');
        expect(e.toMap()['at'], e.at.millisecondsSinceEpoch);
      }
    });

    test('adhan-mode prayers get no plugin notification; other modes and '
        'reminders stay with the plugin; silent ones are dropped', () {
      final split = partitionAdhan(items, n, now);
      final pluginKeys = split.plugin.map((i) => i['key']).toSet();
      for (final e in split.native) {
        expect(pluginKeys, isNot(contains(e.key)));
      }
      expect(pluginKeys, {
        'pre_adhan:asr:2026-05-01',
        'adhan:maghrib:2026-05-01',
        'adhan:fajr:2026-05-02',
        'adhan:sunrise:2026-05-02',
        'morning:2026-05-02',
      });
    });

    test('off Android, adhan mode falls back to plugin notifications', () {
      final split = partitionAdhan(items, n, now, android: false);
      expect(split.native, isEmpty);
      expect(
        split.plugin.map((i) => i['key']),
        containsAll(['adhan:asr:2026-05-01', 'adhan:asr:2026-05-03']),
      );
    });

    test('the master switch silences every prayer', () {
      final split = partitionAdhan(items, {...n, 'enabled': false}, now);
      expect(split.native, isEmpty);
      expect(split.plugin.map((i) => i['key']), [
        'pre_adhan:asr:2026-05-01',
        'morning:2026-05-02',
      ]);
    });
  });

  test('the post-adhan dua is taken verbatim from «أذكار الآذان»', () async {
    final dua = await loadAdhanDua();
    final athkar = await OfflineAthkar.load();
    final texts = [
      for (final item in athkar.category('adhan')!['items'] as List)
        (item as Map)['text'],
    ];
    expect(dua, isNotNull);
    expect(texts, contains(dua));
  });

  test('reschedule sends adhan prayers to the native channel and creates no '
      'plugin notification for them', () async {
    SharedPreferences.setMockInitialValues({
      'fadl.settings': jsonEncode({
        'latitude': 24.7136,
        'longitude': 46.6753,
        'timezone': 'Asia/Riyadh',
        'calcMethod': 'UmmAlQura',
      }),
      'fadl.notifications': jsonEncode({
        'preAlertMinutes': 0,
        'adhanModes': {'asr': 'notify'},
      }),
    });
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final pluginCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(_pluginChannel, (call) async {
      pluginCalls.add(call);
      return switch (call.method) {
        'initialize' ||
        'requestNotificationsPermission' ||
        'canScheduleExactNotifications' => true,
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_pluginChannel, null));

    final state = AppState();
    await state.load();
    final before = DateTime.now();
    await LocalNotifications.instance.reschedule(state);

    final schedule = adhanCalls.singleWhere((c) => c.method == 'schedule');
    final events = ((schedule.arguments as Map)['events'] as List).cast<Map>();
    expect(events, isNotEmpty);
    final prayers = events.map((e) => e['prayer']).toSet();
    expect(prayers, everyElement(isIn(['dhuhr', 'maghrib', 'isha'])));
    for (final e in events) {
      final at = DateTime.fromMillisecondsSinceEpoch(e['at'] as int);
      expect(at.isAfter(before), isTrue);
      expect(at.difference(before), lessThanOrEqualTo(adhanScheduleWindow));
      expect(e['sound'], defaultAdhanSound);
    }

    final scheduled = pluginCalls.where((c) => c.method == 'zonedSchedule');
    final pluginTitles = {
      for (final c in scheduled) (c.arguments as Map)['title'],
    };
    for (final e in events) {
      expect(pluginTitles, isNot(contains(e['title'])));
    }
    // Notify-mode prayers (Fajr, Asr) still use the plugin.
    expect(
      pluginTitles,
      contains(predicate<Object?>((t) => '$t'.contains(prayerNames['asr']!))),
    );
  });

  group('MethodChannel wrapper', () {
    test('forwards every call with its arguments', () async {
      final adhan = AdhanService.instance;
      await adhan.schedule([
        AdhanEvent(
          key: 'adhan:asr:2026-05-01',
          at: DateTime.utc(2026, 5, 1, 12),
          prayer: 'asr',
          nameAr: 'العصر',
          sound: defaultAdhanSound,
          respectSilent: false,
        ),
      ]);
      await adhan.cancelAll();
      await adhan.preview(defaultAdhanSound);
      await adhan.stopPreview();
      final picked = await adhan.pickAndImport(kind: 'fajr');
      final listed = await adhan.listImported();
      await adhan.deleteImported('regular_2.audio');
      await adhan.openBatterySettings();
      final exempt = await adhan.isIgnoringBatteryOptimizations();
      await adhan.testAlarm(defaultAdhanSound);

      expect(adhanCalls.map((c) => c.method), [
        'schedule',
        'cancelAll',
        'preview',
        'stopPreview',
        'pickAndImport',
        'listImported',
        'deleteImported',
        'openBatterySettings',
        'isIgnoringBatteryOptimizations',
        'testAlarm',
      ]);
      final events = (adhanCalls[0].arguments as Map)['events'] as List;
      expect((events.single as Map)['key'], 'adhan:asr:2026-05-01');
      expect(adhanCalls[2].arguments, {'soundId': defaultAdhanSound});
      expect(adhanCalls[4].arguments, {'kind': 'fajr'});
      expect(picked?.id, 'fajr_1.audio');
      expect(picked?.kind, 'fajr');
      expect(listed.single.name, 'makkah.mp3');
      expect(adhanCalls[6].arguments, {'id': 'regular_2.audio'});
      expect(exempt, isFalse);
      final test = (adhanCalls[9].arguments as Map)['event'] as Map;
      final at = DateTime.fromMillisecondsSinceEpoch(test['at'] as int);
      expect(at.difference(DateTime.now()).inSeconds, inInclusiveRange(55, 60));
    });

    test('a cancelled picker returns null', () async {
      messenger.setMockMethodCallHandler(
        AdhanService.channel,
        (call) async => null,
      );
      expect(
        await AdhanService.instance.pickAndImport(kind: 'regular'),
        isNull,
      );
    });
  });
}
