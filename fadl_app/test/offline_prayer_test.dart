import 'package:fadl/core/offline_prayer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cairo = <String, dynamic>{
    'latitude': 30.0444,
    'longitude': 31.2357,
    'timezone': 'Africa/Cairo',
    'calcMethod': 'Egyptian',
    'madhab': 'shafi',
  };
  final makkah = <String, dynamic>{
    'latitude': 21.4225,
    'longitude': 39.8262,
    'timezone': 'Asia/Riyadh',
    'calcMethod': 'UmmAlQura',
  };

  test(
    'every server method has a distinct localized entry and a working factory',
    () {
      expect(calcMethods.length, 12);
      for (final method in calcMethods.keys) {
        final daily = OfflinePrayer.day({
          ...cairo,
          'calcMethod': method,
        }, DateTime.utc(2026, 4, 10));
        expect((daily['method'] as Map)['nameAr'], calcMethods[method]);
        expect((daily['prayers'] as List).length, 6);
      }
    },
  );

  test('Hanafi and user adjustments affect selected prayer times', () {
    final date = DateTime.utc(2026, 4, 10);
    final standard = (OfflinePrayer.day(cairo, date)['prayers'] as List)
        .cast<Map<String, dynamic>>();
    final modified =
        (OfflinePrayer.day({
                  ...cairo,
                  'madhab': 'hanafi',
                  'adjustments': {'fajr': 5},
                }, date)['prayers']
                as List)
            .cast<Map<String, dynamic>>();
    DateTime at(List<Map<String, dynamic>> prayers, String name) =>
        DateTime.parse(
          prayers.firstWhere((p) => p['name'] == name)['time'] as String,
        );
    expect(at(modified, 'fajr').difference(at(standard, 'fajr')).inMinutes, 5);
    expect(at(modified, 'asr').isAfter(at(standard, 'asr')), isTrue);
    expect(at(modified, 'dhuhr'), at(standard, 'dhuhr'));
  });

  test('Ramadan Umm al-Qura Isha follows Maghrib by 120 minutes', () {
    final day = OfflinePrayer.day(makkah, DateTime.utc(2026, 2, 20));
    expect((day['hijri'] as Map)['month'], 9);
    final prayers = (day['prayers'] as List).cast<Map<String, dynamic>>();
    DateTime at(String name) => DateTime.parse(
      prayers.firstWhere((p) => p['name'] == name)['time'] as String,
    );
    expect(at('isha').difference(at('maghrib')).inMinutes, 120);
  });

  test('next prayer excludes sunrise and crosses local midnight', () {
    final daily = OfflinePrayer.day(cairo, DateTime.utc(2026, 4, 10));
    final prayers = (daily['prayers'] as List).cast<Map<String, dynamic>>();
    final fajr = DateTime.parse(prayers.first['time'] as String);
    expect(OfflinePrayer.nextPrayer(cairo, fajr)['name'], 'dhuhr');
    final isha = DateTime.parse(prayers.last['time'] as String);
    final next = OfflinePrayer.nextPrayer(cairo, isha);
    expect(next['name'], 'fajr');
    expect(DateTime.parse(next['time'] as String).isAfter(isha), isTrue);
  });

  test('Cairo and Makkah qibla bearings use the backend Kaaba position', () {
    final cairoBearing = OfflinePrayer.qibla(30.0444, 31.2357);
    expect(cairoBearing['bearing'], closeTo(136.14, 1));
    expect(cairoBearing['distanceKm'], inInclusiveRange(1200, 1300));
    final makkahBearing = OfflinePrayer.qibla(21.4225, 39.8262);
    expect(makkahBearing['distanceKm'], 0);
    expect(makkahBearing['bearing'], inInclusiveRange(0, 360));
  });

  test('serialized day preserves instant, zone display and Arabic labels', () {
    final day = OfflinePrayer.payload(cairo, DateTime.utc(2026, 4, 10, 12));
    expect(day['date'], '2026-04-10');
    expect((day['hijri'] as Map)['formattedAr'], contains('هـ'));
    expect(day['gregorianAr'], contains('أبريل'));
    expect((day['qibla'] as Map)['kaaba'], {
      'latitude': 21.422487,
      'longitude': 39.826206,
    });
    for (final prayer
        in (day['prayers'] as List).cast<Map<String, dynamic>>()) {
      expect(DateTime.parse(prayer['time'] as String).isUtc, isTrue);
      expect(prayer['local'], matches(RegExp(r'^\d\d:\d\d$')));
      expect(prayer['nameAr'], prayerNamesAr[prayer['name']]);
    }
    expect(
      (day['lastThirdOfNight'] as Map)['local'],
      matches(RegExp(r'^\d\d:\d\d$')),
    );
  });
}
