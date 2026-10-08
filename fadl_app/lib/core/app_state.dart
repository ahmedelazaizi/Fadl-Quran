import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'adhan_service.dart';
import 'api.dart';
import 'offline_prayer.dart';
import 'prayer_widget_schedule.dart';

/// Preset cities used when GPS is unavailable or denied.
class City {
  const City(this.nameAr, this.lat, this.lng, this.timezone, this.method);
  final String nameAr;
  final double lat;
  final double lng;
  final String timezone;
  final String method;
}

const presetCities = <City>[
  City('الرياض، السعودية', 24.7136, 46.6753, 'Asia/Riyadh', 'UmmAlQura'),
  City('مكة المكرمة، السعودية', 21.4225, 39.8262, 'Asia/Riyadh', 'UmmAlQura'),
  City(
    'المدينة المنورة، السعودية',
    24.4672,
    39.6111,
    'Asia/Riyadh',
    'UmmAlQura',
  ),
  City('جدة، السعودية', 21.4858, 39.1925, 'Asia/Riyadh', 'UmmAlQura'),
  City('القاهرة، مصر', 30.0444, 31.2357, 'Africa/Cairo', 'Egyptian'),
  City('الإسكندرية، مصر', 31.2001, 29.9187, 'Africa/Cairo', 'Egyptian'),
  City('دبي، الإمارات', 25.2048, 55.2708, 'Asia/Dubai', 'Dubai'),
  City('الكويت، الكويت', 29.3759, 47.9774, 'Asia/Kuwait', 'Kuwait'),
  City('الدوحة، قطر', 25.2854, 51.5310, 'Asia/Qatar', 'Qatar'),
  City('عمّان، الأردن', 31.9454, 35.9284, 'Asia/Amman', 'MuslimWorldLeague'),
  City(
    'الدار البيضاء، المغرب',
    33.5731,
    -7.5898,
    'Africa/Casablanca',
    'MuslimWorldLeague',
  ),
  City('إسطنبول، تركيا', 41.0082, 28.9784, 'Europe/Istanbul', 'Turkey'),
];

/// App-wide state: locally available preferences with optional backend sync.
class AppState extends ChangeNotifier {
  static const _settingsKey = 'fadl.settings';
  static const _notificationsKey = 'fadl.notifications';
  static const _languageKey = 'fadl.uiLanguage';

  String _language = 'ar';
  String get language => _language;
  Locale get locale => Locale(_language);

  Future<void> setLanguage(String language) async {
    if (language != 'ar' && language != 'en') {
      throw ArgumentError.value(language, 'language');
    }
    if (_language == language) return;
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
  }

  Map<String, dynamic> settings = {};
  Map<String, dynamic> notifications = {};
  bool ready = false;
  String? error;
  Future<void>? _loading;
  int _settingsRevision = 0;
  int _notificationsRevision = 0;
  Future<void> _widgetUpdate = Future<void>.value();

  static const _prayerKeys = {
    'latitude',
    'longitude',
    'timezone',
    'calcMethod',
    'madhab',
    'hijriAdjustment',
    'highLatRule',
    'adjustments',
  };

  void refreshPrayerWidget() {
    final snapshot = Map<String, dynamic>.from(settings);
    _widgetUpdate = _widgetUpdate.then(
      (_) => PrayerWidgetSchedule.update(snapshot),
    );
  }

  ThemeMode get themeMode => switch (settings['theme']) {
    'dark' => ThemeMode.dark,
    'auto' => ThemeMode.system,
    _ => ThemeMode.light,
  };

  bool get hasLocation =>
      settings['latitude'] != null && settings['longitude'] != null;
  String get dedicatee =>
      (settings['dedicateeName'] as String?) ?? 'فضل سليم محمد صالح';
  double get quranFontSize => ((settings['fontSize'] as num?) ?? 24).toDouble();
  String get reciterId =>
      (settings['reciterId'] as String?) ?? 'ar.abdulbasitmurattal';
  String get timezone => (settings['timezone'] as String?) ?? 'Asia/Riyadh';

  Future<void> load() =>
      _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedLanguage = prefs.getString(_languageKey);
    _language = storedLanguage == 'en' ? 'en' : 'ar';
    String tz = 'Asia/Riyadh';
    try {
      tz = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      // The timezone plugin is unavailable in some environments (including tests).
    }
    settings = {
      'theme': 'light',
      'fontSize': 24,
      'reciterId': 'ar.abdulbasitmurattal',
      'dedicateeName': 'فضل سليم محمد صالح',
      'continuousPlay': true,
      'timezone': tz,
      ..._readLocal(prefs, _settingsKey),
    };
    final storedNotifications = _readLocal(prefs, _notificationsKey);
    notifications = {
      'enabled': true,
      'preAlertMinutes': 15,
      'morningAthkarTime': '06:00',
      'eveningAthkarTime': '17:00',
      'sleepAthkarTime': null,
      // Device-only: memorization progress never leaves the device.
      'quranReviewTime': null,
      // Device-only: hours between dhikr reminders; 0 is off and null the
      // default (see dhikrReminderHours in core/dhikr_reminders.dart).
      'dhikrReminderHours': null,
      'fridayKahf': true,
      'khatmaReminder': true,
      // Device-only adhan settings (see core/adhan_service.dart); absent
      // per-prayer modes are derived from the legacy `adhan` bool map.
      'adhanModes': <String, String>{},
      'fajrSound': defaultFajrAdhanSound,
      'regularSound': defaultAdhanSound,
      'respectSilent': false,
      ...storedNotifications,
      'adhan': {
        'fajr': true,
        'sunrise': false,
        'dhuhr': true,
        'asr': true,
        'maghrib': true,
        'isha': true,
        ...?storedNotifications['adhan'] as Map?,
      },
    };
    final method = gpsMethodFix(settings);
    if (method != null) {
      settings = {...settings, 'calcMethod': method};
      await prefs.setString(_settingsKey, jsonEncode(settings));
    }
    error = null;
    ready = true;
    notifyListeners();
    refreshPrayerWidget();
    if (Api.hasBackend) unawaited(_sync(tz));
  }

  /// Location name stored for a GPS fix.
  static const gpsLocationName = 'موقعي الحالي';

  /// The method a GPS location set before methods followed the country
  /// should use: only when it still has the old Umm al-Qura default (never
  /// chosen) and its time zone names another country's method.
  @visibleForTesting
  static String? gpsMethodFix(Map<String, dynamic> settings) {
    if (settings['locationName'] != gpsLocationName ||
        settings['calcMethodManual'] == true) {
      return null;
    }
    final current = settings['calcMethod'] as String?;
    if (current != null && current != 'UmmAlQura') return null;
    final method = methodForTimezone('${settings['timezone']}');
    return method == current ? null : method;
  }

  static Map<String, dynamic> _readLocal(SharedPreferences prefs, String key) {
    final stored = prefs.getString(key);
    return stored == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(stored) as Map);
  }

  Future<void> _sync(String timezone) async {
    final settingsRevision = _settingsRevision;
    final notificationsRevision = _notificationsRevision;
    try {
      await Api.instance.ensureIdentity(timezone: timezone);
      final me = await Api.instance.get('/me') as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      if (_settingsRevision == settingsRevision) {
        settings = {
          ...settings,
          ...Map<String, dynamic>.from(me['settings'] as Map),
        };
        settings['dedicateeName'] ??= 'فضل سليم محمد صالح';
        await prefs.setString(_settingsKey, jsonEncode(settings));
        refreshPrayerWidget();
      }
      if (_notificationsRevision == notificationsRevision) {
        notifications = {
          ...notifications,
          ...Map<String, dynamic>.from(me['notifications'] as Map),
          'adhanModes': notifications['adhanModes'],
          'fajrSound': notifications['fajrSound'],
          'regularSound': notifications['regularSound'],
          'respectSilent': notifications['respectSilent'],
        };
        await prefs.setString(_notificationsKey, jsonEncode(notifications));
      }
      error = null;
      notifyListeners();
      if (_settingsRevision == settingsRevision &&
          (me['settings'] as Map)['dedicateeName'] == null) {
        await updateSettings({'dedicateeName': 'فضل سليم محمد صالح'});
      }
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  Future<void> updateSettings(Map<String, Object?> patch) async {
    settings = {...settings, ...patch};
    final revision = ++_settingsRevision;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings));
    if (patch.keys.any(_prayerKeys.contains)) refreshPrayerWidget();
    // Device-only: whether the user chose the calculation method.
    final backendPatch = Map<String, Object?>.from(patch)
      ..remove('calcMethodManual');
    if (Api.hasBackend && backendPatch.isNotEmpty) {
      unawaited(_syncSettingsPatch(backendPatch, revision));
    }
  }

  Future<void> _syncSettingsPatch(
    Map<String, Object?> patch,
    int revision,
  ) async {
    try {
      final updated =
          await Api.instance.patch('/me/settings', patch)
              as Map<String, dynamic>;
      if (revision != _settingsRevision) return;
      settings = {...settings, ...updated};
      error = null;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(settings));
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  Future<void> updateNotifications(Map<String, Object?> patch) async {
    notifications = {
      ...notifications,
      ...patch,
      if (patch['adhan'] case final Map adhanPatch)
        'adhan': {...?notifications['adhan'] as Map?, ...adhanPatch},
      if (patch['adhanModes'] case final Map modePatch)
        'adhanModes': {...?notifications['adhanModes'] as Map?, ...modePatch},
    };
    final revision = ++_notificationsRevision;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationsKey, jsonEncode(notifications));
    if (Api.hasBackend) {
      final backendPatch = Map<String, Object?>.from(patch)
        ..remove('adhanModes')
        ..remove('regularSound')
        ..remove('fajrSound')
        ..remove('respectSilent')
        ..remove('quranReviewTime')
        ..remove('dhikrReminderHours');
      if (backendPatch.isNotEmpty) {
        unawaited(_syncNotificationsPatch(backendPatch, revision));
      }
    }
  }

  Future<void> _syncNotificationsPatch(
    Map<String, Object?> patch,
    int revision,
  ) async {
    try {
      final updated =
          await Api.instance.patch('/me/notifications', patch)
              as Map<String, dynamic>;
      if (revision != _notificationsRevision) return;
      notifications = {...notifications, ...updated};
      error = null;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notificationsKey, jsonEncode(notifications));
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  Future<void> setCity(City city) => updateSettings({
    'latitude': city.lat,
    'longitude': city.lng,
    'locationName': city.nameAr,
    'timezone': city.timezone,
    'calcMethod': city.method,
  });

  /// Uses GPS; returns false when permission is denied or location is off.
  Future<bool> useDeviceLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    final pos = await Geolocator.getCurrentPosition();
    String tz = timezone;
    try {
      tz = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {}
    // The country's official method, unless the user picked one.
    final method = settings['calcMethodManual'] == true
        ? null
        : methodForTimezone(tz);
    await updateSettings({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'locationName': gpsLocationName,
      'timezone': tz,
      'calcMethod': ?method,
    });
    return true;
  }
}
