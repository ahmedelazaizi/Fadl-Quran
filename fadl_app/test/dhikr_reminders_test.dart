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

  test('reminders fire every interval between 8:00 and 22:00 only', () {
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
    // Today 14, 17, 20; tomorrow 8…20; then 8 and 11 before 13:00.
    expect(local.map((t) => '${t.day}/${t.hour}'), [
      '6/14',
      '6/17',
      '6/20',
      '7/8',
      '7/11',
      '7/14',
      '7/17',
      '7/20',
      '8/8',
      '8/11',
    ]);
    expect(items.map((i) => i['key']).toSet(), hasLength(items.length));
    expect(items.first['title'], 'ذكر الله');
    for (var i = 1; i < items.length; i++) {
      expect(items[i]['body'], isNot(items[i - 1]['body']));
    }
    final body = items.first['body'] as String;
    expect(dhikrReminders.any((d) => body == '${d.text}\n${d.source}'), isTrue);
  });

  test('hourly reminders rotate through the whole list', () {
    final items = LocalNotifications.dhikrReminderItems(
      intervalHours: 1,
      location: riyadh,
      now: DateTime.utc(2026, 10, 6, 3),
      l: ar,
    );
    expect(
      items.map((i) => i['body']).toSet(),
      hasLength(dhikrReminders.length),
    );
  });

  test('reschedule posts dhikr reminders with expanded text', () async {
    SharedPreferences.setMockInitialValues({
      'fadl.notifications': jsonEncode({'dhikrReminderHours': 1}),
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
  });
}
