import { describe, expect, it } from 'vitest';
import { computeDay, nextPrayer, qibla, serializeDay, type PrayerOptions } from '../../src/modules/prayer/calc.js';

const riyadh: PrayerOptions = {
  latitude: 24.7136,
  longitude: 46.6753,
  timezone: 'Asia/Riyadh',
  method: 'UmmAlQura',
  madhab: 'shafi',
};

const local = (opts: PrayerOptions, y: number, m: number, d: number) =>
  Object.fromEntries(serializeDay(computeDay({ year: y, month: m, day: d }, opts), opts.timezone).prayers.map((p) => [p.name, p.local]));

describe('prayer times', () => {
  it('matches the Umm al-Qura timetable for Riyadh', () => {
    expect(local(riyadh, 2025, 9, 15)).toEqual({
      fajr: '04:21',
      sunrise: '05:39',
      dhuhr: '11:48',
      asr: '15:15',
      maghrib: '17:57',
      isha: '19:27',
    });
  });

  it('uses 120 minutes for isha in Ramadan with Umm al-Qura', () => {
    const t = computeDay({ year: 2026, month: 3, day: 1 }, riyadh).times; // 12 Ramadan 1447
    expect((t.isha.getTime() - t.maghrib.getTime()) / 60000).toBe(120);
    const outside = computeDay({ year: 2026, month: 4, day: 1 }, riyadh).times;
    expect((outside.isha.getTime() - outside.maghrib.getTime()) / 60000).toBe(90);
  });

  it('applies the Hanafi asr and per-prayer adjustments', () => {
    const shafi = computeDay({ year: 2025, month: 9, day: 15 }, riyadh).times;
    const hanafi = computeDay({ year: 2025, month: 9, day: 15 }, { ...riyadh, madhab: 'hanafi', adjustments: { fajr: 2 } }).times;
    expect(hanafi.asr.getTime()).toBeGreaterThan(shafi.asr.getTime());
    expect(hanafi.fajr.getTime() - shafi.fajr.getTime()).toBe(2 * 60000);
  });

  it('computes the Egyptian method for Cairo', () => {
    const cairo: PrayerOptions = { latitude: 30.0444, longitude: 31.2357, timezone: 'Africa/Cairo', method: 'Egyptian', madhab: 'shafi' };
    const t = local(cairo, 2025, 1, 15);
    expect(t.dhuhr).toMatch(/^12:0\d$/);
    // Egyptian General Authority of Survey publishes fajr ≈ 05:20 for this date.
    expect(t.fajr).toMatch(/^05:2[0-2]$/);
  });

  it('finds the next prayer, rolling over to tomorrow after isha', () => {
    const afterIsha = new Date('2025-09-15T20:00:00Z'); // 23:00 Riyadh
    const next = nextPrayer({ year: 2025, month: 9, day: 15 }, riyadh, afterIsha);
    expect(next.name).toBe('fajr');
    expect(next.time.toISOString().slice(0, 10)).toBe('2025-09-16');
    expect(next.secondsRemaining).toBeGreaterThan(0);

    const morning = nextPrayer({ year: 2025, month: 9, day: 15 }, riyadh, new Date('2025-09-15T03:00:00Z'));
    expect(morning.name).toBe('dhuhr'); // sunrise is skipped
  });
});

describe('qibla', () => {
  it('points south-west from Riyadh and south-east from Cairo', () => {
    const r = qibla(24.7136, 46.6753);
    expect(r.bearing).toBeCloseTo(243.8, 0);
    expect(r.distanceKm).toBeGreaterThan(780);
    expect(r.distanceKm).toBeLessThan(800);
    expect(qibla(30.0444, 31.2357).bearing).toBeCloseTo(136.1, 0);
  });
});
