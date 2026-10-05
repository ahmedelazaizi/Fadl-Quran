import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma.js';
import { addDays, dateToYMD, todayIn, ymdToDate } from '../../lib/time.js';
import { computeProgress } from '../khatma/plan.js';
import { hasLocation, prayerOptionsFromSettings } from '../me/context.js';
import type { PrayerName } from '../prayer/calc.js';
import { type NotificationPrefs, notificationsForDay, type ScheduleContext, type ScheduledNotification } from './schedule.js';
import type { PushSender } from './sender.js';

/** Builds the schedule context for one user, or null if they cannot be scheduled. */
export async function scheduleContextFor(
  userId: string,
  now: Date,
): Promise<(ScheduleContext & { adhanSound: string }) | null> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      settings: true,
      notifications: true,
      khatmas: { where: { status: 'ACTIVE' }, take: 1, orderBy: { createdAt: 'desc' } },
    },
  });
  if (!user?.settings || !user.notifications || !hasLocation(user.settings)) return null;
  const prayer = prayerOptionsFromSettings(user.settings);
  const n = user.notifications;
  const prefs: NotificationPrefs = { ...n, adhan: n.adhan as Partial<Record<PrayerName, boolean>> };

  let khatma: ScheduleContext['khatma'] = null;
  const plan = user.khatmas[0];
  if (plan?.reminderTime) {
    const day = todayIn(prayer.timezone, now);
    const readToday = await prisma.khatmaLog.aggregate({
      where: { planId: plan.id, date: ymdToDate(day) },
      _sum: { pages: true },
    });
    const progress = computeProgress(
      { ...plan, startDate: dateToYMD(plan.startDate) },
      day,
      readToday._sum.pages ?? 0,
    );
    khatma = { reminderTime: plan.reminderTime, todayRemaining: progress.today.remaining };
  }
  return { prayer, prefs, locationName: user.settings.locationName, khatma, adhanSound: n.adhanSound };
}

/** Upcoming notifications for a user within `hours` from `now`. */
export async function upcomingFor(userId: string, now: Date, hours: number): Promise<ScheduledNotification[]> {
  const ctx = await scheduleContextFor(userId, now);
  if (!ctx) return [];
  const today = todayIn(ctx.prayer.timezone, now);
  const end = now.getTime() + hours * 3600_000;
  const days = Math.ceil(hours / 24) + 1;
  const all = Array.from({ length: days + 1 }, (_, i) => notificationsForDay(addDays(today, i - 1), ctx)).flat();
  return all.filter((n) => n.fireAt.getTime() > now.getTime() && n.fireAt.getTime() <= end);
}

export interface DispatchStats {
  users: number;
  due: number;
  sent: number;
  failed: number;
  removedTokens: number;
}

/**
 * One scheduler tick: finds notifications whose fire time fell inside
 * (now - lookback, now], records each in NotificationLog (the unique key makes
 * concurrent workers and restarts safe) and pushes it to the user's devices.
 */
export async function dispatchDue(sender: PushSender, now = new Date(), lookbackMs = 5 * 60_000): Promise<DispatchStats> {
  const stats: DispatchStats = { users: 0, due: 0, sent: 0, failed: 0, removedTokens: 0 };
  const windowStart = now.getTime() - lookbackMs;
  let cursor: string | undefined;

  for (;;) {
    const users = await prisma.user.findMany({
      where: {
        devices: { some: {} },
        notifications: { enabled: true },
        settings: { latitude: { not: null }, longitude: { not: null } },
      },
      select: { id: true },
      orderBy: { id: 'asc' },
      take: 200,
      ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
    });
    if (users.length === 0) break;
    cursor = users[users.length - 1]!.id;

    for (const { id: userId } of users) {
      stats.users++;
      const ctx = await scheduleContextFor(userId, now);
      if (!ctx) continue;
      const today = todayIn(ctx.prayer.timezone, now);
      // Yesterday is included for events past midnight (e.g. the last third of the night).
      const due = [addDays(today, -1), today]
        .flatMap((d) => notificationsForDay(d, ctx))
        .filter((n) => n.fireAt.getTime() > windowStart && n.fireAt.getTime() <= now.getTime());

      if (due.length === 0) continue;
      const devices = await prisma.device.findMany({ where: { userId }, select: { fcmToken: true } });
      const tokens = devices.map((d) => d.fcmToken);

      for (const n of due) {
        stats.due++;
        try {
          await prisma.notificationLog.create({
            data: { userId, key: n.key, type: n.type, fireAt: n.fireAt },
          });
        } catch (err) {
          if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') continue; // already sent
          throw err;
        }
        const result = await sender.send(tokens, n, { adhanSound: ctx.adhanSound });
        if (result.invalidTokens.length) {
          const removed = await prisma.device.deleteMany({ where: { fcmToken: { in: result.invalidTokens } } });
          stats.removedTokens += removed.count;
        }
        const ok = result.successCount > 0;
        if (ok) stats.sent++;
        else stats.failed++;
        if (!ok) {
          await prisma.notificationLog.update({
            where: { userId_key: { userId, key: n.key } },
            data: { status: 'FAILED', error: result.error?.slice(0, 500) ?? 'No device accepted the message' },
          });
        }
      }
    }
  }
  return stats;
}

/** Deletes delivery logs older than `days` (they only matter for de-duplication). */
export async function pruneLogs(days = 30) {
  return prisma.notificationLog.deleteMany({ where: { createdAt: { lt: new Date(Date.now() - days * 86400_000) } } });
}
