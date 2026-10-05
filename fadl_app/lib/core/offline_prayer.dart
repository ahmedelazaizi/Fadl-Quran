import 'dart:math' as math;

import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'format.dart';
import 'umm_al_qura_months.dart';

const calcMethods = <String, String>{
  'UmmAlQura': 'جامعة أم القرى - مكة المكرمة',
  'Egyptian': 'الهيئة المصرية العامة للمساحة',
  'MuslimWorldLeague': 'رابطة العالم الإسلامي',
  'Karachi': 'جامعة العلوم الإسلامية - كراتشي',
  'Dubai': 'دبي',
  'Kuwait': 'الكويت',
  'Qatar': 'قطر',
  'Singapore': 'سنغافورة',
  'Turkey': 'رئاسة الشؤون الدينية التركية',
  'Tehran': 'معهد الجيوفيزياء - طهران',
  'NorthAmerica': 'الجمعية الإسلامية لأمريكا الشمالية (ISNA)',
  'MoonsightingCommittee': 'لجنة رؤية الهلال',
};

const prayerNamesAr = <String, String>{
  'fajr': 'الفجر',
  'sunrise': 'الشروق',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};

const _hijriMonths = [
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];
const _weekdays = [
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];
const _gregorianMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];
const _compass = [
  'شمال',
  'شمال شرق',
  'شرق',
  'جنوب شرق',
  'جنوب',
  'جنوب غرب',
  'غرب',
  'شمال غرب',
];

class OfflinePrayer {
  OfflinePrayer._();

  static bool _zonesReady = false;

  static tz.Location location(String name) {
    if (!_zonesReady) {
      tzdata.initializeTimeZones();
      _zonesReady = true;
    }
    return tz.getLocation(name);
  }

  static DateTime today(String timezone, DateTime now) {
    final local = tz.TZDateTime.from(now, location(timezone));
    return DateTime.utc(local.year, local.month, local.day);
  }

  static Map<String, dynamic> hijri(DateTime day, [int adjustment = 0]) {
    final shifted = DateTime.utc(day.year, day.month, day.day + adjustment);
    final epochDay =
        shifted.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    var low = 0;
    var high = ummAlQuraMonths.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (ummAlQuraMonths[middle].$3 <= epochDay) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    if (low == 0 || low == ummAlQuraMonths.length) {
      throw RangeError('Umm al-Qura calendar supports 1900–2200 only');
    }
    final (year, month, start) = ummAlQuraMonths[low - 1];
    final date = epochDay - start + 1;
    return {
      'year': year,
      'month': month,
      'day': date,
      'monthNameAr': _hijriMonths[month - 1],
      'formattedAr':
          '${arNum(date)} ${_hijriMonths[month - 1]} ${arNum(year)} هـ',
    };
  }

  static adhan.CalculationParameters parameters(
    Map<String, dynamic> settings,
    DateTime day,
  ) {
    final method = (settings['calcMethod'] as String?) ?? 'UmmAlQura';
    final params = switch (method) {
      'UmmAlQura' => adhan.CalculationMethodParameters.ummAlQura(),
      'Egyptian' => adhan.CalculationMethodParameters.egyptian(),
      'MuslimWorldLeague' =>
        adhan.CalculationMethodParameters.muslimWorldLeague(),
      'Karachi' => adhan.CalculationMethodParameters.karachi(),
      'Dubai' => adhan.CalculationMethodParameters.dubai(),
      'Kuwait' => adhan.CalculationMethodParameters.kuwait(),
      'Qatar' => adhan.CalculationMethodParameters.qatar(),
      'Singapore' => adhan.CalculationMethodParameters.singapore(),
      'Turkey' => adhan.CalculationMethodParameters.turkiye(),
      'Tehran' => adhan.CalculationMethodParameters.tehran(),
      'NorthAmerica' => adhan.CalculationMethodParameters.northAmerica(),
      'MoonsightingCommittee' =>
        adhan.CalculationMethodParameters.moonsightingCommittee(),
      _ => throw ArgumentError.value(method, 'calcMethod'),
    };
    params.madhab = switch (settings['madhab'] ?? 'shafi') {
      'shafi' => adhan.Madhab.shafi,
      'hanafi' => adhan.Madhab.hanafi,
      final unknown => throw ArgumentError.value(unknown, 'madhab'),
    };
    params.highLatitudeRule = switch (settings['highLatRule']) {
      null || 'middleofthenight' => adhan.HighLatitudeRule.middleOfTheNight,
      'seventhofthenight' => adhan.HighLatitudeRule.seventhOfTheNight,
      'twilightangle' => adhan.HighLatitudeRule.twilightAngle,
      final unknown => throw ArgumentError.value(unknown, 'highLatRule'),
    };
    if (method == 'UmmAlQura' &&
        hijri(
              day,
              (settings['hijriAdjustment'] as num?)?.toInt() ?? 0,
            )['month'] ==
            9) {
      params.ishaInterval = 120;
    }
    final adjustments = (settings['adjustments'] as Map?) ?? const {};
    params.adjustments = {
      for (final entry in _prayerEnums.entries)
        entry.value: (adjustments[entry.key] as num?)?.toInt() ?? 0,
    };
    return params;
  }

  static const _prayerEnums = <String, adhan.Prayer>{
    'fajr': adhan.Prayer.fajr,
    'sunrise': adhan.Prayer.sunrise,
    'dhuhr': adhan.Prayer.dhuhr,
    'asr': adhan.Prayer.asr,
    'maghrib': adhan.Prayer.maghrib,
    'isha': adhan.Prayer.isha,
  };

  static Map<String, dynamic> day(
    Map<String, dynamic> settings,
    DateTime date,
  ) {
    final timezone = (settings['timezone'] as String?) ?? 'Asia/Riyadh';
    final zone = location(timezone);
    final dayDate = DateTime.utc(date.year, date.month, date.day);
    final method = (settings['calcMethod'] as String?) ?? 'UmmAlQura';
    final params = parameters(settings, dayDate);
    final times = adhan.PrayerTimes(
      coordinates: adhan.Coordinates(
        (settings['latitude'] as num).toDouble(),
        (settings['longitude'] as num).toDouble(),
      ),
      date: dayDate,
      calculationParameters: params,
      precision: method == 'Singapore',
    );
    DateTime prayerTime(adhan.Prayer prayer) {
      final time = times.timeForPrayer(prayer);
      // JS adhan rounds Singapore up, including times already on a minute.
      return method == 'Singapore'
          ? time.add(Duration(seconds: 60 - time.second))
          : time;
    }

    final DateTime middleOfNight;
    final DateTime lastThird;
    if (method == 'Singapore') {
      final nextDay = dayDate.add(const Duration(days: 1));
      final tomorrow = adhan.PrayerTimes(
        coordinates: times.coordinates,
        date: nextDay,
        calculationParameters: params,
        precision: true,
      );
      final maghrib = prayerTime(adhan.Prayer.maghrib);
      final fajr = tomorrow.fajr.add(
        Duration(seconds: 60 - tomorrow.fajr.second),
      );
      final night = fajr.difference(maghrib).inMilliseconds;
      DateTime nearestMinute(DateTime time) => time.add(
        Duration(seconds: time.second >= 30 ? 60 - time.second : -time.second),
      );
      middleOfNight = nearestMinute(
        maghrib.add(Duration(milliseconds: night ~/ 2)),
      );
      lastThird = nearestMinute(
        maghrib.add(Duration(milliseconds: night * 2 ~/ 3)),
      );
    } else {
      final sunnah = adhan.SunnahTimes(times, precision: false);
      middleOfNight = sunnah.middleOfTheNight;
      lastThird = sunnah.lastThirdOfTheNight;
    }
    String local(DateTime instant) {
      final time = tz.TZDateTime.from(instant, zone);
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }

    Map<String, String> instant(DateTime time) => {
      'time': time.toUtc().toIso8601String(),
      'local': local(time),
    };
    return {
      'date':
          '${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}',
      'hijri': hijri(
        dayDate,
        (settings['hijriAdjustment'] as num?)?.toInt() ?? 0,
      ),
      'gregorianAr':
          '${_weekdays[dayDate.weekday % 7]} ${arNum(dayDate.day)} ${_gregorianMonths[dayDate.month - 1]} ${arNum(dayDate.year)}م',
      'timezone': timezone,
      'method': {'key': method, 'nameAr': calcMethods[method] ?? method},
      'prayers': [
        for (final prayer in _prayerEnums.entries)
          {
            'name': prayer.key,
            'nameAr': prayerNamesAr[prayer.key],
            ...instant(prayerTime(prayer.value)),
          },
      ],
      'lastThirdOfNight': instant(lastThird),
      'middleOfNight': instant(middleOfNight),
    };
  }

  static Map<String, dynamic> nextPrayer(
    Map<String, dynamic> settings,
    DateTime now,
  ) {
    final start = today(
      (settings['timezone'] as String?) ?? 'Asia/Riyadh',
      now,
    );
    for (final offset in [0, 1]) {
      final prayers =
          (day(settings, start.add(Duration(days: offset)))['prayers'] as List)
              .cast<Map<String, dynamic>>();
      for (final prayer in prayers) {
        if (prayer['name'] == 'sunrise') continue;
        final at = DateTime.parse(prayer['time'] as String);
        if (at.isAfter(now)) {
          return {
            'name': prayer['name'],
            'nameAr': prayer['nameAr'],
            'time': prayer['time'],
            'secondsRemaining': at.difference(now).inSeconds,
          };
        }
      }
    }
    throw StateError('Unable to determine the next prayer');
  }

  static Map<String, dynamic> payload(
    Map<String, dynamic> settings,
    DateTime now,
  ) {
    final daily = day(
      settings,
      today((settings['timezone'] as String?) ?? 'Asia/Riyadh', now),
    );
    return {
      ...daily,
      'next': nextPrayer(settings, now),
      'qibla': qibla(
        (settings['latitude'] as num).toDouble(),
        (settings['longitude'] as num).toDouble(),
      ),
      'locationName': settings['locationName'],
    };
  }

  static Map<String, dynamic> qibla(double latitude, double longitude) {
    const kaabaLat = 21.422487, kaabaLng = 39.826206;
    final lat = latitude * math.pi / 180;
    final targetLat = kaabaLat * math.pi / 180;
    final deltaLng = (kaabaLng - longitude) * math.pi / 180;
    final bearing =
        (math.atan2(
                  math.sin(deltaLng),
                  math.cos(lat) * math.tan(targetLat) -
                      math.sin(lat) * math.cos(deltaLng),
                ) *
                180 /
                math.pi +
            360) %
        360;
    final dLat = targetLat - lat;
    final haversine =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat) *
            math.cos(targetLat) *
            math.pow(math.sin(deltaLng / 2), 2);
    return {
      'bearing': (bearing * 100).round() / 100,
      'direction': _compass[(bearing / 45).round() % 8],
      'distanceKm': (2 * 6371.0088 * math.asin(math.sqrt(haversine))).round(),
      'kaaba': {'latitude': kaabaLat, 'longitude': kaabaLng},
    };
  }
}
