/** Calendar date without time, e.g. { year: 2026, month: 3, day: 1 }. */
export interface YMD {
  year: number;
  month: number; // 1..12
  day: number;
}

export function isValidTimeZone(tz: string): boolean {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

const partsCache = new Map<string, Intl.DateTimeFormat>();

function wallFormatter(tz: string): Intl.DateTimeFormat {
  let f = partsCache.get(tz);
  if (!f) {
    f = new Intl.DateTimeFormat('en-US', {
      timeZone: tz,
      hourCycle: 'h23',
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
      second: 'numeric',
      weekday: 'short',
    });
    partsCache.set(tz, f);
  }
  return f;
}

export interface WallClock extends YMD {
  hour: number;
  minute: number;
  second: number;
  weekday: number; // 0 = Sunday
}

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/** Wall-clock reading of an instant in a timezone. */
export function wallClock(instant: Date, tz: string): WallClock {
  const parts = Object.fromEntries(
    wallFormatter(tz)
      .formatToParts(instant)
      .map((p) => [p.type, p.value]),
  );
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    second: Number(parts.second),
    weekday: WEEKDAYS.indexOf(parts.weekday ?? ''),
  };
}

/** Offset of `tz` from UTC at `instant`, in minutes (e.g. +180 for Riyadh). */
export function tzOffsetMinutes(instant: Date, tz: string): number {
  const w = wallClock(instant, tz);
  const asUtc = Date.UTC(w.year, w.month - 1, w.day, w.hour, w.minute, w.second);
  return Math.round((asUtc - Math.floor(instant.getTime() / 1000) * 1000) / 60000);
}

/** Converts a wall-clock time in `tz` into an absolute instant. */
export function zonedToUtc(date: YMD, hour: number, minute: number, tz: string): Date {
  const guess = Date.UTC(date.year, date.month - 1, date.day, hour, minute);
  let offset = tzOffsetMinutes(new Date(guess), tz);
  let result = guess - offset * 60000;
  const corrected = tzOffsetMinutes(new Date(result), tz);
  if (corrected !== offset) {
    offset = corrected;
    result = guess - offset * 60000;
  }
  return new Date(result);
}

export function todayIn(tz: string, now = new Date()): YMD {
  const w = wallClock(now, tz);
  return { year: w.year, month: w.month, day: w.day };
}

export function parseYMD(value: string): YMD {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!m) throw new Error(`Invalid date "${value}", expected YYYY-MM-DD`);
  const ymd = { year: Number(m[1]), month: Number(m[2]), day: Number(m[3]) };
  const check = new Date(Date.UTC(ymd.year, ymd.month - 1, ymd.day));
  if (check.getUTCMonth() !== ymd.month - 1 || check.getUTCDate() !== ymd.day) {
    throw new Error(`Invalid date "${value}"`);
  }
  return ymd;
}

export function formatYMD(d: YMD): string {
  return `${d.year}-${String(d.month).padStart(2, '0')}-${String(d.day).padStart(2, '0')}`;
}

export function addDays(d: YMD, days: number): YMD {
  const t = new Date(Date.UTC(d.year, d.month - 1, d.day + days));
  return { year: t.getUTCFullYear(), month: t.getUTCMonth() + 1, day: t.getUTCDate() };
}

/** Day of week for a calendar date, 0 = Sunday. */
export function weekdayOf(d: YMD): number {
  return new Date(Date.UTC(d.year, d.month - 1, d.day)).getUTCDay();
}

/** Calendar date as a UTC-midnight Date, the representation Prisma uses for @db.Date. */
export function ymdToDate(d: YMD): Date {
  return new Date(Date.UTC(d.year, d.month - 1, d.day));
}

export function dateToYMD(d: Date): YMD {
  return { year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate() };
}

export function diffDays(a: YMD, b: YMD): number {
  return Math.round((ymdToDate(a).getTime() - ymdToDate(b).getTime()) / 86400000);
}

/** "HH:mm" of an instant in a timezone. */
export function formatHM(instant: Date, tz: string): string {
  const w = wallClock(instant, tz);
  return `${String(w.hour).padStart(2, '0')}:${String(w.minute).padStart(2, '0')}`;
}

export function parseHM(value: string): { hour: number; minute: number } {
  const m = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(value);
  if (!m) throw new Error(`Invalid time "${value}", expected HH:mm`);
  return { hour: Number(m[1]), minute: Number(m[2]) };
}

export const HM_REGEX = /^([01]\d|2[0-3]):([0-5]\d)$/;
export const YMD_REGEX = /^\d{4}-\d{2}-\d{2}$/;
