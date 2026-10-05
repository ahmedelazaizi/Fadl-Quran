import type { UserSettings } from '@prisma/client';
import { badRequest } from '../../lib/errors.js';
import { prisma } from '../../lib/prisma.js';
import { parseYMD, todayIn, type YMD } from '../../lib/time.js';
import type { CalcMethod, HighLatRuleKey, MadhabKey, PrayerName, PrayerOptions } from '../prayer/calc.js';

export async function getSettings(userId: string): Promise<UserSettings> {
  return prisma.userSettings.upsert({ where: { userId }, create: { userId }, update: {} });
}

/** Resolves an optional "YYYY-MM-DD" against the user's timezone. */
export function resolveDate(settings: UserSettings, date?: string): YMD {
  return date ? parseYMD(date) : todayIn(settings.timezone);
}

export function hasLocation(s: UserSettings): s is UserSettings & { latitude: number; longitude: number } {
  return s.latitude !== null && s.longitude !== null;
}

export function prayerOptionsFromSettings(s: UserSettings): PrayerOptions {
  if (!hasLocation(s)) throw badRequest('Set your location first (PATCH /me/settings with latitude & longitude)');
  return {
    latitude: s.latitude,
    longitude: s.longitude,
    timezone: s.timezone,
    method: s.calcMethod as CalcMethod,
    madhab: s.madhab as MadhabKey,
    highLatRule: (s.highLatRule as HighLatRuleKey | null) ?? null,
    adjustments: (s.adjustments ?? {}) as Partial<Record<PrayerName, number>>,
    hijriAdjustment: s.hijriAdjustment,
  };
}
