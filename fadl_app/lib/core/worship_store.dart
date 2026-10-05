import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_user_data.dart';
import 'offline_prayer.dart';

const obligatoryPrayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
const prayerStatusLabels = {
  'onTime': 'في الوقت',
  'congregation': 'في جماعة',
  'late': 'متأخرة',
  'missed': 'فائتة',
};
const fastingTypes = {
  'ramadan': 'رمضان',
  'shawwal': 'ست من شوال',
  'voluntary': 'تطوع',
  'makeup': 'قضاء',
};

/// All dates are civil dates in the user's selected location, never UTC instants.
class WorshipStore {
  static const _prayersKey = 'fadl.worship.prayers.v1';
  static const _qadaKey = 'fadl.worship.qada.v1';
  static const _fastsKey = 'fadl.worship.fasts.v1';
  static const _ramadanQadaKey = 'fadl.worship.ramadanQada.v1';

  Future<Map<String, String>> prayers() async {
    final raw = (await SharedPreferences.getInstance()).getString(_prayersKey);
    return raw == null ? {} : Map<String, String>.from(jsonDecode(raw) as Map);
  }

  Future<Map<String, int>> qada() async {
    final raw = (await SharedPreferences.getInstance()).getString(_qadaKey);
    return raw == null ? {} : Map<String, int>.from(jsonDecode(raw) as Map);
  }

  Future<void> setPrayer(String date, String prayer, String? status) async {
    if (!obligatoryPrayers.contains(prayer) ||
        (status != null && !prayerStatusLabels.containsKey(status))) {
      throw ArgumentError('Invalid prayer or status');
    }
    validateDate(date);
    final records = await prayers();
    final key = '$date/$prayer';
    final previous = records[key];
    if (status == null) {
      records.remove(key);
    } else {
      records[key] = status;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prayersKey, jsonEncode(records));
    if (previous != 'missed' && status == 'missed') {
      await adjustQada(prayer, 1);
    }
  }

  Future<void> adjustQada(String prayer, int delta) async {
    if (!obligatoryPrayers.contains(prayer)) throw ArgumentError.value(prayer);
    final counts = await qada();
    counts[prayer] = ((counts[prayer] ?? 0) + delta).clamp(0, 1000000);
    await (await SharedPreferences.getInstance()).setString(
      _qadaKey,
      jsonEncode(counts),
    );
  }

  Future<Map<String, int>> prayerStats(DateTime start, DateTime end) async {
    final records = await prayers();
    final counts = {for (final status in prayerStatusLabels.keys) status: 0};
    final first = LocalUserData.ymd(start);
    final last = LocalUserData.ymd(end);
    for (final entry in records.entries) {
      if (entry.key.length < 10) continue;
      final date = entry.key.substring(0, 10);
      if (date.compareTo(first) >= 0 && date.compareTo(last) <= 0) {
        counts.update(entry.value, (count) => count + 1);
      }
    }
    return counts;
  }

  Future<String> exportPrayers() async => jsonEncode({
    'version': 1,
    'prayers': await prayers(),
    'qada': await qada(),
  });

  Future<void> importPrayers(String source) async {
    final bundle = jsonDecode(source) as Map;
    if (bundle['version'] != 1) {
      throw const FormatException('Unsupported version');
    }
    final records = Map<String, String>.from(bundle['prayers'] as Map);
    final counts = Map<String, int>.from(bundle['qada'] as Map);
    for (final entry in records.entries) {
      final parts = entry.key.split('/');
      if (parts.length != 2 ||
          !obligatoryPrayers.contains(parts[1]) ||
          !prayerStatusLabels.containsKey(entry.value)) {
        throw const FormatException('Invalid prayer record');
      }
      validateDate(parts[0]);
    }
    for (final entry in counts.entries) {
      if (!obligatoryPrayers.contains(entry.key) || entry.value < 0) {
        throw const FormatException('Invalid qada count');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prayersKey, jsonEncode(records));
    await prefs.setString(_qadaKey, jsonEncode(counts));
  }

  Future<Map<String, Map<String, String>>> fasts() async {
    final raw = (await SharedPreferences.getInstance()).getString(_fastsKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map).map(
      (date, record) =>
          MapEntry(date as String, Map<String, String>.from(record as Map)),
    );
  }

  Future<void> setFast(String date, String? type, {String notes = ''}) async {
    validateDate(date);
    if (type != null && !fastingTypes.containsKey(type)) {
      throw ArgumentError.value(type);
    }
    final records = await fasts();
    if (type == null) {
      records.remove(date);
    } else {
      records[date] = {'type': type, 'notes': notes};
    }
    await (await SharedPreferences.getInstance()).setString(
      _fastsKey,
      jsonEncode(records),
    );
  }

  Future<Map<String, int>> fastingYear(int year) async {
    final records = await fasts();
    final counts = {for (final type in fastingTypes.keys) type: 0};
    for (final entry in records.entries) {
      if (entry.key.startsWith('$year-')) {
        counts.update(entry.value['type']!, (count) => count + 1);
      }
    }
    return counts;
  }

  Future<int> ramadanQada() async =>
      (await SharedPreferences.getInstance()).getInt(_ramadanQadaKey) ?? 0;

  Future<void> adjustRamadanQada(int delta) async {
    final count = ((await ramadanQada()) + delta).clamp(0, 1000000);
    await (await SharedPreferences.getInstance()).setInt(
      _ramadanQadaKey,
      count,
    );
  }
}

void validateDate(String date) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
  if (match == null) throw const FormatException('Invalid civil date');
  final parsed = DateTime.utc(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
  );
  if (LocalUserData.ymd(parsed) != date) {
    throw const FormatException('Invalid civil date');
  }
}

String selectedLocalDate(String timezone, DateTime instant) =>
    LocalUserData.ymd(OfflinePrayer.today(timezone, instant));
