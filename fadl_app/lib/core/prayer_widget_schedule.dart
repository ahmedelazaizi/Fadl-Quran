import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'local_user_data.dart';
import 'offline_prayer.dart';

/// Android stores absolute instants; date labels use the selected city zone.
class PrayerWidgetSchedule {
  PrayerWidgetSchedule._();

  static const channel = MethodChannel('fadl/prayer_widget');
  static const horizonDays = 400;

  static Map<String, dynamic> build(
    Map<String, dynamic> settings,
    DateTime now, {
    int days = horizonDays,
  }) {
    final timezone = (settings['timezone'] as String?) ?? 'Asia/Riyadh';
    final start = OfflinePrayer.today(timezone, now);
    final prayers = <Map<String, dynamic>>[];
    final dates = <String, String>{};
    for (var offset = 0; offset < days; offset++) {
      final date = DateTime.utc(start.year, start.month, start.day + offset);
      final daily = OfflinePrayer.day(settings, date);
      dates[LocalUserData.ymd(date)] =
          (daily['hijri'] as Map)['formattedAr'] as String;
      for (final prayer in (daily['prayers'] as List).cast<Map>()) {
        if (prayer['name'] == 'sunrise') continue;
        prayers.add({
          'at': DateTime.parse(prayer['time'] as String).millisecondsSinceEpoch,
          'name': prayer['nameAr'],
          'local': prayer['local'],
        });
      }
    }
    prayers.sort((a, b) => (a['at'] as int).compareTo(b['at'] as int));
    return {
      'version': 1,
      'timezone': timezone,
      'dates': dates,
      'prayers': prayers,
    };
  }

  static Map<String, dynamic>? nextPrayer(
    Map<String, dynamic> schedule,
    DateTime now,
  ) {
    for (final prayer in (schedule['prayers'] as List).cast<Map>()) {
      if ((prayer['at'] as int) > now.millisecondsSinceEpoch) {
        return Map<String, dynamic>.from(prayer);
      }
    }
    return null;
  }

  static Future<void> update(Map<String, dynamic> settings) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final hasLocation =
        settings['latitude'] != null && settings['longitude'] != null;
    final schedule = hasLocation
        ? await compute(_buildWidgetPayload, (
            settings,
            DateTime.now().millisecondsSinceEpoch,
          ))
        : null;
    try {
      if (schedule == null) {
        await channel.invokeMethod<void>('clear');
      } else {
        await channel.invokeMethod<void>('save', jsonEncode(schedule));
      }
    } on MissingPluginException catch (error) {
      debugPrint('Prayer widget is unavailable: $error');
    } on PlatformException catch (error) {
      debugPrint('Prayer widget update failed: $error');
    }
  }
}

Map<String, dynamic> _buildWidgetPayload((Map<String, dynamic>, int) input) =>
    PrayerWidgetSchedule.build(
      input.$1,
      DateTime.fromMillisecondsSinceEpoch(input.$2),
    );
