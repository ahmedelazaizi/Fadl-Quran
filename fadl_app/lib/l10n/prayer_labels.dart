import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/audio_store.dart';
import '../core/format.dart';
import 'app_localizations.dart';

AppLocalizations prayerL(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('ar'));

bool englishPrayerUi(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'en';

String prayerNumber(BuildContext context, Object? value) =>
    englishPrayerUi(context) ? '$value' : arNum(value ?? '');

String prayerBytes(BuildContext context, int bytes) =>
    formatBytes(bytes, english: englishPrayerUi(context));

String prayerTime(BuildContext context, String hm) {
  if (!englishPrayerUi(context)) return hm12(hm);
  final parts = hm.split(':');
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
  );
}

String prayerHijriDate(BuildContext context, Map hijri) {
  if (!englishPrayerUi(context)) return hijri['formattedAr'] as String;
  final l = prayerL(context);
  final month = switch (hijri['month']) {
    1 => l.hijriMuharram,
    2 => l.hijriSafar,
    3 => l.hijriRabiI,
    4 => l.hijriRabiII,
    5 => l.hijriJumadaI,
    6 => l.hijriJumadaII,
    7 => l.hijriRajab,
    8 => l.hijriShaban,
    9 => l.hijriRamadan,
    10 => l.hijriShawwal,
    11 => l.hijriDhulQadah,
    _ => l.hijriDhulHijjah,
  };
  return l.hijriDate('${hijri['day']}', month, '${hijri['year']}');
}

String prayerLabel(AppLocalizations l, String id) => switch (id) {
  'fajr' => l.prayerFajr,
  'sunrise' => l.prayerSunrise,
  'dhuhr' => l.prayerDhuhr,
  'asr' => l.prayerAsr,
  'maghrib' => l.prayerMaghrib,
  'isha' => l.prayerIsha,
  _ => id,
};

String prayerStatusLabel(AppLocalizations l, String? id) => switch (id) {
  'onTime' => l.trackerOnTime,
  'congregation' => l.trackerCongregation,
  'late' => l.trackerLate,
  'missed' => l.trackerMissed,
  _ => l.trackerUnrecorded,
};

String fastingTypeLabel(AppLocalizations l, String? id) => switch (id) {
  'ramadan' => l.trackerFastRamadan,
  'shawwal' => l.trackerFastShawwal,
  'voluntary' => l.trackerFastOther,
  'makeup' => l.trackerFastQada,
  _ => l.trackerNoFast,
};

String calculationLabel(AppLocalizations l, String id) => switch (id) {
  'UmmAlQura' => l.methodUmmAlQura,
  'Egyptian' => l.methodEgyptian,
  'MuslimWorldLeague' => l.methodMuslimWorldLeague,
  'Karachi' => l.methodKarachi,
  'Dubai' => l.methodDubai,
  'Kuwait' => l.methodKuwait,
  'Qatar' => l.methodQatar,
  'Singapore' => l.methodSingapore,
  'Turkey' => l.methodTurkey,
  'Tehran' => l.methodTehran,
  'NorthAmerica' => l.methodNorthAmerica,
  'MoonsightingCommittee' => l.methodMoonsightingCommittee,
  _ => id,
};

String madhabLabel(AppLocalizations l, String id) => switch (id) {
  'shafi' => l.madhabShafi,
  'hanafi' => l.madhabHanafi,
  _ => id,
};

String adhanModeLabel(AppLocalizations l, String id) => switch (id) {
  'adhan' => l.modeAdhan,
  'notify' => l.modeNotify,
  'silent' => l.modeSilent,
  _ => id,
};

String cityLabel(AppLocalizations l, City city) => switch (city.nameAr) {
  'الرياض، السعودية' => l.cityRiyadh,
  'مكة المكرمة، السعودية' => l.cityMakkah,
  'المدينة المنورة، السعودية' => l.cityMadinah,
  'جدة، السعودية' => l.cityJeddah,
  'القاهرة، مصر' => l.cityCairo,
  'الإسكندرية، مصر' => l.cityAlexandria,
  'دبي، الإمارات' => l.cityDubai,
  'الكويت، الكويت' => l.cityKuwait,
  'الدوحة، قطر' => l.cityDoha,
  'عمّان، الأردن' => l.cityAmman,
  'الدار البيضاء، المغرب' => l.cityCasablanca,
  'إسطنبول، تركيا' => l.cityIstanbul,
  _ => city.nameAr,
};

String locationLabel(AppLocalizations l, String? stored) {
  if (stored == null || stored == 'موقعي الحالي') return l.currentLocation;
  for (final city in presetCities) {
    if (city.nameAr == stored) return cityLabel(l, city);
  }
  return stored;
}

String compassLabel(AppLocalizations l, String? direction) =>
    switch (direction) {
      'شمال' => l.north,
      'شمال شرق' => l.northEast,
      'شرق' => l.east,
      'جنوب شرق' => l.southEast,
      'جنوب' => l.south,
      'جنوب غرب' => l.southWest,
      'غرب' => l.west,
      'شمال غرب' => l.northWest,
      _ => direction ?? '',
    };
