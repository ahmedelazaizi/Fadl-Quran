import { describe, expect, it } from 'vitest';
import { computeProgress, presetSummary } from '../../src/modules/khatma/plan.js';
import { isVoluntaryFastAllowed, notificationsForDay, type ScheduleContext } from '../../src/modules/notifications/schedule.js';
import { computeStreak } from '../../src/modules/tasbeeh/routes.js';
import { toHijri } from '../../src/lib/hijri.js';
import { addDays, formatYMD } from '../../src/lib/time.js';

describe('khatma plan', () => {
  const start = { year: 2026, month: 2, day: 18 };

  it('summarizes presets like the khatma screen', () => {
    expect(presetSummary({ durationDays: 30, khatmaCount: 1 })).toEqual({ pagesPerDay: 21, pagesPerPrayer: 5 });
    expect(presetSummary({ durationDays: 60, khatmaCount: 1 })).toEqual({ pagesPerDay: 11, pagesPerPrayer: 3 });
    expect(presetSummary({ durationDays: 30, khatmaCount: 2 })).toEqual({ pagesPerDay: 41, pagesPerPrayer: 9 });
  });

  it('spreads remaining pages over remaining days', () => {
    const p = computeProgress({ khatmaCount: 1, durationDays: 30, startDate: start, currentPage: 241 }, addDays(start, 24), 0);
    expect(p.pagesRead).toBe(240);
    expect(p.remainingPages).toBe(364);
    expect(p.daysLeft).toBe(6);
    expect(p.today.target).toBe(61); // ceil(364 / 6)
    expect(p.percent).toBe(39);
    expect(p.nextPage).toBe(241);
    expect(p.scheduleDelta).toBeLessThan(0);
  });

  it("does not raise today's target while the user is reading today", () => {
    const before = computeProgress({ khatmaCount: 1, durationDays: 30, startDate: start, currentPage: 1 }, start, 0);
    const after = computeProgress({ khatmaCount: 1, durationDays: 30, startDate: start, currentPage: 11 }, start, 10);
    expect(after.today.target).toBe(before.today.target);
    expect(after.today.remaining).toBe(before.today.target - 10);
  });

  it('tracks the second khatma of a double plan', () => {
    const p = computeProgress({ khatmaCount: 2, durationDays: 30, startDate: start, currentPage: 700 }, addDays(start, 10), 0);
    expect(p.currentKhatma).toBe(2);
    expect(p.nextPage).toBe(96);
  });

  it('reports completion', () => {
    const p = computeProgress({ khatmaCount: 1, durationDays: 30, startDate: start, currentPage: 605 }, addDays(start, 29), 20);
    expect(p.remainingPages).toBe(0);
    expect(p.percent).toBe(100);
    expect(p.nextPage).toBeNull();
    expect(p.today.target).toBe(0);
  });
});

describe('tasbeeh streak', () => {
  const today = { year: 2026, month: 3, day: 10 };
  const days = (...offsets: number[]) => new Set(offsets.map((o) => formatYMD(addDays(today, o))));

  it('counts consecutive days up to today', () => {
    expect(computeStreak(days(0, -1, -2, -4), today)).toBe(3);
  });
  it('keeps yesterday-ending streaks alive until today ends', () => {
    expect(computeStreak(days(-1, -2), today)).toBe(2);
  });
  it('is zero after a missed day', () => {
    expect(computeStreak(days(-2, -3), today)).toBe(0);
  });
});

describe('notification schedule', () => {
  const ctx: ScheduleContext = {
    prayer: { latitude: 24.7136, longitude: 46.6753, timezone: 'Asia/Riyadh', method: 'UmmAlQura', madhab: 'shafi' },
    prefs: {
      enabled: true,
      adhan: { fajr: true, sunrise: false, dhuhr: true, asr: true, maghrib: true, isha: true },
      preAlertMinutes: 15,
      morningAthkarTime: '06:00',
      eveningAthkarTime: '17:00',
      sleepAthkarTime: null,
      qiyamEnabled: true,
      duhaEnabled: false,
      fridayKahf: true,
      fridayHour: true,
      mondayThursdayFast: true,
      whiteDaysFast: true,
      khatmaReminder: true,
    },
    locationName: 'الرياض',
    khatma: { reminderTime: '20:30', todayRemaining: 12 },
  };
  const types = (date: { year: number; month: number; day: number }) => notificationsForDay(date, ctx).map((n) => n.type);

  it('schedules adhan, pre-alerts, athkar, qiyam and khatma on a normal day', () => {
    const list = notificationsForDay({ year: 2025, month: 9, day: 16 }, ctx); // Tuesday
    const types = list.map((n) => n.type);
    expect(types.filter((t) => t === 'adhan')).toHaveLength(5);
    expect(types.filter((t) => t === 'pre_adhan')).toHaveLength(5);
    expect(types).toContain('athkar_morning');
    expect(types).toContain('qiyam');
    expect(types).toContain('khatma');
    expect(types).not.toContain('friday_kahf');
    const morning = list.find((n) => n.type === 'athkar_morning')!;
    expect(morning.fireAt.toISOString()).toBe('2025-09-16T03:00:00.000Z');
    // Sorted by time.
    expect([...list].sort((a, b) => a.fireAt.getTime() - b.fireAt.getTime())).toEqual(list);
  });

  it('adds Friday reminders', () => {
    const types = notificationsForDay({ year: 2025, month: 9, day: 19 }, ctx).map((n) => n.type);
    expect(types).toContain('friday_kahf');
    expect(types).toContain('friday_hour');
  });

  it('reminds of Monday/Thursday fasting the evening before, but not before Eid or Tashreeq', () => {
    expect(types({ year: 2025, month: 9, day: 14 })).toContain('fast_mon_thu'); // Sunday
    expect(types({ year: 2025, month: 9, day: 15 })).not.toContain('fast_mon_thu'); // Monday
    // Around Eid al-Adha 1447 the 10th–13th Dhu al-Hijjah include a Monday or Thursday.
    let d = { year: 2026, month: 5, day: 15 };
    let checked = 0;
    for (let i = 0; i < 30; i++, d = addDays(d, 1)) {
      const weekday = new Date(Date.UTC(d.year, d.month - 1, d.day)).getUTCDay();
      if ((weekday === 0 || weekday === 3) && !isVoluntaryFastAllowed(toHijri(addDays(d, 1)))) {
        expect(types(d)).not.toContain('fast_mon_thu');
        checked++;
      }
    }
    expect(checked).toBeGreaterThan(0);
  });

  it('reminds of the white days on the 12th, except in Ramadan and Dhu al-Hijjah', () => {
    let d = { year: 2025, month: 9, day: 1 };
    while (toHijri(d).day !== 12) d = addDays(d, 1);
    expect(notificationsForDay(d, ctx).some((n) => n.type === 'fast_white_days')).toBe(true);
    expect(isVoluntaryFastAllowed({ year: 1447, month: 9, day: 5, monthNameAr: '', formattedAr: '' })).toBe(false);
  });

  it('skips khatma reminders once today is done and everything when disabled', () => {
    const done = notificationsForDay({ year: 2025, month: 9, day: 16 }, { ...ctx, khatma: { reminderTime: '20:30', todayRemaining: 0 } });
    expect(done.some((n) => n.type === 'khatma')).toBe(false);
    expect(notificationsForDay({ year: 2025, month: 9, day: 16 }, { ...ctx, prefs: { ...ctx.prefs, enabled: false } })).toEqual([]);
  });
});
