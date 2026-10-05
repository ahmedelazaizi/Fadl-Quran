import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { badRequest, notFound } from '../../lib/errors.js';
import { prisma } from '../../lib/prisma.js';
import { todayIn, ymdToDate } from '../../lib/time.js';
import { requireUserId } from '../auth/plugin.js';
import { getCollection, isValidAmenTarget, searchAthkar, serializeDhikr } from './service.js';

export const athkarRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get(
    '/athkar/categories',
    {
      schema: {
        tags: ['athkar'],
        summary: 'Athkar categories (featured first) with item counts',
        querystring: z.object({ featured: z.enum(['true', 'false']).optional() }),
      },
    },
    async (req) => {
      const categories = await prisma.athkarCategory.findMany({
        where: req.query.featured ? { featured: req.query.featured === 'true' } : undefined,
        orderBy: { sortOrder: 'asc' },
        include: { _count: { select: { items: true } } },
      });
      return {
        categories: categories.map((c) => ({
          id: c.id,
          slug: c.slug,
          nameAr: c.nameAr,
          featured: c.featured,
          count: c._count.items,
        })),
      };
    },
  );

  app.get(
    '/athkar/categories/:slug',
    {
      schema: {
        tags: ['athkar'],
        summary: 'A category with all its athkar (text, virtue, repeat count, reference)',
        params: z.object({ slug: z.string().max(60) }),
      },
    },
    async (req) => {
      const category = await prisma.athkarCategory.findUnique({
        where: { slug: req.params.slug },
        include: { items: { orderBy: { sortOrder: 'asc' } } },
      });
      if (!category) throw notFound(`Athkar category "${req.params.slug}"`);
      return {
        id: category.id,
        slug: category.slug,
        nameAr: category.nameAr,
        totalRepeats: category.items.reduce((sum, d) => sum + d.repeat, 0),
        items: category.items.map(serializeDhikr),
      };
    },
  );

  app.get(
    '/athkar/search',
    {
      schema: {
        tags: ['athkar'],
        summary: 'Search athkar and prophetic duas (diacritics-insensitive)',
        querystring: z.object({ q: z.string().min(2).max(100), limit: z.coerce.number().int().min(1).max(50).default(20) }),
      },
    },
    async (req) => ({ query: req.query.q, results: await searchAthkar(req.query.q, req.query.limit) }),
  );

  app.get('/duas/collections', { schema: { tags: ['duas'], summary: 'Dua collections (parents, deceased, healing…)' } }, async () => {
    const collections = await prisma.duaCollection.findMany({
      orderBy: { sortOrder: 'asc' },
      include: { _count: { select: { items: true } } },
    });
    return { collections: collections.map((c) => ({ slug: c.slug, nameAr: c.nameAr, count: c._count.items })) };
  });

  app.get(
    '/duas/collections/:slug',
    {
      schema: {
        tags: ['duas'],
        summary: 'Duas in a collection with global "آمين" counters',
        params: z.object({ slug: z.string().max(60) }),
      },
    },
    async (req) => getCollection(req.params.slug),
  );

  app.post(
    '/duas/amen',
    {
      preHandler: app.authenticate,
      schema: {
        tags: ['duas'],
        security: [{ bearerAuth: [] }],
        summary: 'Say "آمين" on a dua (counted once per user per day)',
        body: z.object({ targetKey: z.string().max(60) }),
      },
    },
    async (req) => {
      const userId = requireUserId(req);
      const { targetKey } = req.body;
      if (!(await isValidAmenTarget(targetKey))) throw badRequest(`Unknown dua "${targetKey}"`);
      const date = ymdToDate(todayIn('UTC'));
      const counted = await prisma.$transaction(async (tx) => {
        const inserted = await tx.userAmen.createMany({
          data: [{ userId, targetKey, date }],
          skipDuplicates: true,
        });
        if (inserted.count === 0) return false;
        await tx.amenCounter.upsert({
          where: { targetKey },
          create: { targetKey, count: 1 },
          update: { count: { increment: 1 } },
        });
        return true;
      });
      const counter = await prisma.amenCounter.findUnique({ where: { targetKey } });
      return { targetKey, counted, amenCount: counter?.count ?? 0 };
    },
  );
};
