import {
  CalculationMethod,
  type CalculationParameters,
  Coordinates,
  HighLatitudeRule,
  Madhab,
  PrayerTimes,
  Qibla,
  SunnahTimes,
} from 'adhan';
import { toHijri, type HijriDate } from '../../lib/hijri.js';
import { addDays, formatHM, formatYMD, type YMD } from '../../lib/time.js';

export const CALC_METHODS = {
  UmmAlQura: { nameAr: 'جامعة أم القرى - مكة المكرمة', factory: () => CalculationMethod.UmmAlQura() },
  Egyptian: { nameAr: 'الهيئة المصرية العامة للمساحة', factory: () => CalculationMethod.Egyptian() },
  MuslimWorldLeague: { nameAr: 'رابطة العالم الإسلامي', factory: () => CalculationMethod.MuslimWorldLeague() },
  Karachi: { nameAr: 'جامعة العلوم الإسلامية - كراتشي', factory: () => CalculationMethod.Karachi() },
  Dubai: { nameAr: 'دبي', factory: () => CalculationMethod.Dubai() },
  Kuwait: { nameAr: 'الكويت', factory: () => CalculationMethod.Kuwait() },
  Qatar: { nameAr: 'قطر', factory: () => CalculationMethod.Qatar() },
  Singapore: { nameAr: 'سنغافورة', factory: () => CalculationMethod.Singapore() },
  Turkey: { nameAr: 'رئاسة الشؤون الدينية التركية', factory: () => CalculationMethod.Turkey() },
  Tehran: { nameAr: 'معهد الجيوفيزياء - طهران', factory: () => CalculationMethod.Tehran() },
  NorthAmerica: { nameAr: 'الجمعية الإسلامية لأمريكا الشمالية (ISNA)', factory: () => CalculationMethod.NorthAmerica() },
  MoonsightingCommittee: { nameAr: 'لجنة رؤية الهلال', factory: () => CalculationMethod.MoonsightingCommittee() },
} as const;

export type CalcMethod = keyof typeof CALC_METHODS;
export const CALC_METHOD_KEYS = Object.keys(CALC_METHODS) as [CalcMethod, ...CalcMethod[]];

export const MADHABS = ['shafi', 'hanafi'] as const;
export type MadhabKey = (typeof MADHABS)[number];

export const HIGH_LAT_RULES = ['middleofthenight', 'seventhofthenight', 'twilightangle'] as const;
export type HighLatRuleKey = (typeof HIGH_LAT_RULES)[number];

export const PRAYERS = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'] as const;
export type PrayerName = (typeof PRAYERS)[number];

export const PRAYER_NAMES_AR: Record<PrayerName, string> = {
  fajr: 'الفجر',
  sunrise: 'الشروق',
  dhuhr: 'الظهر',
  asr: 'العصر',
  maghrib: 'المغرب',
  isha: 'العشاء',
};

export interface PrayerOptions {
  latitude: number;
  longitude: number;
  timezone: string;
  method: CalcMethod;
  madhab: MadhabKey;
  highLatRule?: HighLatRuleKey | null;
  /** Minutes added to individual prayers. */
  adjustments?: Partial<Record<PrayerName, number>>;
  hijriAdjustment?: number;
}

export interface DayPrayerTimes {
  date: string; // YYYY-MM-DD (local)
  hijri: HijriDate;
  times: Record<PrayerName, Date>;
  /** Start of the last third of the night (for qiyam), and midnight. */
  lastThirdOfNight: Date;
  middleOfNight: Date;
}

function buildParams(opts: PrayerOptions, hijri: HijriDate): CalculationParameters {
  const params = CALC_METHODS[opts.method].factory();
  params.madhab = opts.madhab === 'hanafi' ? Madhab.Hanafi : Madhab.Shafi;
  if (opts.highLatRule) {
    params.highLatitudeRule = {
      middleofthenight: HighLatitudeRule.MiddleOfTheNight,
      seventhofthenight: HighLatitudeRule.SeventhOfTheNight,
      twilightangle: HighLatitudeRule.TwilightAngle,
    }[opts.highLatRule];
  }
  // Umm al-Qura uses 120 minutes after maghrib for isha during Ramadan.
  if (opts.method === 'UmmAlQura' && hijri.month === 9) params.ishaInterval = 120;
  const adj = opts.adjustments ?? {};
  params.adjustments = {
    fajr: adj.fajr ?? 0,
    sunrise: adj.sunrise ?? 0,
    dhuhr: adj.dhuhr ?? 0,
    asr: adj.asr ?? 0,
    maghrib: adj.maghrib ?? 0,
    isha: adj.isha ?? 0,
  };
  return params;
}

/** adhan reads the calendar day from a Date using the process's local timezone. */
function localDateFor(d: YMD): Date {
  return new Date(d.year, d.month - 1, d.day, 12, 0, 0);
}

export function computeDay(date: YMD, opts: PrayerOptions): DayPrayerTimes {
  const hijri = toHijri(date, opts.hijriAdjustment ?? 0);
  const coords = new Coordinates(opts.latitude, opts.longitude);
  const pt = new PrayerTimes(coords, localDateFor(date), buildParams(opts, hijri));
  const sunnah = new SunnahTimes(pt);
  return {
    date: formatYMD(date),
    hijri,
    times: {
      fajr: pt.fajr,
      sunrise: pt.sunrise,
      dhuhr: pt.dhuhr,
      asr: pt.asr,
      maghrib: pt.maghrib,
      isha: pt.isha,
    },
    lastThirdOfNight: sunnah.lastThirdOfTheNight,
    middleOfNight: sunnah.middleOfTheNight,
  };
}

export interface NextPrayer {
  name: PrayerName;
  nameAr: string;
  time: Date;
  secondsRemaining: number;
}

/** Next obligatory prayer (sunrise excluded) after `now`, looking into tomorrow if needed. */
export function nextPrayer(today: YMD, opts: PrayerOptions, now: Date): NextPrayer {
  for (const day of [today, addDays(today, 1)]) {
    const { times } = computeDay(day, opts);
    for (const name of PRAYERS) {
      if (name === 'sunrise') continue;
      if (times[name].getTime() > now.getTime()) {
        return {
          name,
          nameAr: PRAYER_NAMES_AR[name],
          time: times[name],
          secondsRemaining: Math.floor((times[name].getTime() - now.getTime()) / 1000),
        };
      }
    }
  }
  throw new Error('Unable to determine the next prayer');
}

export function serializeDay(day: DayPrayerTimes, tz: string) {
  return {
    date: day.date,
    hijri: day.hijri,
    prayers: PRAYERS.map((name) => ({
      name,
      nameAr: PRAYER_NAMES_AR[name],
      time: day.times[name].toISOString(),
      local: formatHM(day.times[name], tz),
    })),
    lastThirdOfNight: { time: day.lastThirdOfNight.toISOString(), local: formatHM(day.lastThirdOfNight, tz) },
    middleOfNight: { time: day.middleOfNight.toISOString(), local: formatHM(day.middleOfNight, tz) },
  };
}

// ───────────────────────────── Qibla ─────────────────────────────

export const KAABA = { latitude: 21.422487, longitude: 39.826206 };

/** Great-circle distance in kilometres (haversine). */
export function distanceKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371.0088;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

const COMPASS_AR = ['شمال', 'شمال شرق', 'شرق', 'جنوب شرق', 'جنوب', 'جنوب غرب', 'غرب', 'شمال غرب'];

export function qibla(latitude: number, longitude: number) {
  const bearing = Qibla(new Coordinates(latitude, longitude));
  return {
    /** Degrees clockwise from true north. */
    bearing: Math.round(bearing * 100) / 100,
    direction: COMPASS_AR[Math.round(bearing / 45) % 8]!,
    distanceKm: Math.round(distanceKm(latitude, longitude, KAABA.latitude, KAABA.longitude)),
    kaaba: KAABA,
  };
}
