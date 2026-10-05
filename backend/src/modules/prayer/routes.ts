import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { toHijri, GREGORIAN_MONTHS_AR, WEEKDAYS_AR } from '../../lib/hijri.js';
import { latitudeSchema, longitudeSchema, prayerQuerySchema, timezoneSchema, ymdSchema } from '../../lib/schemas.js';
import { addDays, parseYMD, todayIn, weekdayOf, type YMD } from '../../lib/time.js';
import { CALC_METHODS, CALC_METHOD_KEYS, computeDay, nextPrayer, qibla, serializeDay, type PrayerOptions } from './calc.js';

export function toPrayerOptions(q: z.infer<typeof prayerQuerySchema>): PrayerOptions {
  return {
    latitude: q.lat,
    longitude: q.lng,
    timezone: q.tz,
    method: q.method,
    madhab: q.madhab,
    highLatRule: q.highLatRule ?? null,
    hijriAdjustment: q.hijriAdjustment,
  };
}

const arNum = new Intl.NumberFormat('ar-SA', { useGrouping: false });

export function gregorianAr(d: YMD): string {
  return `${WEEKDAYS_AR[weekdayOf(d)]} ${arNum.format(d.day)} ${GREGORIAN_MONTHS_AR[d.month - 1]} ${arNum.format(d.year)}م`;
}

/** Prayer times for one day plus the "next prayer" countdown used by the home screen. */
export function prayerDayPayload(opts: PrayerOptions, date: YMD, now = new Date()) {
  const day = computeDay(date, opts);
  const next = nextPrayer(todayIn(opts.timezone, now), opts, now);
  return {
    ...serializeDay(day, opts.timezone),
    gregorianAr: gregorianAr(date),
    timezone: opts.timezone,
    method: { key: opts.method, nameAr: CALC_METHODS[opts.method].nameAr },
    next: { ...next, time: next.time.toISOString() },
    qibla: qibla(opts.latitude, opts.longitude),
  };
}

export const prayerRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get(
    '/prayer/methods',
    { schema: { tags: ['prayer'], summary: 'Supported calculation methods' } },
    async () => ({
      methods: CALC_METHOD_KEYS.map((key) => ({ key, nameAr: CALC_METHODS[key].nameAr })),
      madhabs: [
        { key: 'shafi', nameAr: 'الجمهور (الشافعي، المالكي، الحنبلي)' },
        { key: 'hanafi', nameAr: 'الحنفي' },
      ],
      highLatRules: ['middleofthenight', 'seventhofthenight', 'twilightangle'],
    }),
  );

  app.get(
    '/prayer/times',
    {
      schema: {
        tags: ['prayer'],
        summary: 'Prayer times for a day, the next prayer countdown and qibla',
        querystring: prayerQuerySchema.extend({ date: ymdSchema.optional() }),
      },
    },
    async (req) => {
      const opts = toPrayerOptions(req.query);
      const date = req.query.date ? parseYMD(req.query.date) : todayIn(opts.timezone);
      return prayerDayPayload(opts, date);
    },
  );

  app.get(
    '/prayer/calendar',
    {
      schema: {
        tags: ['prayer'],
        summary: 'Prayer times for a whole Gregorian month',
        querystring: prayerQuerySchema.extend({
          year: z.coerce.number().int().min(1900).max(2200),
          month: z.coerce.number().int().min(1).max(12),
        }),
      },
    },
    async (req) => {
      const opts = toPrayerOptions(req.query);
      const days = [];
      let cursor: YMD = { year: req.query.year, month: req.query.month, day: 1 };
      while (cursor.month === req.query.month) {
        days.push(serializeDay(computeDay(cursor, opts), opts.timezone));
        cursor = addDays(cursor, 1);
      }
      return { timezone: opts.timezone, method: opts.method, days };
    },
  );

  app.get(
    '/qibla',
    {
      schema: {
        tags: ['prayer'],
        summary: 'Qibla bearing (degrees from true north) and distance to the Kaaba',
        querystring: z.object({ lat: latitudeSchema, lng: longitudeSchema }),
      },
    },
    async (req) => qibla(req.query.lat, req.query.lng),
  );

  app.get(
    '/hijri',
    {
      schema: {
        tags: ['prayer'],
        summary: 'Convert a Gregorian date to Hijri (Umm al-Qura)',
        querystring: z.object({
          date: ymdSchema.optional(),
          tz: timezoneSchema.default('Asia/Riyadh'),
          adjustment: z.coerce.number().int().min(-3).max(3).default(0),
        }),
      },
    },
    async (req) => {
      const date = req.query.date ? parseYMD(req.query.date) : todayIn(req.query.tz);
      return { gregorian: date, gregorianAr: gregorianAr(date), hijri: toHijri(date, req.query.adjustment) };
    },
  );
};
