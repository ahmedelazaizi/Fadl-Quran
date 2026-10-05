import { z } from 'zod';
import { CALC_METHOD_KEYS, HIGH_LAT_RULES, MADHABS } from '../modules/prayer/calc.js';
import { HM_REGEX, isValidTimeZone, YMD_REGEX } from './time.js';

export const timezoneSchema = z.string().refine(isValidTimeZone, 'Unknown IANA timezone');
export const ymdSchema = z.string().regex(YMD_REGEX, 'Expected YYYY-MM-DD');
export const hmSchema = z.string().regex(HM_REGEX, 'Expected HH:mm');

export const latitudeSchema = z.coerce.number().min(-90).max(90);
export const longitudeSchema = z.coerce.number().min(-180).max(180);

/** Query parameters shared by every prayer-time endpoint. */
export const prayerQuerySchema = z.object({
  lat: latitudeSchema,
  lng: longitudeSchema,
  tz: timezoneSchema.default('Asia/Riyadh'),
  method: z.enum(CALC_METHOD_KEYS).default('UmmAlQura'),
  madhab: z.enum(MADHABS).default('shafi'),
  highLatRule: z.enum(HIGH_LAT_RULES).optional(),
  hijriAdjustment: z.coerce.number().int().min(-3).max(3).default(0),
});

export const ayahKeySchema = z.string().regex(/^\d{1,3}:\d{1,3}$/, 'Expected "surah:ayah", e.g. 2:255');

export const paginationSchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});
