import { addDays, type YMD, ymdToDate } from './time.js';

export const HIJRI_MONTHS_AR = [
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
] as const;

export const WEEKDAYS_AR = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

export const GREGORIAN_MONTHS_AR = [
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

export interface HijriDate {
  year: number;
  month: number; // 1..12
  day: number;
  monthNameAr: string;
  formattedAr: string; // "١٢ ربيع الأول ١٤٤٧ هـ"
}

const formatter = new Intl.DateTimeFormat('en-US-u-ca-islamic-umalqura', {
  timeZone: 'UTC',
  year: 'numeric',
  month: 'numeric',
  day: 'numeric',
});

const arDigits = new Intl.NumberFormat('ar-SA', { useGrouping: false });

/**
 * Converts a Gregorian calendar date to the Umm al-Qura Hijri calendar.
 * `adjustment` shifts the result by whole days to follow local moon sighting.
 */
export function toHijri(date: YMD, adjustment = 0): HijriDate {
  const shifted = addDays(date, adjustment);
  const parts = Object.fromEntries(
    formatter.formatToParts(ymdToDate(shifted)).map((p) => [p.type, p.value]),
  );
  const year = Number.parseInt(parts.year ?? parts.relatedYear ?? '', 10);
  const month = Number(parts.month);
  const day = Number(parts.day);
  const monthNameAr = HIJRI_MONTHS_AR[month - 1]!;
  return {
    year,
    month,
    day,
    monthNameAr,
    formattedAr: `${arDigits.format(day)} ${monthNameAr} ${arDigits.format(year)} هـ`,
  };
}

/** Finds the Gregorian date of the first day of a Hijri month. */
export function hijriMonthStart(hijriYear: number, hijriMonth: number, adjustment = 0): YMD {
  // Mean Hijri month length is ~29.5306 days; Hijri day 1/1/1 ≈ 622-07-19 (proleptic Gregorian).
  const monthsSinceEpoch = (hijriYear - 1) * 12 + (hijriMonth - 1);
  const approxMs = Date.UTC(622, 6, 19) + monthsSinceEpoch * 29.530588 * 86400000;
  const approx = new Date(approxMs);
  let cursor: YMD = {
    year: approx.getUTCFullYear(),
    month: approx.getUTCMonth() + 1,
    day: approx.getUTCDate(),
  };
  cursor = addDays(cursor, -20);
  for (let i = 0; i < 45; i++) {
    const h = toHijri(cursor, adjustment);
    if (h.year === hijriYear && h.month === hijriMonth && h.day === 1) return cursor;
    cursor = addDays(cursor, 1);
  }
  throw new Error(`Could not locate ${hijriMonth}/${hijriYear} in the Umm al-Qura calendar`);
}

/** Number of days in a Hijri month (29 or 30). */
export function hijriMonthLength(hijriYear: number, hijriMonth: number, adjustment = 0): number {
  const start = hijriMonthStart(hijriYear, hijriMonth, adjustment);
  return toHijri(addDays(start, 29), adjustment).day === 30 ? 30 : 29;
}
