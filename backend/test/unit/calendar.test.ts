import { describe, expect, it } from 'vitest';
import { normalizeArabic, searchTerms } from '../../src/lib/arabic.js';
import { hijriMonthLength, hijriMonthStart, toHijri } from '../../src/lib/hijri.js';
import { formatHM, todayIn, zonedToUtc } from '../../src/lib/time.js';

describe('arabic normalization', () => {
  it('strips diacritics and unifies letter forms', () => {
    expect(normalizeArabic('وَبِالْوَالِدَيْنِ إِحْسَانًا')).toBe('وبالوالدين احسانا');
    expect(normalizeArabic('ٱلصَّلَوٰةَ')).toBe('الصلوه');
    expect(normalizeArabic('مُوسَىٰ')).toBe('موسي');
  });

  it('builds search terms without the definite article', () => {
    expect(searchTerms('بر الوالدين')).toEqual(['بر', 'والدين']);
    expect(searchTerms('الصبر')).toEqual(['صبر']);
    expect(searchTerms('الله')).toEqual(['الله']);
  });
});

describe('hijri calendar (Umm al-Qura)', () => {
  it('converts Gregorian dates', () => {
    expect(toHijri({ year: 2025, month: 9, day: 15 })).toMatchObject({ year: 1447, month: 3, day: 23 });
  });

  it('applies the sighting adjustment', () => {
    expect(toHijri({ year: 2025, month: 9, day: 15 }, 1).day).toBe(24);
  });

  it('finds the first day of Ramadan', () => {
    expect(hijriMonthStart(1446, 9)).toEqual({ year: 2025, month: 3, day: 1 });
    expect(hijriMonthStart(1447, 9)).toEqual({ year: 2026, month: 2, day: 18 });
    expect([29, 30]).toContain(hijriMonthLength(1447, 9));
  });
});

describe('time zones', () => {
  it('converts wall-clock time to UTC', () => {
    const d = zonedToUtc({ year: 2026, month: 3, day: 1 }, 6, 0, 'Asia/Riyadh');
    expect(d.toISOString()).toBe('2026-03-01T03:00:00.000Z');
    expect(formatHM(d, 'Asia/Riyadh')).toBe('06:00');
  });

  it('handles daylight saving time', () => {
    // Cairo observes DST in summer (UTC+3) and not in winter (UTC+2).
    expect(zonedToUtc({ year: 2025, month: 7, day: 1 }, 12, 0, 'Africa/Cairo').toISOString()).toBe('2025-07-01T09:00:00.000Z');
    expect(zonedToUtc({ year: 2025, month: 1, day: 1 }, 12, 0, 'Africa/Cairo').toISOString()).toBe('2025-01-01T10:00:00.000Z');
  });

  it('returns the local calendar day', () => {
    const now = new Date('2026-03-01T22:30:00Z'); // 01:30 next day in Riyadh
    expect(todayIn('Asia/Riyadh', now)).toEqual({ year: 2026, month: 3, day: 2 });
    expect(todayIn('UTC', now)).toEqual({ year: 2026, month: 3, day: 1 });
  });
});
