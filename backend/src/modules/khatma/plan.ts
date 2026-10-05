import { addDays, diffDays, formatYMD, type YMD } from '../../lib/time.js';

export const MUSHAF_PAGES = 604;
export const DAILY_PRAYERS = 5;

export const KHATMA_PRESETS = [
  { key: '30-days', title: 'ختمة في شهر', durationDays: 30, khatmaCount: 1 },
  { key: '60-days', title: 'ختمة في شهرين', durationDays: 60, khatmaCount: 1 },
  { key: 'ramadan-double', title: 'ختمتان في رمضان', durationDays: 30, khatmaCount: 2 },
  { key: '15-days', title: 'ختمة في ١٥ يوماً', durationDays: 15, khatmaCount: 1 },
  { key: '7-days', title: 'ختمة في أسبوع', durationDays: 7, khatmaCount: 1 },
] as const;

export type PresetKey = (typeof KHATMA_PRESETS)[number]['key'];

export function presetSummary(p: { durationDays: number; khatmaCount: number }) {
  const pagesPerDay = Math.ceil((MUSHAF_PAGES * p.khatmaCount) / p.durationDays);
  return { pagesPerDay, pagesPerPrayer: Math.ceil(pagesPerDay / DAILY_PRAYERS) };
}

export interface PlanState {
  khatmaCount: number;
  durationDays: number;
  startDate: YMD;
  /** Next page to read across all khatmas, 1-based. */
  currentPage: number;
}

/**
 * Derives everything the khatma screen shows from the stored plan state:
 * overall progress, today's adaptive target (remaining pages spread over
 * the remaining days), per-prayer split and whether the reader is on track.
 */
export function computeProgress(plan: PlanState, today: YMD, pagesReadToday: number) {
  const totalPages = MUSHAF_PAGES * plan.khatmaCount;
  const pagesRead = Math.min(plan.currentPage - 1, totalPages);
  const remainingPages = totalPages - pagesRead;
  const endDate = addDays(plan.startDate, plan.durationDays - 1);
  const dayIndex = Math.max(0, diffDays(today, plan.startDate)); // 0 on the first day
  const daysLeft = Math.max(1, plan.durationDays - dayIndex); // including today
  const remainingAtStartOfDay = remainingPages + pagesReadToday;
  const dailyTarget = remainingPages === 0 ? 0 : Math.ceil(remainingAtStartOfDay / daysLeft);
  const todayRemaining = Math.max(0, dailyTarget - pagesReadToday);
  const expectedByEndOfToday = Math.min(
    totalPages,
    Math.ceil((totalPages * Math.min(dayIndex + 1, plan.durationDays)) / plan.durationDays),
  );
  const nextPageInMushaf = remainingPages === 0 ? null : ((plan.currentPage - 1) % MUSHAF_PAGES) + 1;

  return {
    totalPages,
    pagesRead,
    remainingPages,
    remainingJuz: Math.round((remainingPages / 20) * 10) / 10,
    percent: Math.floor((pagesRead / totalPages) * 100),
    startDate: formatYMD(plan.startDate),
    endDate: formatYMD(endDate),
    dayNumber: Math.min(dayIndex + 1, plan.durationDays),
    daysLeft: remainingPages === 0 ? 0 : daysLeft,
    overdue: diffDays(today, endDate) > 0 && remainingPages > 0,
    currentKhatma: Math.min(Math.floor(pagesRead / MUSHAF_PAGES) + 1, plan.khatmaCount),
    nextPage: nextPageInMushaf,
    today: {
      target: dailyTarget,
      read: pagesReadToday,
      remaining: todayRemaining,
      perPrayer: Math.ceil(dailyTarget / DAILY_PRAYERS),
      done: dailyTarget > 0 && todayRemaining === 0,
    },
    /**
     * Pages read minus pages an even schedule expects by the end of today.
     * Negative while today's wird is unfinished or when behind schedule.
     */
    scheduleDelta: pagesRead - expectedByEndOfToday,
  };
}
