import 'dart:convert';

import 'package:fadl/core/offline_prayer.dart';
import 'package:fadl/core/prayer_widget_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final settings = {
    'latitude': 24.7136,
    'longitude': 46.6753,
    'timezone': 'Asia/Riyadh',
    'calcMethod': 'UmmAlQura',
  };

  test(
    'widget payload serializes five ordered absolute prayer instants daily',
    () {
      final now = DateTime.utc(2026, 4, 20, 8);
      final payload = PrayerWidgetSchedule.build(settings, now, days: 2);
      final decoded = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      final prayers = (decoded['prayers'] as List).cast<Map>();
      expect(decoded['timezone'], 'Asia/Riyadh');
      expect(
        (decoded['dates'] as Map).keys,
        containsAll(['2026-04-20', '2026-04-21']),
      );
      expect(
        (decoded['dates'] as Map)['2026-04-20'],
        OfflinePrayer.hijri(DateTime.utc(2026, 4, 20))['formattedAr'],
      );
      expect(prayers, hasLength(10));
      expect(
        prayers.every(
          (prayer) =>
              prayer['at'] is int &&
              prayer['local'] is String &&
              prayer['name'] is String,
        ),
        isTrue,
      );
      expect(
        prayers.map((prayer) => prayer['at']),
        orderedEquals(prayers.map((prayer) => prayer['at']).toList()..sort()),
      );
    },
  );

  test(
    'next prayer skips exact boundary and returns null past cache horizon',
    () {
      final payload = PrayerWidgetSchedule.build(
        settings,
        DateTime.utc(2026, 4, 20),
        days: 2,
      );
      final prayers = (payload['prayers'] as List).cast<Map>();
      final first = prayers.first['at'] as int;
      expect(
        PrayerWidgetSchedule.nextPrayer(
          payload,
          DateTime.fromMillisecondsSinceEpoch(first - 1),
        )?['at'],
        first,
      );
      expect(
        PrayerWidgetSchedule.nextPrayer(
          payload,
          DateTime.fromMillisecondsSinceEpoch(first),
        )?['at'],
        prayers[1]['at'],
      );
      expect(
        PrayerWidgetSchedule.nextPrayer(payload, DateTime.utc(2026, 4, 23)),
        isNull,
      );
    },
  );

  test('widget payload preserves adjusted Hijri dates and selected zone', () {
    final adjusted = {
      ...settings,
      'hijriAdjustment': 1,
      'timezone': 'America/New_York',
    };
    final now = DateTime.utc(2026, 3, 8, 2);
    final payload = PrayerWidgetSchedule.build(adjusted, now, days: 2);
    final dates = payload['dates'] as Map;
    expect(dates.keys.first, '2026-03-07');
    expect(
      dates['2026-03-07'],
      OfflinePrayer.hijri(DateTime.utc(2026, 3, 7), 1)['formattedAr'],
    );
  });

  test(
    'widget bridge sends serialized schedule without network calls',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      String? saved;
      messenger.setMockMethodCallHandler(PrayerWidgetSchedule.channel, (
        call,
      ) async {
        expect(call.method, 'save');
        saved = call.arguments as String;
        return null;
      });
      try {
        await PrayerWidgetSchedule.update(settings);
        expect((jsonDecode(saved!) as Map)['version'], 1);
      } finally {
        messenger.setMockMethodCallHandler(PrayerWidgetSchedule.channel, null);
      }
    },
  );
}
