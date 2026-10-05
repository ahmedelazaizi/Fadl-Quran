import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { hijriMonthLength, hijriMonthStart, toHijri, WEEKDAYS_AR } from '../../lib/hijri.js';
import { prayerQuerySchema } from '../../lib/schemas.js';
import { addDays, diffDays, formatHM, formatYMD, todayIn, weekdayOf, type YMD } from '../../lib/time.js';
import { computeDay, type PrayerOptions } from '../prayer/calc.js';
import { toPrayerOptions } from '../prayer/routes.js';

const RAMADAN = 9;

/** Well-known events, keyed by Ramadan day. */
const RAMADAN_NOTES: Record<number, string> = {
  1: 'أول أيام رمضان',
  17: 'ذكرى غزوة بدر الكبرى',
  20: 'ذكرى فتح مكة',
  21: 'بداية العشر الأواخر',
};

export interface ImsakiyaOptions {
  hijriYear: number;
  imsakMinutes: number;
  taraweehOffset: number;
}

export function buildImsakiya(opts: PrayerOptions, o: ImsakiyaOptions) {
  const start = hijriMonthStart(o.hijriYear, RAMADAN, opts.hijriAdjustment ?? 0);
  const length = hijriMonthLength(o.hijriYear, RAMADAN, opts.hijriAdjustment ?? 0);
  const tz = opts.timezone;
  const days = Array.from({ length }, (_, i) => {
    const date = addDays(start, i);
    const { times } = computeDay(date, opts);
    const imsak = new Date(times.fajr.getTime() - o.imsakMinutes * 60000);
    const taraweeh = new Date(times.isha.getTime() + o.taraweehOffset * 60000);
    const fastingMinutes = Math.round((times.maghrib.getTime() - times.fajr.getTime()) / 60000);
    const ramadanDay = i + 1;
    const nextNight = ramadanDay + 1;
    return {
      ramadanDay,
      date: formatYMD(date),
      weekdayAr: WEEKDAYS_AR[weekdayOf(date)],
      note: RAMADAN_NOTES[ramadanDay] ?? null,
      /** The coming night (after this day's maghrib) is an odd night of the last ten. */
      oddNightTonight: nextNight >= 21 && nextNight <= length && nextNight % 2 === 1,
      imsak: formatHM(imsak, tz),
      fajr: formatHM(times.fajr, tz),
      sunrise: formatHM(times.sunrise, tz),
      dhuhr: formatHM(times.dhuhr, tz),
      asr: formatHM(times.asr, tz),
      maghrib: formatHM(times.maghrib, tz),
      isha: formatHM(times.isha, tz),
      taraweeh: formatHM(taraweeh, tz),
      fastingDuration: { hours: Math.floor(fastingMinutes / 60), minutes: fastingMinutes % 60 },
      instants: { imsak: imsak.toISOString(), fajr: times.fajr.toISOString(), maghrib: times.maghrib.toISOString() },
    };
  });
  return { start, length, days };
}

/** Live info for "today" during Ramadan: iftar countdown, tomorrow's imsak and days to Eid. */
function todaySummary(
  imsakiya: ReturnType<typeof buildImsakiya>,
  today: YMD,
  now: Date,
) {
  const index = diffDays(today, imsakiya.start);
  if (index < 0 || index >= imsakiya.length) return null;
  const day = imsakiya.days[index]!;
  const tomorrow = imsakiya.days[index + 1] ?? null;
  const iftarAt = new Date(day.instants.maghrib);
  return {
    ramadanDay: day.ramadanDay,
    iftar: day.maghrib,
    secondsToIftar: Math.max(0, Math.floor((iftarAt.getTime() - now.getTime()) / 1000)),
    tomorrowImsak: tomorrow?.imsak ?? null,
    tomorrowFajr: tomorrow?.fajr ?? null,
    daysToEid: imsakiya.length - index,
  };
}

export const ramadanRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get(
    '/ramadan/imsakiya',
    {
      schema: {
        tags: ['ramadan'],
        summary: 'Ramadan timetable (imsak, iftar, taraweeh) and live countdowns',
        querystring: prayerQuerySchema.extend({
          hijriYear: z.coerce.number().int().min(1400).max(1600).optional(),
          imsakMinutes: z.coerce.number().int().min(0).max(30).default(10),
          taraweehOffset: z.coerce.number().int().min(0).max(120).default(15),
          period: z.enum(['first', 'middle', 'last', 'all']).default('all'),
        }),
      },
    },
    async (req) => {
      const opts = toPrayerOptions(req.query);
      const now = new Date();
      const today = todayIn(opts.timezone, now);
      const hijriToday = toHijri(today, opts.hijriAdjustment);
      const hijriYear =
        req.query.hijriYear ?? (hijriToday.month > RAMADAN ? hijriToday.year + 1 : hijriToday.year);

      const imsakiya = buildImsakiya(opts, {
        hijriYear,
        imsakMinutes: req.query.imsakMinutes,
        taraweehOffset: req.query.taraweehOffset,
      });
      const ranges = { first: [1, 10], middle: [11, 20], last: [21, 30], all: [1, 30] } as const;
      const [from, to] = ranges[req.query.period];
      return {
        hijriYear,
        startDate: formatYMD(imsakiya.start),
        length: imsakiya.length,
        eidAlFitr: formatYMD(addDays(imsakiya.start, imsakiya.length)),
        timezone: opts.timezone,
        today: todaySummary(imsakiya, today, now),
        daysUntilRamadan: Math.max(0, diffDays(imsakiya.start, today)),
        days: imsakiya.days.filter((d) => d.ramadanDay >= from && d.ramadanDay <= to),
      };
    },
  );
};
