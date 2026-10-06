import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'offline_athkar.dart';

/// Full-length adhan at prayer times (Android): pure scheduling rules plus a
/// thin wrapper around the native `fadl/adhan` MethodChannel.
///
/// Settings live in `AppState.notifications`:
/// - `adhan`: legacy per-prayer bool map (still synced with the backend);
///   `false` means the prayer is silent.
/// - `adhanModes`: per-prayer `adhan` | `notify` | `silent`.
/// - `regularSound`: sound for dhuhr…isha (a bundled id or an import id).
/// - `fajrSound`: imported Fajr adhan id, or null.
/// - `respectSilent`: vibrate + notify instead of sound in silent/vibrate mode.

const prayerNames = <String, String>{
  'fajr': 'الفجر',
  'sunrise': 'الشروق',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};

const adhanModeValues = ['adhan', 'notify', 'silent'];

/// Bundled raw resource; it lacks the Fajr-specific words, so never Fajr.
const defaultAdhanSound = 'adhan_default';

/// Every bundled adhan (Android raw resources, see the licenses page). None
/// carries the Fajr-specific words, so they serve dhuhr…isha only.
const bundledAdhanSounds = [defaultAdhanSound, 'adhan_madinah', 'adhan_makkah'];

/// Window of native alarms; matches the 48h of plugin notifications.
const adhanScheduleWindow = Duration(hours: 48);

/// Mode chosen for [prayer], migrating the legacy bool map:
/// `false` → silent; `true` (or unset, except sunrise) → the explicit mode
/// if any, else `adhan` for dhuhr/asr/maghrib/isha and `notify` for
/// fajr/sunrise.
String prayerMode(Map notifications, String prayer) {
  final legacy = notifications['adhan'] as Map? ?? const {};
  final enabled = legacy[prayer] ?? prayer != 'sunrise';
  if (enabled != true) return 'silent';
  final explicit = (notifications['adhanModes'] as Map?)?[prayer];
  if (explicit == 'adhan' || explicit == 'notify') return explicit as String;
  return prayer == 'fajr' || prayer == 'sunrise' ? 'notify' : 'adhan';
}

/// What actually happens at [prayer] time: the master switch silences all,
/// and Fajr without an imported Fajr adhan (or sunrise) is a notification.
String effectivePrayerMode(Map notifications, String prayer) {
  if (notifications['enabled'] == false) return 'silent';
  final mode = prayerMode(notifications, prayer);
  if (mode == 'adhan' && soundForPrayer(notifications, prayer) == null) {
    return 'notify';
  }
  return mode;
}

/// Sound id for [prayer]; null when no adhan may be played (Fajr without an
/// imported Fajr adhan, sunrise). Never [defaultAdhanSound] for Fajr.
String? soundForPrayer(Map notifications, String prayer) {
  if (prayer == 'sunrise') return null;
  if (prayer == 'fajr') {
    final value = notifications['fajrSound'];
    return value is String && value.startsWith('fajr_') ? value : null;
  }
  final value = notifications['regularSound'];
  return value is String &&
          (value.startsWith('regular_') || bundledAdhanSounds.contains(value))
      ? value
      : defaultAdhanSound;
}

/// Notification sound for [prayer] on iOS, where a 30-second clip of a
/// bundled adhan (`ios/Runner/*.caf`) rings with the alert; null for the
/// default alert sound. Fajr never gets one: no bundled adhan has the Fajr
/// words, and imports (synced from Android) do not exist on iOS.
String? iosAdhanClip(Map notifications, String prayer) {
  if (prayer == 'fajr' ||
      effectivePrayerMode(notifications, prayer) != 'adhan') {
    return null;
  }
  return '${iosRegularAdhan(notifications)}.caf';
}

/// The bundled adhan iOS rings for dhuhr…isha: the chosen one, or the
/// default in place of a sound imported on Android.
String iosRegularAdhan(Map notifications) {
  final sound = soundForPrayer(notifications, 'dhuhr')!;
  return bundledAdhanSounds.contains(sound) ? sound : defaultAdhanSound;
}

class AdhanEvent {
  const AdhanEvent({
    required this.key,
    required this.at,
    required this.prayer,
    required this.nameAr,
    required this.sound,
    required this.respectSilent,
    this.title,
    this.body,
  });
  final String key;
  final DateTime at;
  final String prayer;
  final String nameAr;
  final String sound;
  final bool respectSilent;
  final String? title;
  final String? body;

  Map<String, Object> toMap() => {
    'key': key,
    'at': at.millisecondsSinceEpoch,
    'prayer': prayer,
    'nameAr': nameAr,
    'sound': sound,
    'respectSilent': respectSilent,
    'title': ?title,
    'body': ?body,
  };
}

/// Prayer name of an adhan notification item (`adhan:<prayer>:<date>`).
String? prayerFromNotification(Map item) {
  if (item['type'] != 'adhan') return null;
  final match = RegExp(
    r'^adhan:(fajr|sunrise|dhuhr|asr|maghrib|isha):',
  ).firstMatch('${item['key']}');
  return match?.group(1);
}

/// Splits upcoming notification items: adhan-mode prayers become native
/// [AdhanEvent]s (future, within [adhanScheduleWindow]) and get no plugin
/// notification; silent prayers are dropped; everything else (notify mode,
/// reminders, and adhan mode off Android) stays with the plugin. [dua]
/// replaces the item body of native events when given.
({List<AdhanEvent> native, List<Map<String, dynamic>> plugin}) partitionAdhan(
  List<Map<String, dynamic>> items,
  Map notifications,
  DateTime now, {
  bool android = true,
  String? dua,
}) {
  final native = <AdhanEvent>[];
  final plugin = <Map<String, dynamic>>[];
  final end = now.add(adhanScheduleWindow);
  for (final item in items) {
    final at = DateTime.tryParse('${item['fireAt']}');
    if (at == null || !at.isAfter(now)) continue;
    final prayer = prayerFromNotification(item);
    if (prayer == null) {
      plugin.add(item);
      continue;
    }
    final mode = effectivePrayerMode(notifications, prayer);
    if (mode == 'silent') continue;
    if (mode == 'adhan' && android) {
      if (at.isAfter(end)) continue;
      native.add(
        AdhanEvent(
          key: '${item['key']}',
          at: at,
          prayer: prayer,
          nameAr: prayerNames[prayer]!,
          sound: soundForPrayer(notifications, prayer)!,
          respectSilent: notifications['respectSilent'] == true,
          title: item['title'] as String?,
          body: dua ?? item['body'] as String?,
        ),
      );
    } else {
      plugin.add(item);
    }
  }
  return (native: native, plugin: plugin);
}

/// The dua after the adhan, verbatim from the bundled «أذكار الآذان»
/// category; null when the asset cannot be read.
Future<String?> loadAdhanDua() async {
  try {
    final athkar = await OfflineAthkar.load();
    final items = (athkar.category('adhan')?['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    // Lookup key only; the returned text is the asset's own wording.
    final terms = searchTerms('الدعوة التامة');
    for (final item in items) {
      final text = item['text'] as String;
      if (terms.every(normalizeArabic(text).contains)) return text;
    }
  } catch (e) {
    debugPrint('loadAdhanDua failed: $e');
  }
  return null;
}

/// A user-imported audio file in app-private storage.
class AdhanSound {
  const AdhanSound({required this.id, required this.name, required this.kind});
  factory AdhanSound.fromMap(Map map) {
    final id = '${map['id']}';
    return AdhanSound(
      id: id,
      name: '${map['name'] ?? id}',
      kind: '${map['kind'] ?? id.split('_').first}',
    );
  }
  final String id;
  final String name;

  /// `fajr` or `regular`.
  final String kind;
}

class AdhanService {
  AdhanService._();
  static final instance = AdhanService._();
  static const channel = MethodChannel('fadl/adhan');

  /// The native side exists on Android only; elsewhere calls are no-ops.
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// iOS rings a clip of a bundled adhan with the notification
  /// ([iosAdhanClip]) and can preview those clips, but nothing else.
  bool get clipsOnly => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Replaces every scheduled adhan alarm with [events].
  Future<void> schedule(List<AdhanEvent> events) async {
    if (!supported) return;
    await channel.invokeMethod<void>('schedule', {
      'events': [for (final e in events) e.toMap()],
    });
  }

  Future<void> cancelAll() async {
    if (supported) await channel.invokeMethod<void>('cancelAll');
  }

  Future<void> preview(String soundId) async {
    if (supported || clipsOnly) {
      await channel.invokeMethod<void>('preview', {'soundId': soundId});
    }
  }

  Future<void> stopPreview() async {
    if (supported || clipsOnly) {
      await channel.invokeMethod<void>('stopPreview');
    }
  }

  /// Opens the system audio picker and copies the file into app storage;
  /// null when cancelled. [kind] is `fajr` or `regular`.
  Future<AdhanSound?> pickAndImport({required String kind}) async {
    assert(kind == 'fajr' || kind == 'regular');
    if (!supported) return null;
    final result = await channel.invokeMapMethod<String, dynamic>(
      'pickAndImport',
      {'kind': kind},
    );
    return result == null ? null : AdhanSound.fromMap(result);
  }

  Future<List<AdhanSound>> listImported() async {
    if (!supported) return const [];
    final list = await channel.invokeListMethod<dynamic>('listImported');
    return [for (final item in list ?? const []) AdhanSound.fromMap(item)];
  }

  Future<void> deleteImported(String id) async {
    if (supported) {
      await channel.invokeMethod<void>('deleteImported', {'id': id});
    }
  }

  /// Opens the battery-optimisation list so the user can exempt the app.
  Future<void> openBatterySettings() async {
    if (supported) await channel.invokeMethod<void>('openBatterySettings');
  }

  /// Whether alarms fire at the exact minute (Alarms & reminders access).
  /// Null when unknown (non-Android).
  Future<bool?> canScheduleExactAlarms() async {
    if (!supported) return null;
    return channel.invokeMethod<bool>('canScheduleExactAlarms');
  }

  /// Opens the system page where the user allows exact alarms.
  Future<void> openExactAlarmSettings() async {
    if (supported) await channel.invokeMethod<void>('openExactAlarmSettings');
  }

  /// Null when unknown (non-Android).
  Future<bool?> isIgnoringBatteryOptimizations() async {
    if (!supported) return null;
    return channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
  }

  /// Arms a real alarm one minute from now playing [soundId].
  Future<void> testAlarm(String soundId, {bool respectSilent = false}) async {
    if (!supported) return;
    final now = DateTime.now();
    await channel.invokeMethod<void>('testAlarm', {
      'event': AdhanEvent(
        key: 'test:${now.millisecondsSinceEpoch}',
        at: now.add(const Duration(minutes: 1)),
        prayer: 'test',
        nameAr: '',
        sound: soundId,
        respectSilent: respectSilent,
        title: 'تجربة الأذان',
      ).toMap(),
    });
  }
}
