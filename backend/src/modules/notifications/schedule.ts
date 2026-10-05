import { type HijriDate, toHijri } from '../../lib/hijri.js';
import { addDays, formatYMD, parseHM, weekdayOf, type YMD, zonedToUtc } from '../../lib/time.js';
import { computeDay, PRAYER_NAMES_AR, PRAYERS, type PrayerName, type PrayerOptions } from '../prayer/calc.js';

export type NotificationType =
  | 'adhan'
  | 'pre_adhan'
  | 'athkar_morning'
  | 'athkar_evening'
  | 'athkar_sleep'
  | 'qiyam'
  | 'duha'
  | 'friday_kahf'
  | 'friday_hour'
  | 'fast_mon_thu'
  | 'fast_white_days'
  | 'khatma';

export interface ScheduledNotification {
  /** Unique per user; used to de-duplicate sends. */
  key: string;
  type: NotificationType;
  fireAt: Date;
  title: string;
  body: string;
  /** Deep link the app opens when the notification is tapped. */
  link: string;
  prayer?: PrayerName;
}

export interface NotificationPrefs {
  enabled: boolean;
  adhan: Partial<Record<PrayerName, boolean>>;
  preAlertMinutes: number;
  morningAthkarTime: string | null;
  eveningAthkarTime: string | null;
  sleepAthkarTime: string | null;
  qiyamEnabled: boolean;
  duhaEnabled: boolean;
  fridayKahf: boolean;
  fridayHour: boolean;
  mondayThursdayFast: boolean;
  whiteDaysFast: boolean;
  khatmaReminder: boolean;
}

export interface ScheduleContext {
  prayer: PrayerOptions;
  prefs: NotificationPrefs;
  locationName?: string | null;
  /** Active khatma with a reminder; `todayRemaining` pages still to read today. */
  khatma?: { reminderTime: string | null; todayRemaining: number } | null;
}

const MINUTE = 60_000;
const FRIDAY = 5;

/**
 * Voluntary-fast reminders are skipped in Ramadan (already fasting), on Eid
 * al-Fitr (1 Shawwal), and on Eid al-Adha and the days of Tashreeq (10–13 Dhu al-Hijjah).
 */
export function isVoluntaryFastAllowed(h: HijriDate): boolean {
  if (h.month === 9) return false;
  if (h.month === 10 && h.day === 1) return false;
  if (h.month === 12 && h.day >= 10 && h.day <= 13) return false;
  return true;
}

/**
 * All notifications for one local calendar day. Pure: the worker, the
 * "upcoming" endpoint and the tests share it.
 */
export function notificationsForDay(date: YMD, ctx: ScheduleContext): ScheduledNotification[] {
  const { prefs } = ctx;
  if (!prefs.enabled) return [];
  const tz = ctx.prayer.timezone;
  const d = formatYMD(date);
  const day = computeDay(date, ctx.prayer);
  const t = day.times;
  const out: ScheduledNotification[] = [];
  const at = (hm: string) => {
    const { hour, minute } = parseHM(hm);
    return zonedToUtc(date, hour, minute, tz);
  };
  const where = ctx.locationName ? ` حسب توقيت ${ctx.locationName}` : '';

  for (const p of PRAYERS) {
    if (!prefs.adhan[p]) continue;
    out.push({
      key: `adhan:${p}:${d}`,
      type: 'adhan',
      prayer: p,
      fireAt: t[p],
      title: p === 'sunrise' ? 'حان وقت الشروق' : `حان الآن وقت صلاة ${PRAYER_NAMES_AR[p]}`,
      body: p === 'sunrise' ? `انتهى وقت صلاة الفجر${where}` : `حيّ على الصلاة، حيّ على الفلاح${where}`,
      link: 'fadl://prayer-times',
    });
    if (prefs.preAlertMinutes > 0 && p !== 'sunrise') {
      out.push({
        key: `pre_adhan:${p}:${d}`,
        type: 'pre_adhan',
        prayer: p,
        fireAt: new Date(t[p].getTime() - prefs.preAlertMinutes * MINUTE),
        title: `اقترب وقت صلاة ${PRAYER_NAMES_AR[p]}`,
        body: `بقي ${prefs.preAlertMinutes} دقيقة على الأذان`,
        link: 'fadl://prayer-times',
      });
    }
  }

  if (prefs.morningAthkarTime) {
    out.push({
      key: `athkar_morning:${d}`,
      type: 'athkar_morning',
      fireAt: at(prefs.morningAthkarTime),
      title: 'أذكار الصباح',
      body: 'ابدأ يومك بذكر الله، حصّن نفسك بأذكار الصباح',
      link: 'fadl://athkar/morning',
    });
  }
  if (prefs.eveningAthkarTime) {
    out.push({
      key: `athkar_evening:${d}`,
      type: 'athkar_evening',
      fireAt: at(prefs.eveningAthkarTime),
      title: 'أذكار المساء',
      body: 'لا تنسَ أذكار المساء',
      link: 'fadl://athkar/evening',
    });
  }
  if (prefs.sleepAthkarTime) {
    out.push({
      key: `athkar_sleep:${d}`,
      type: 'athkar_sleep',
      fireAt: at(prefs.sleepAthkarTime),
      title: 'أذكار النوم',
      body: 'اختم يومك بأذكار النوم',
      link: 'fadl://athkar/sleep',
    });
  }

  if (prefs.qiyamEnabled) {
    out.push({
      key: `qiyam:${d}`,
      type: 'qiyam',
      fireAt: day.lastThirdOfNight,
      title: 'الثلث الأخير من الليل',
      body: 'ينزل ربنا إلى السماء الدنيا حين يبقى ثلث الليل الآخر فيقول: من يدعوني فأستجيب له',
      link: 'fadl://duas',
    });
  }
  if (prefs.duhaEnabled) {
    out.push({
      key: `duha:${d}`,
      type: 'duha',
      // Midway between sunrise and dhuhr, when the sun is high.
      fireAt: new Date((t.sunrise.getTime() + t.dhuhr.getTime()) / 2),
      title: 'صلاة الضحى',
      body: 'صلاة الأوّابين، ركعتان تجزئان عن صدقة كل مفصل',
      link: 'fadl://home',
    });
  }

  const weekday = weekdayOf(date);
  if (weekday === FRIDAY && prefs.fridayKahf) {
    out.push({
      key: `friday_kahf:${d}`,
      type: 'friday_kahf',
      fireAt: new Date(t.fajr.getTime() + 30 * MINUTE),
      title: 'جمعة مباركة',
      body: 'لا تنسَ قراءة سورة الكهف والإكثار من الصلاة على النبي ﷺ',
      link: 'fadl://quran/surah/18',
    });
  }
  if (weekday === FRIDAY && prefs.fridayHour) {
    out.push({
      key: `friday_hour:${d}`,
      type: 'friday_hour',
      fireAt: new Date(t.maghrib.getTime() - 60 * MINUTE),
      title: 'ساعة الإجابة يوم الجمعة',
      body: 'آخر ساعة بعد العصر من يوم الجمعة، أكثر من الدعاء',
      link: 'fadl://duas',
    });
  }

  // Reminders sent the evening before (after isha) so the user can intend the fast.
  const hijri = toHijri(date, ctx.prayer.hijriAdjustment ?? 0);
  const tomorrowFastable = isVoluntaryFastAllowed(toHijri(addDays(date, 1), ctx.prayer.hijriAdjustment ?? 0));
  if (prefs.mondayThursdayFast && (weekday === 0 || weekday === 3) && tomorrowFastable) {
    out.push({
      key: `fast_mon_thu:${d}`,
      type: 'fast_mon_thu',
      fireAt: t.isha,
      title: `غداً ${weekday === 0 ? 'الاثنين' : 'الخميس'}`,
      body: 'تُعرض الأعمال يومي الاثنين والخميس، فهل تنوي الصيام؟',
      link: 'fadl://home',
    });
  }
  // Dhu al-Hijjah is skipped: its 13th is a day of Tashreeq, when fasting is forbidden.
  if (prefs.whiteDaysFast && hijri.day === 12 && hijri.month !== 9 && hijri.month !== 12) {
    out.push({
      key: `fast_white_days:${d}`,
      type: 'fast_white_days',
      fireAt: t.isha,
      title: 'الأيام البيض',
      body: `تبدأ غداً الأيام البيض (١٣، ١٤، ١٥ ${hijri.monthNameAr})، صيامها كصيام الدهر`,
      link: 'fadl://home',
    });
  }

  if (prefs.khatmaReminder && ctx.khatma?.reminderTime && ctx.khatma.todayRemaining > 0) {
    out.push({
      key: `khatma:${d}`,
      type: 'khatma',
      fireAt: at(ctx.khatma.reminderTime),
      title: 'وِردك اليومي من القرآن',
      body: `بقي لك اليوم ${ctx.khatma.todayRemaining} صفحة لتبقى على خطة ختمتك`,
      link: 'fadl://khatma',
    });
  }

  return out.sort((a, b) => a.fireAt.getTime() - b.fireAt.getTime());
}
