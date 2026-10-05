import type { KhatmaPlan } from '@prisma/client';
import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { badRequest, notFound } from '../../lib/errors.js';
import { prisma } from '../../lib/prisma.js';
import { hmSchema, ymdSchema } from '../../lib/schemas.js';
import { dateToYMD, formatYMD, parseYMD, type YMD, ymdToDate } from '../../lib/time.js';
import { requireUserId } from '../auth/plugin.js';
import { getSettings, resolveDate } from '../me/context.js';
import { computeProgress, KHATMA_PRESETS, MUSHAF_PAGES, presetSummary } from './plan.js';

const security = [{ bearerAuth: [] }];

async function pagesReadOn(planId: string, date: YMD): Promise<number> {
  const agg = await prisma.khatmaLog.aggregate({ where: { planId, date: ymdToDate(date) }, _sum: { pages: true } });
  return agg._sum.pages ?? 0;
}

export async function serializePlan(plan: KhatmaPlan, today: YMD) {
  const progress = computeProgress(
    {
      khatmaCount: plan.khatmaCount,
      durationDays: plan.durationDays,
      startDate: dateToYMD(plan.startDate),
      currentPage: plan.currentPage,
    },
    today,
    await pagesReadOn(plan.id, today),
  );
  let position = null;
  if (progress.nextPage) {
    const ayah = await prisma.ayah.findFirst({
      where: { page: progress.nextPage },
      orderBy: { id: 'asc' },
      include: { surah: { select: { nameAr: true } } },
    });
    if (ayah) position = { page: progress.nextPage, ayahKey: ayah.key, surahNameAr: ayah.surah.nameAr, juz: ayah.juz };
  }
  return {
    id: plan.id,
    title: plan.title,
    status: plan.status,
    khatmaCount: plan.khatmaCount,
    durationDays: plan.durationDays,
    reminderTime: plan.reminderTime,
    dedicated: plan.dedicated,
    createdAt: plan.createdAt,
    ...progress,
    position,
  };
}

async function ownPlan(userId: string, id: string) {
  const plan = await prisma.khatmaPlan.findFirst({ where: { id, userId } });
  if (!plan) throw notFound('Khatma plan');
  return plan;
}

export const khatmaRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get('/khatma/presets', { schema: { tags: ['khatma'], summary: 'Plan presets with pages per day / per prayer' } }, async () => ({
    presets: KHATMA_PRESETS.map((p) => ({ ...p, ...presetSummary(p) })),
  }));

  app.get(
    '/me/khatmas',
    {
      schema: {
        tags: ['khatma'],
        security,
        summary: 'Khatma plans with live progress',
        querystring: z.object({ status: z.enum(['ACTIVE', 'COMPLETED', 'ARCHIVED']).optional() }),
      },
    },
    async (req) => {
      const userId = requireUserId(req);
      const today = resolveDate(await getSettings(userId));
      const plans = await prisma.khatmaPlan.findMany({
        where: { userId, status: req.query.status },
        orderBy: { createdAt: 'desc' },
      });
      return { plans: await Promise.all(plans.map((p) => serializePlan(p, today))) };
    },
  );

  app.post(
    '/me/khatmas',
    {
      schema: {
        tags: ['khatma'],
        security,
        summary: 'Start a khatma from a preset or custom duration. Any other active plan is archived.',
        body: z
          .object({
            preset: z.enum(KHATMA_PRESETS.map((p) => p.key) as [string, ...string[]]).optional(),
            durationDays: z.number().int().min(1).max(365).optional(),
            khatmaCount: z.number().int().min(1).max(10).optional(),
            title: z.string().max(120).optional(),
            startDate: ymdSchema.optional(),
            /** Resume from a page (e.g. continuing an existing reading). */
            startPage: z.number().int().min(1).max(MUSHAF_PAGES).default(1),
            reminderTime: hmSchema.nullable().optional(),
            dedicated: z.boolean().default(false),
          })
          .refine((b) => b.preset || b.durationDays, 'Provide a preset or durationDays'),
      },
    },
    async (req, reply) => {
      const userId = requireUserId(req);
      const settings = await getSettings(userId);
      const preset = KHATMA_PRESETS.find((p) => p.key === req.body.preset);
      const durationDays = req.body.durationDays ?? preset!.durationDays;
      const khatmaCount = req.body.khatmaCount ?? preset?.khatmaCount ?? 1;
      const startDate = req.body.startDate ? parseYMD(req.body.startDate) : resolveDate(settings);

      const plan = await prisma.$transaction(async (tx) => {
        await tx.khatmaPlan.updateMany({ where: { userId, status: 'ACTIVE' }, data: { status: 'ARCHIVED' } });
        return tx.khatmaPlan.create({
          data: {
            userId,
            title: req.body.title ?? preset?.title ?? `ختمة في ${durationDays} يوماً`,
            durationDays,
            khatmaCount,
            startDate: ymdToDate(startDate),
            currentPage: req.body.startPage,
            reminderTime: req.body.reminderTime ?? null,
            dedicated: req.body.dedicated,
          },
        });
      });
      reply.code(201);
      return serializePlan(plan, resolveDate(settings));
    },
  );

  app.get(
    '/me/khatmas/:id',
    { schema: { tags: ['khatma'], security, summary: 'One khatma plan', params: z.object({ id: z.string().uuid() }) } },
    async (req) => {
      const userId = requireUserId(req);
      return serializePlan(await ownPlan(userId, req.params.id), resolveDate(await getSettings(userId)));
    },
  );

  app.patch(
    '/me/khatmas/:id',
    {
      schema: {
        tags: ['khatma'],
        security,
        summary: 'Update title, reminder, dedication or status',
        params: z.object({ id: z.string().uuid() }),
        body: z
          .object({
            title: z.string().max(120),
            reminderTime: hmSchema.nullable(),
            dedicated: z.boolean(),
            status: z.enum(['ACTIVE', 'ARCHIVED']),
          })
          .partial(),
      },
    },
    async (req) => {
      const userId = requireUserId(req);
      await ownPlan(userId, req.params.id);
      const plan = await prisma.$transaction(async (tx) => {
        if (req.body.status === 'ACTIVE') {
          await tx.khatmaPlan.updateMany({
            where: { userId, status: 'ACTIVE', id: { not: req.params.id } },
            data: { status: 'ARCHIVED' },
          });
        }
        return tx.khatmaPlan.update({ where: { id: req.params.id }, data: req.body });
      });
      return serializePlan(plan, resolveDate(await getSettings(userId)));
    },
  );

  app.delete(
    '/me/khatmas/:id',
    { schema: { tags: ['khatma'], security, summary: 'Delete a plan', params: z.object({ id: z.string().uuid() }) } },
    async (req, reply) => {
      await ownPlan(requireUserId(req), req.params.id);
      await prisma.khatmaPlan.delete({ where: { id: req.params.id } });
      reply.code(204);
    },
  );

  app.post(
    '/me/khatmas/:id/progress',
    {
      schema: {
        tags: ['khatma'],
        security,
        summary:
          'Record reading: either `pages` read now, or `toPage` = last mushaf page finished (1–604) in the current khatma',
        params: z.object({ id: z.string().uuid() }),
        body: z
          .object({
            pages: z.number().int().min(1).max(MUSHAF_PAGES * 10).optional(),
            toPage: z.number().int().min(1).max(MUSHAF_PAGES).optional(),
            date: ymdSchema.optional(),
          })
          .refine((b) => (b.pages === undefined) !== (b.toPage === undefined), 'Send exactly one of pages or toPage'),
      },
    },
    async (req) => {
      const userId = requireUserId(req);
      const settings = await getSettings(userId);
      const plan = await ownPlan(userId, req.params.id);
      if (plan.status !== 'ACTIVE') throw badRequest('Only an active plan can record progress');
      const totalPages = MUSHAF_PAGES * plan.khatmaCount;
      const date = resolveDate(settings, req.body.date);

      let pages: number;
      if (req.body.toPage !== undefined) {
        const khatmaOffset = Math.floor((plan.currentPage - 1) / MUSHAF_PAGES) * MUSHAF_PAGES;
        const target = khatmaOffset + req.body.toPage + 1;
        pages = target - plan.currentPage;
        if (pages <= 0) throw badRequest(`Page ${req.body.toPage} was already recorded`);
      } else {
        pages = req.body.pages!;
      }
      pages = Math.min(pages, totalPages - (plan.currentPage - 1));
      if (pages <= 0) throw badRequest('This khatma is already complete');

      const fromPage = plan.currentPage;
      const currentPage = fromPage + pages;
      const completed = currentPage > totalPages;
      const updated = await prisma.$transaction(async (tx) => {
        await tx.khatmaLog.create({
          data: { planId: plan.id, date: ymdToDate(date), fromPage, toPage: currentPage - 1, pages },
        });
        if (completed && plan.dedicated) {
          await tx.dedication.create({
            data: {
              userId,
              type: 'KHATMA',
              amount: plan.khatmaCount,
              dedicateeName: settings.dedicateeName,
              refKey: `khatma:${plan.id}`,
            },
          });
        }
        return tx.khatmaPlan.update({
          where: { id: plan.id },
          data: { currentPage, status: completed ? 'COMPLETED' : 'ACTIVE' },
        });
      });
      return { recordedPages: pages, completed, plan: await serializePlan(updated, resolveDate(settings)) };
    },
  );

  app.get(
    '/me/khatmas/:id/logs',
    {
      schema: {
        tags: ['khatma'],
        security,
        summary: 'Reading history ("سجل القراءة") grouped by day',
        params: z.object({ id: z.string().uuid() }),
      },
    },
    async (req) => {
      const plan = await ownPlan(requireUserId(req), req.params.id);
      const logs = await prisma.khatmaLog.findMany({ where: { planId: plan.id }, orderBy: { createdAt: 'desc' } });
      const byDay = new Map<string, { date: string; pages: number; entries: typeof logs }>();
      for (const log of logs) {
        const key = formatYMD(dateToYMD(log.date));
        const day = byDay.get(key) ?? { date: key, pages: 0, entries: [] };
        day.pages += log.pages;
        day.entries.push(log);
        byDay.set(key, day);
      }
      return { days: [...byDay.values()] };
    },
  );
};
