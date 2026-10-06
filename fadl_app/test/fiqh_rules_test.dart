import 'dart:convert';

import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/local_notifications.dart';
import 'package:fadl/core/offline_prayer.dart';
import 'package:fadl/core/worship_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First Gregorian day from [from] whose Umm al-Qura date is [day]/[month].
DateTime hijriDay(int month, int day, {DateTime? from}) {
  var date = from ?? DateTime.utc(2026, 1, 1);
  while (true) {
    final h = OfflinePrayer.hijri(date);
    if (h['month'] == month && h['day'] == day) return date;
    date = date.add(const Duration(days: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('calendar occasions', () {
    test('13 Dhul-Hijjah is a day of tashreeq, not a white day', () {
      final d13 = hijriDay(12, 13);
      expect(hijriOccasions(d13, 0), contains('أيام التشريق'));
      expect(hijriOccasions(d13, 0), isNot(contains('الأيام البيض')));
      final d14 = d13.add(const Duration(days: 1));
      expect(hijriOccasions(d14, 0), contains('الأيام البيض'));
      expect(hijriOccasions(d14, 0), isNot(contains('أيام التشريق')));
    });

    test('Tasu\'a precedes Ashura and other months keep the 13th', () {
      final tasua = hijriDay(1, 9);
      expect(hijriOccasions(tasua, 0), contains('تاسوعاء'));
      expect(
        hijriOccasions(tasua.add(const Duration(days: 1)), 0),
        contains('عاشوراء'),
      );
      expect(hijriOccasions(hijriDay(8, 13), 0), contains('الأيام البيض'));
    });
  });

  group('zakat', () {
    ZakatBreakdown calc({
      double cash = 0,
      double goldGrams = 0,
      int karat = 24,
      double debts = 0,
    }) => ZakatBreakdown(
      cash: cash,
      goldGrams: goldGrams,
      silverGrams: 0,
      goldPrice: 100,
      silverPrice: 1,
      inventory: 0,
      receivables: 0,
      useGoldNisab: true,
      goldKarat: karat,
      debts: debts,
    );

    test('gold is valued by its pure-gold content', () {
      expect(calc(goldGrams: 100, karat: 21).pureGoldGrams, 87.5);
      expect(calc(goldGrams: 100, karat: 21).goldValue, 8750);
      // 90 g of 18k is 67.5 g pure: below the 85 g nisab.
      expect(calc(goldGrams: 90, karat: 18).due, 0);
      expect(calc(goldGrams: 90).due, 225);
    });

    test('debts due now are deducted before the nisab check', () {
      expect(calc(cash: 10000, debts: 2000).net, 8000);
      expect(calc(cash: 10000, debts: 2000).due, 0);
      expect(calc(cash: 10000, debts: 1500).due, 212.5);
      expect(calc(cash: 100, debts: 500).net, 0);
    });
  });

  test('pre-adhan minutes agree with the Arabic counted noun', () {
    expect(LocalNotifications.arabicMinutes(1), 'دقيقة واحدة');
    expect(LocalNotifications.arabicMinutes(2), 'دقيقتان');
    expect(LocalNotifications.arabicMinutes(5), '٥ دقائق');
    expect(LocalNotifications.arabicMinutes(10), '١٠ دقائق');
    expect(LocalNotifications.arabicMinutes(15), '١٥ دقيقة');
    expect(LocalNotifications.arabicMinutes(30), '٣٠ دقيقة');
  });

  group('offline reminders', () {
    Future<AppState> riyadh(Map<String, Object?> notifications) async {
      SharedPreferences.setMockInitialValues({
        'fadl.settings': jsonEncode({
          'latitude': 24.7136,
          'longitude': 46.6753,
          'timezone': 'Asia/Riyadh',
          'calcMethod': 'UmmAlQura',
        }),
        'fadl.notifications': jsonEncode(notifications),
      });
      final state = AppState();
      await state.load();
      return state;
    }

    List<Map<String, dynamic>> at(AppState state, DateTime day, String type) =>
        LocalNotifications.offlineUpcoming(
          state,
          day.add(const Duration(hours: 1)), // 04:00 Riyadh
        ).where((n) => n['type'] == type).toList();

    test('Dhul-Hijjah white days are announced on the 13th for the 14th '
        'and 15th only', () async {
      final state = await riyadh({'whiteDaysFast': true});
      final d12 = hijriDay(12, 12);
      final onD12 = at(
        state,
        d12,
        'fast_white_days',
      ).where((n) => (n['key'] as String).endsWith(_iso(d12)));
      expect(onD12, isEmpty);
      final d13 = d12.add(const Duration(days: 1));
      final reminder = at(
        state,
        d13,
        'fast_white_days',
      ).singleWhere((n) => (n['key'] as String).endsWith(_iso(d13)));
      expect(reminder['body'], contains('١٤، ١٥'));
      expect(reminder['body'], isNot(contains('١٣،')));
    });

    test('other months announce the white days on the 12th', () async {
      final state = await riyadh({'whiteDaysFast': true});
      final d12 = hijriDay(8, 12);
      final reminder = at(
        state,
        d12,
        'fast_white_days',
      ).singleWhere((n) => (n['key'] as String).endsWith(_iso(d12)));
      expect(reminder['body'], contains('١٣، ١٤، ١٥'));
    });

    test('pre-adhan alert uses correct Arabic plural', () async {
      final state = await riyadh({'preAlertMinutes': 10});
      final alerts = at(state, DateTime.utc(2026, 10, 7), 'pre_adhan:dhuhr');
      expect(alerts, isNotEmpty);
      expect(alerts.first['body'], 'بقي ١٠ دقائق على الأذان');
    });

    test('the Friday hour of response never starts before asr', () async {
      final state = await riyadh({'fridayHour': true});
      final friday = DateTime.utc(2026, 10, 9);
      final hour = at(state, friday, 'friday_hour').single;
      final prayers =
          (OfflinePrayer.day(state.settings, friday)['prayers'] as List)
              .cast<Map>();
      DateTime time(String name) => DateTime.parse(
        prayers.firstWhere((p) => p['name'] == name)['time'] as String,
      );
      final fireAt = DateTime.parse(hour['fireAt'] as String);
      expect(fireAt.isBefore(time('asr')), isFalse);
      expect(
        time('maghrib').difference(fireAt),
        lessThanOrEqualTo(const Duration(hours: 1)),
      );
    });
  });
}

String _iso(DateTime d) =>
    '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';
