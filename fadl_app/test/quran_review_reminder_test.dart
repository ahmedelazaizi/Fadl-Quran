import 'dart:convert';

import 'package:fadl/core/adhan_service.dart';
import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/local_notifications.dart';
import 'package:fadl/core/offline_prayer.dart';
import 'package:fadl/core/quran_learning.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pluginChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final riyadh = OfflinePrayer.location('Asia/Riyadh');
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));
  // 13:00 in Riyadh (UTC+3).
  final now = DateTime.utc(2026, 10, 6, 10);

  List<Map<String, dynamic>> reminders({
    String time = '20:00',
    DateTime? at,
    int Function(DateTime)? dueAt,
    AppLocalizations? l,
  }) => LocalNotifications.reviewReminders(
    time: time,
    location: riyadh,
    now: at ?? now,
    dueAt: dueAt ?? (_) => 3,
    l: l ?? en,
  );

  test('schedules each local review time inside the 48-hour window', () {
    final items = reminders();
    expect(items.map((i) => i['fireAt']), [
      '2026-10-06T17:00:00.000Z',
      '2026-10-07T17:00:00.000Z',
    ]);
    expect(items.map((i) => i['key']), [
      'quran_review:2026-10-06',
      'quran_review:2026-10-07',
    ]);
    expect(items.first['type'], 'quran_review');
    expect(items.first['title'], 'Quran review');
    expect(items.first['body'], '3 memorized pages are due for review today');
  });

  test('a passed time today starts tomorrow', () {
    final items = reminders(at: DateTime.utc(2026, 10, 6, 18));
    expect(items.first['fireAt'], '2026-10-07T17:00:00.000Z');
  });

  test('days with nothing due get no reminder', () {
    final tomorrow = DateTime.utc(2026, 10, 7);
    final items = reminders(dueAt: (at) => at.isBefore(tomorrow) ? 0 : 1);
    expect(items.map((i) => i['key']), ['quran_review:2026-10-07']);
    expect(items.single['body'], '1 memorized page is due for review today');
  });

  test('counts pages that fall due later on the reminder day', () {
    // A page rated at 21:00 Riyadh becomes due at 21:00 the next day; the
    // 20:00 reminder that day should still include it.
    final dueAt21 = DateTime.utc(2026, 10, 6, 18);
    final items = reminders(dueAt: (at) => at.isBefore(dueAt21) ? 0 : 1);
    expect(items.first['key'], 'quran_review:2026-10-06');
  });

  test('Arabic text uses Arabic digits and plural forms', () {
    String body(int due) =>
        reminders(dueAt: (_) => due, l: ar).first['body'] as String;
    expect(reminders(l: ar).first['title'], 'مراجعة الحفظ');
    expect(body(1), 'صفحة محفوظة تستحق المراجعة اليوم');
    expect(body(2), 'صفحتان محفوظتان تستحقان المراجعة اليوم');
    expect(body(3), '٣ صفحات محفوظة تستحق المراجعة اليوم');
    expect(body(12), '١٢ صفحة محفوظة تستحق المراجعة اليوم');
  });

  test(
    'reschedule adds due-review reminders without a saved location',
    () async {
      final review = PageReview(
        quality: 4,
        repetitions: 1,
        intervalDays: 1,
        ease: 2.5,
        due: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );
      SharedPreferences.setMockInitialValues({
        QuranReviewStore.preferenceKey: jsonEncode({'5': review.toRow()}),
        'fadl.notifications': jsonEncode({'quranReviewTime': '00:01'}),
        'fadl.uiLanguage': 'en',
      });
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(_pluginChannel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'initialize' ||
          'requestNotificationsPermission' ||
          'canScheduleExactNotifications' => true,
          _ => null,
        };
      });
      messenger.setMockMethodCallHandler(
        AdhanService.channel,
        (_) async => null,
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(_pluginChannel, null);
        messenger.setMockMethodCallHandler(AdhanService.channel, null);
      });

      final state = AppState();
      await state.load();
      expect(state.hasLocation, isFalse);
      await LocalNotifications.instance.reschedule(state);

      final scheduled = [
        for (final call in calls)
          if (call.method == 'zonedSchedule') call.arguments as Map,
      ];
      expect(scheduled, isNotEmpty);
      expect(scheduled.map((c) => c['title']), everyElement('Quran review'));
      expect(
        scheduled.first['body'],
        '1 memorized page is due for review today',
      );
    },
  );
}
