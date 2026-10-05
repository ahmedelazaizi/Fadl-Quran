import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { badRequest, notFound } from '../../lib/errors.js';
import { prisma } from '../../lib/prisma.js';
import { ymdSchema } from '../../lib/schemas.js';
import { addDays, dateToYMD, formatYMD, parseYMD, type YMD, ymdToDate } from '../../lib/time.js';
import { requireUserId } from '../auth/plugin.js';
import { getSettings, resolveDate } from '../me/context.js';

const security = [{ bearerAuth: [] }];

/** Consecutive days (ending today, or yesterday if today is still empty) with any tasbeeh. */
export function computeStreak(activeDays: Set<string>, today: YMD): number {
  let cursor = activeDays.has(formatYMD(today)) ? today : addDays(today, -1);
  let streak = 0;
  while (activeDays.has(formatYMD(cursor))) {
    streak++;
    cursor = addDays(cursor, -1);
  }
  return streak;
}

export async function tasbeehSummary(userId: string, today: YMD, dailyGoal: number) {
  const [dhikrs, todayGroups, history] = await Promise.all([
    prisma.tasbeehDhikr.findMany({ where: { userId }, orderBy: { sortOrder: 'asc' } }),
    prisma.tasbeehEntry.groupBy({
      by: ['dhikrId'],
      where: { userId, date: ymdToDate(today) },
      _sum: { count: true },
    }),
    prisma.tasbeehEntry.groupBy({
      by: ['date'],
      where: { userId, date: { gte: ymdToDate(addDays(today, -366)), lte: ymdToDate(today) } },
      _sum: { count: true },
    }),
  ]);
  const todayByDhikr = new Map(todayGroups.map((g) => [g.dhikrId, g._sum.count ?? 0]));
  const totals = new Map(history.map((h) => [formatYMD(dateToYMD(h.date)), h._sum.count ?? 0]));
  const todayTotal = totals.get(formatYMD(today)) ?? 0;
  const activeDays = new Set([...totals].filter(([, n]) => n > 0).map(([d]) => d));

  return {
    date: formatYMD(today),
    dailyGoal,
    todayTotal,
    goalPercent: Math.min(100, Math.floor((todayTotal / dailyGoal) * 100)),
    streakDays: computeStreak(activeDays, today),
    week: Array.from({ length: 7 }, (_, i) => {
      const d = formatYMD(addDays(today, i - 6));
      return { date: d, total: totals.get(d) ?? 0 };
    }),
    dhikrs: dhikrs.map((d) => {
      const count = todayByDhikr.get(d.id) ?? 0;
      return {
        id: d.id,
        text: d.text,
        target: d.target,
        todayCount: count,
        rounds: Math.floor(count / d.target),
        remainingInRound: d.target - (count % d.target),
      };
    }),
  };
}

async function ownDhikr(userId: string, id: string) {
  const dhikr = await prisma.tasbeehDhikr.findFirst({ where: { id, userId } });
  if (!dhikr) throw notFound('Tasbeeh dhikr');
  return dhikr;
}

export const tasbeehRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get(
    '/me/tasbeeh',
    {
      schema: {
        tags: ['tasbeeh'],
        security,
        summary: "Today's counters, daily goal, streak and last 7 days",
        querystring: z.object({ date: ymdSchema.optional() }),
      },
    },
    async (req) => {
      const userId = requireUserId(req);
      const settings = await getSettings(userId);
      return tasbeehSummary(userId, resolveDate(settings, req.query.date), settings.tasbeehDailyGoal);
    },
  );

  app.post(
    '/me/tasbeeh/dhikrs',
    {
      schema: {
        tags: ['tasbeeh'],
        security,
        summary: 'Add a custom dhikr ("إضافة ذكر")',
        body: z.object({ text: z.string().min(1).max(300), target: z.number().int().min(1).max(10000).default(33) }),
      },
    },
    async (req, reply) => {
      const userId = requireUserId(req);
      const last = await prisma.tasbeehDhikr.findFirst({ where: { userId }, orderBy: { sortOrder: 'desc' } });
      reply.code(201);
      return prisma.tasbeehDhikr.create({
        data: { userId, text: req.body.text, target: req.body.target, sortOrder: (last?.sortOrder ?? -1) + 1 },
      });
    },
  );

  app.patch(
    '/me/tasbeeh/dhikrs/:id',
    {
      schema: {
        tags: ['tasbeeh'],
        security,
        summary: 'Edit a dhikr text / target / order',
        params: z.object({ id: z.string().uuid() }),
        body: z
          .object({
            text: z.string().min(1).max(300),
            target: z.number().int().min(1).max(10000),
            sortOrder: z.number().int().min(0),
          })
          .partial(),
      },
    },
    async (req) => {
      await ownDhikr(requireUserId(req), req.params.id);
      return prisma.tasbeehDhikr.update({ where: { id: req.params.id }, data: req.body });
    },
  );

  app.delete(
    '/me/tasbeeh/dhikrs/:id',
    { schema: { tags: ['tasbeeh'], security, summary: 'Remove a dhikr', params: z.object({ id: z.string().uuid() }) } },
    async (req, reply) => {
      await ownDhikr(requireUserId(req), req.params.id);
      await prisma.tasbeehDhikr.delete({ where: { id: req.params.id } });
      reply.code(204);
    },
  );

  app.post(
    '/me/tasbeeh/entries',
    {
      schema: {
        tags: ['tasbeeh'],
        security,
        summary:
          'Upload counted tasbeeh (batched, offline-friendly). Entries with an already-seen clientEventId are ignored.',
        body: z.object({
          entries: z
            .array(
              z.object({
                dhikrId: z.string().uuid(),
                count: z.number().int().min(1).max(100000),
                date: ymdSchema.optional(),
                clientEventId: z.string().min(8).max(64).optional(),
              }),
            )
            .min(1)
            .max(500),
        }),
      },
    },
    async (req) => {
      const userId = requireUserId(req);
      const settings = await getSettings(userId);
      const ids = [...new Set(req.body.entries.map((e) => e.dhikrId))];
      const owned = await prisma.tasbeehDhikr.count({ where: { userId, id: { in: ids } } });
      if (owned !== ids.length) throw badRequest('Unknown dhikrId in entries');
      const result = await prisma.tasbeehEntry.createMany({
        data: req.body.entries.map((e) => ({
          userId,
          dhikrId: e.dhikrId,
          count: e.count,
          date: ymdToDate(e.date ? parseYMD(e.date) : resolveDate(settings)),
          clientEventId: e.clientEventId,
        })),
        skipDuplicates: true,
      });
      return {
        accepted: result.count,
        ignored: req.body.entries.length - result.count,
        summary: await tasbeehSummary(userId, resolveDate(settings), settings.tasbeehDailyGoal),
      };
    },
  );

  app.delete(
    '/me/tasbeeh/today/:dhikrId',
    {
      schema: {
        tags: ['tasbeeh'],
        security,
        summary: 'Reset ("تصفير") today\'s counter for one dhikr',
        params: z.object({ dhikrId: z.string().uuid() }),
      },
    },
    async (req, reply) => {
      const userId = requireUserId(req);
      await ownDhikr(userId, req.params.dhikrId);
      const today = resolveDate(await getSettings(userId));
      await prisma.tasbeehEntry.deleteMany({ where: { userId, dhikrId: req.params.dhikrId, date: ymdToDate(today) } });
      reply.code(204);
    },
  );
};
