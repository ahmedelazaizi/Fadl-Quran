import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { badRequest, notFound } from '../../lib/errors.js';
import { prisma } from '../../lib/prisma.js';
import { ayahKeySchema, ymdSchema } from '../../lib/schemas.js';
import { formatYMD, ymdToDate } from '../../lib/time.js';
import { requireUserId } from '../auth/plugin.js';
import { findAyahByKey, serializeAyah } from '../quran/service.js';
import { getSettings, resolveDate } from './context.js';

const security = [{ bearerAuth: [] }];

const bookmarkInclude = { ayah: { include: { surah: { select: { nameAr: true } } } } } as const;

function serializeBookmark(b: {
  id: string;
  kind: string;
  note: string | null;
  createdAt: Date;
  updatedAt: Date;
  ayah: Parameters<typeof serializeAyah>[0] & { surah: { nameAr: string } };
}) {
  return {
    id: b.id,
    kind: b.kind,
    note: b.note,
    createdAt: b.createdAt,
    updatedAt: b.updatedAt,
    surahNameAr: b.ayah.surah.nameAr,
    ayah: serializeAyah(b.ayah),
  };
}

export const libraryRoutes: FastifyPluginAsyncZod = async (app) => {
  // ───────────── Bookmarks & last read position ─────────────

  app.get('/me/bookmarks', { schema: { tags: ['bookmarks'], security, summary: 'Saved bookmarks (الفواصل)' } }, async (req) => {
    const bookmarks = await prisma.bookmark.findMany({
      where: { userId: requireUserId(req), kind: 'BOOKMARK' },
      orderBy: { createdAt: 'desc' },
      include: bookmarkInclude,
    });
    return { bookmarks: bookmarks.map(serializeBookmark) };
  });

  app.post(
    '/me/bookmarks',
    {
      schema: {
        tags: ['bookmarks'],
        security,
        summary: 'Bookmark an ayah (idempotent; updates the note if it exists)',
        body: z.object({ ayahKey: ayahKeySchema, note: z.string().max(500).nullable().optional() }),
      },
    },
    async (req, reply) => {
      const userId = requireUserId(req);
      const ayah = await findAyahByKey(req.body.ayahKey);
      const bookmark = await prisma.bookmark.upsert({
        where: { userId_ayahId_kind: { userId, ayahId: ayah.id, kind: 'BOOKMARK' } },
        create: { userId, ayahId: ayah.id, kind: 'BOOKMARK', note: req.body.note ?? null },
        update: { note: req.body.note ?? undefined },
        include: bookmarkInclude,
      });
      reply.code(201);
      return serializeBookmark(bookmark);
    },
  );

  app.delete(
    '/me/bookmarks/:id',
    { schema: { tags: ['bookmarks'], security, summary: 'Remove a bookmark', params: z.object({ id: z.string().uuid() }) } },
    async (req, reply) => {
      const deleted = await prisma.bookmark.deleteMany({ where: { id: req.params.id, userId: requireUserId(req) } });
      if (deleted.count === 0) throw notFound('Bookmark');
      reply.code(204);
    },
  );

  app.get('/me/last-read', { schema: { tags: ['bookmarks'], security, summary: 'Last reading position' } }, async (req) => {
    const last = await prisma.bookmark.findFirst({
      where: { userId: requireUserId(req), kind: 'LAST_READ' },
      include: bookmarkInclude,
    });
    return { lastRead: last ? serializeBookmark(last) : null };
  });

  app.put(
    '/me/last-read',
    {
      schema: {
        tags: ['bookmarks'],
        security,
        summary: 'Save the last reading position (one per user)',
        body: z.object({ ayahKey: ayahKeySchema }),
      },
    },
    async (req) => {
      const userId = requireUserId(req);
      const ayah = await findAyahByKey(req.body.ayahKey);
      const saved = await prisma.$transaction(async (tx) => {
        await tx.bookmark.deleteMany({ where: { userId, kind: 'LAST_READ', ayahId: { not: ayah.id } } });
        return tx.bookmark.upsert({
          where: { userId_ayahId_kind: { userId, ayahId: ayah.id, kind: 'LAST_READ' } },
          create: { userId, ayahId: ayah.id, kind: 'LAST_READ' },
          update: {},
          include: bookmarkInclude,
        });
      });
      return { lastRead: serializeBookmark(saved) };
    },
  );

  // ───────────── Athkar daily progress ─────────────

  app.get(
    '/me/athkar/progress',
    {
      schema: {
        tags: ['athkar'],
        security,
        summary: 'Per-category completion for a day ("أتممت 12 من 15")',
        querystring: z.object({ date: ymdSchema.optional() }),
      },
    },
    async (req) => {
      const userId = requireUserId(req);
      const date = resolveDate(await getSettings(userId), req.query.date);
      const [categories, progress] = await Promise.all([
        prisma.athkarCategory.findMany({
          where: { featured: true },
          orderBy: { sortOrder: 'asc' },
          include: { items: { select: { id: true, repeat: true } } },
        }),
        prisma.athkarProgress.findMany({ where: { userId, date: ymdToDate(date) } }),
      ]);
      const counts = new Map(progress.map((p) => [p.dhikrId, p.count]));
      return {
        date: formatYMD(date),
        categories: categories.map((c) => {
          const completed = c.items.filter((i) => (counts.get(i.id) ?? 0) >= i.repeat).length;
          return {
            slug: c.slug,
            nameAr: c.nameAr,
            total: c.items.length,
            completed,
            percent: c.items.length ? Math.floor((completed / c.items.length) * 100) : 0,
            status: completed === 0 ? 'NOT_STARTED' : completed === c.items.length ? 'COMPLETED' : 'PARTIAL',
          };
        }),
        items: progress.map((p) => ({ dhikrId: p.dhikrId, count: p.count })),
      };
    },
  );

  app.put(
    '/me/athkar/progress',
    {
      schema: {
        tags: ['athkar'],
        security,
        summary: 'Set how many times a dhikr was said today (absolute value; last write wins)',
        body: z.object({
          dhikrId: z.number().int().positive(),
          count: z.number().int().min(0).max(10000),
          date: ymdSchema.optional(),
        }),
      },
    },
    async (req) => {
      const userId = requireUserId(req);
      const date = ymdToDate(resolveDate(await getSettings(userId), req.body.date));
      const dhikr = await prisma.dhikr.findUnique({ where: { id: req.body.dhikrId } });
      if (!dhikr) throw notFound('Dhikr');
      const where = { userId_dhikrId_date: { userId, dhikrId: dhikr.id, date } };
      if (req.body.count === 0) {
        await prisma.athkarProgress.deleteMany({ where: { userId, dhikrId: dhikr.id, date } });
      } else {
        await prisma.athkarProgress.upsert({
          where,
          create: { userId, dhikrId: dhikr.id, date, count: req.body.count },
          update: { count: req.body.count },
        });
      }
      return { dhikrId: dhikr.id, count: req.body.count, repeat: dhikr.repeat, done: req.body.count >= dhikr.repeat };
    },
  );

  // ───────────── Daily checklist (Ramadan sunnahs etc.) ─────────────

  app.get(
    '/me/checklist',
    {
      schema: {
        tags: ['ramadan'],
        security,
        summary: 'Checked items for a day (e.g. suhoor, iftar-dua, taraweeh, feed-fasting)',
        querystring: z.object({ date: ymdSchema.optional() }),
      },
    },
    async (req) => {
      const userId = requireUserId(req);
      const date = resolveDate(await getSettings(userId), req.query.date);
      const items = await prisma.dailyChecklist.findMany({ where: { userId, date: ymdToDate(date), done: true } });
      return { date: formatYMD(date), done: items.map((i) => i.key) };
    },
  );

  app.put(
    '/me/checklist',
    {
      schema: {
        tags: ['ramadan'],
        security,
        summary: 'Check / uncheck an item',
        body: z.object({
          key: z.string().regex(/^[a-z0-9-]{2,40}$/),
          done: z.boolean(),
          date: ymdSchema.optional(),
        }),
      },
    },
    async (req) => {
      const userId = requireUserId(req);
      const date = ymdToDate(resolveDate(await getSettings(userId), req.body.date));
      if (req.body.done) {
        await prisma.dailyChecklist.upsert({
          where: { userId_date_key: { userId, date, key: req.body.key } },
          create: { userId, date, key: req.body.key },
          update: { done: true },
        });
      } else {
        await prisma.dailyChecklist.deleteMany({ where: { userId, date, key: req.body.key } });
      }
      return { key: req.body.key, done: req.body.done };
    },
  );

  // ───────────── Personal duas ─────────────

  app.get('/me/duas', { schema: { tags: ['duas'], security, summary: 'Personal duas written by the user' } }, async (req) => ({
    duas: await prisma.customDua.findMany({ where: { userId: requireUserId(req) }, orderBy: { createdAt: 'desc' } }),
  }));

  app.post(
    '/me/duas',
    {
      schema: {
        tags: ['duas'],
        security,
        summary: 'Save a personal dua ("حفظ الدعاء")',
        body: z.object({ text: z.string().min(2).max(2000) }),
      },
    },
    async (req, reply) => {
      reply.code(201);
      return prisma.customDua.create({ data: { userId: requireUserId(req), text: req.body.text } });
    },
  );

  app.delete(
    '/me/duas/:id',
    { schema: { tags: ['duas'], security, summary: 'Delete a personal dua', params: z.object({ id: z.string().uuid() }) } },
    async (req, reply) => {
      const deleted = await prisma.customDua.deleteMany({ where: { id: req.params.id, userId: requireUserId(req) } });
      if (deleted.count === 0) throw notFound('Dua');
      reply.code(204);
    },
  );

  // ───────────── Sadaqah jariyah: إهداء الثواب ─────────────

  app.post(
    '/me/dedications',
    {
      schema: {
        tags: ['dedications'],
        security,
        summary: 'Record a dedication of reward ("إهداء الثواب") to the configured dedicatee',
        body: z.object({
          type: z.enum(['KHATMA', 'READING', 'LISTENING', 'TASBEEH', 'ATHKAR', 'DUA', 'OTHER']),
          amount: z.number().int().min(1).max(1_000_000).default(1),
          refKey: z.string().max(80).optional(),
        }),
      },
    },
    async (req, reply) => {
      const userId = requireUserId(req);
      const settings = await getSettings(userId);
      if (!settings.dedicateeName) throw badRequest('Set dedicateeName in /me/settings first');
      reply.code(201);
      return prisma.dedication.create({
        data: { userId, ...req.body, dedicateeName: settings.dedicateeName },
      });
    },
  );

  app.get(
    '/me/dedications/stats',
    { schema: { tags: ['dedications'], security, summary: 'Totals per type for this user, plus the global counter' } },
    async (req) => {
      const userId = requireUserId(req);
      const [byType, global, settings] = await Promise.all([
        prisma.dedication.groupBy({ by: ['type'], where: { userId }, _sum: { amount: true }, _count: true }),
        prisma.dedication.count(),
        getSettings(userId),
      ]);
      return {
        dedicateeName: settings.dedicateeName,
        totalDedications: byType.reduce((s, t) => s + t._count, 0),
        byType: Object.fromEntries(byType.map((t) => [t.type, { count: t._count, amount: t._sum.amount ?? 0 }])),
        globalDedications: global,
      };
    },
  );
};
