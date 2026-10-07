import 'dart:convert';

import 'package:fadl/core/adhan_service.dart';
import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/dhikr_reminders.dart';
import 'package:fadl/core/local_notifications.dart';
import 'package:fadl/core/offline_prayer.dart';
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
  final ar = lookupAppLocalizations(const Locale('ar'));

  test('every reminder has a distinct text and a cited source', () {
    expect(dhikrReminders.length, greaterThanOrEqualTo(12));
    expect(
      dhikrReminders.map((d) => d.text).toSet(),
      hasLength(dhikrReminders.length),
    );
    for (final dhikr in dhikrReminders) {
      expect(dhikr.text.trim(), isNotEmpty);
      expect(dhikr.source.trim(), isNotEmpty);
    }
  });

  test('one daily slot per interval between 8:00 and 22:00', () {
    // 13:00 in Riyadh.
    final now = DateTime.utc(2026, 10, 6, 10);
    final items = LocalNotifications.dhikrReminderItems(
      intervalHours: 3,
      location: riyadh,
      now: now,
      l: ar,
    );
    final local = [
      for (final item in items)
        DateTime.parse(item['fireAt'] as String).add(const Duration(hours: 3)),
    ];
    // 8 and 11 already passed today, so their first time is tomorrow.
    expect(local.map((t) => '${t.day}/${t.hour}'), [
      '7/8',
      '7/11',
      '6/14',
      '6/17',
      '6/20',
    ]);
    expect(items.map((i) => i['repeat']), everyElement('daily'));
    expect(items.map((i) => i['key']), [
      'dhikr:8',
      'dhikr:11',
      'dhikr:14',
      'dhikr:17',
      'dhikr:20',
    ]);
    expect(items.first['title'], 'ذكر الله');
    expect(items.map((i) => i['body']).toSet(), hasLength(items.length));
    final body = items.first['body'] as String;
    expect(dhikrReminders.any((d) => body == '${d.text}\n${d.source}'), isTrue);
  });

  test('hourly reminders use every text', () {
    final items = LocalNotifications.dhikrReminderItems(
      intervalHours: 1,
      location: riyadh,
      now: DateTime.utc(2026, 10, 6, 3),
      l: ar,
    );
    expect(items, hasLength(14));
    expect(
      items.map((i) => i['body']).toSet(),
      hasLength(dhikrReminders.length),
    );
  });

  test('reminders are on by default and stay off once turned off', () {
    expect(dhikrReminderHours({}), defaultDhikrReminderHours);
    expect(dhikrReminderHours({'dhikrReminderHours': null}), 2);
    expect(dhikrReminderHours({'dhikrReminderHours': 4}), 4);
    expect(dhikrReminderHours({'dhikrReminderHours': 0}), isNull);
    expect(dhikrReminderHours({'enabled': false}), isNull);
  });

  test('the iOS cap keeps every prayer and the soonest reminders', () {
    final start = DateTime.utc(2026, 10, 6);
    Map<String, dynamic> item(String type, int hours) => {
      'key': '$type:$hours',
      'type': type,
      'fireAt': start.add(Duration(hours: hours)).toIso8601String(),
    };
    final items = [
      for (var h = 1; h <= 47; h++) item('dhikr', h),
      for (var h = 2; h <= 46; h += 4) item('adhan', h),
    ];
    final kept = LocalNotifications.capPending(items, 20);
    expect(kept, hasLength(20));
    expect(kept.where((i) => i['type'] == 'adhan'), hasLength(12));
    // The eight reminders left are the soonest, and the list stays in order.
    expect(kept.where((i) => i['type'] == 'dhikr').map((i) => i['key']), [
      for (var h = 1; h <= 8; h++) 'dhikr:$h',
    ]);
    final times = kept.map((i) => i['fireAt'] as String).toList();
    expect(times, [...times]..sort());
    expect(
      LocalNotifications.capPending(items.take(5).toList(), 64),
      hasLength(5),
    );
  });

  test('reschedule posts default dhikr reminders with expanded text', () async {
    SharedPreferences.setMockInitialValues({
      // Nothing stored: reminders are on by default.
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
    messenger.setMockMethodCallHandler(AdhanService.channel, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(_pluginChannel, null);
      messenger.setMockMethodCallHandler(AdhanService.channel, null);
    });

    final state = AppState();
    await state.load();
    await LocalNotifications.instance.reschedule(state);
    final scheduled = [
      for (final call in calls)
        if (call.method == 'zonedSchedule') call.arguments as Map,
    ];
    expect(scheduled, isNotEmpty);
    expect(scheduled.map((c) => c['title']), everyElement('Remember Allah'));
    expect(
      jsonEncode(scheduled.first['platformSpecifics']),
      contains('bigText'),
    );
    // Daily repeats keep reminding without the app being opened.
    expect(scheduled.map((c) => c['matchDateTimeComponents']), everyElement(0));
  });
}
