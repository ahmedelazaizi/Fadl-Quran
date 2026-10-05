import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { notFound } from '../../lib/errors.js';
import { prisma } from '../../lib/prisma.js';
import { paginationSchema, timezoneSchema, ymdSchema } from '../../lib/schemas.js';
import { formatYMD, parseYMD, todayIn } from '../../lib/time.js';
import { dailyHadithId, getBook, getHadith, searchHadith, serializeHadith } from './service.js';

const GROUP_AR = { nine: 'الكتب التسعة', forties: 'الأربعينيات', other: 'كتب أخرى' } as const;

export const hadithRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get('/hadith/books', { schema: { tags: ['hadith'], summary: 'Embedded hadith collections' } }, async () => {
    const books = await prisma.hadithBook.findMany({ orderBy: { sortOrder: 'asc' } });
    return {
      books: books.map((b) => ({
        slug: b.slug,
        nameAr: b.nameAr,
        nameEn: b.nameEn,
        authorAr: b.authorAr,
        group: b.group,
        groupAr: GROUP_AR[b.group as keyof typeof GROUP_AR] ?? b.group,
        hadithCount: b.hadithCount,
      })),
    };
  });

  app.get(
    '/hadith/books/:slug',
    {
      schema: {
        tags: ['hadith'],
        summary: 'A collection with its chapters (كتب/أبواب) and hadith counts',
        params: z.object({ slug: z.string().max(40) }),
      },
    },
    async (req) => {
      const book = await getBook(req.params.slug);
      const chapters = await prisma.hadithChapter.findMany({
        where: { bookId: book.id },
        orderBy: { number: 'asc' },
        include: { _count: { select: { hadiths: true } } },
      });
      return {
        slug: book.slug,
        nameAr: book.nameAr,
        authorAr: book.authorAr,
        hadithCount: book.hadithCount,
        chapters: chapters.map((c) => ({ id: c.id, number: c.number, nameAr: c.nameAr, nameEn: c.nameEn, count: c._count.hadiths })),
      };
    },
  );

  app.get(
    '/hadith/books/:slug/hadiths',
    {
      schema: {
        tags: ['hadith'],
        summary: 'Hadiths of a collection, optionally one chapter, in book order',
        params: z.object({ slug: z.string().max(40) }),
        querystring: paginationSchema.extend({ chapterId: z.coerce.number().int().positive().optional() }),
      },
    },
    async (req) => {
      const book = await getBook(req.params.slug);
      const where = { bookId: book.id, ...(req.query.chapterId ? { chapterId: req.query.chapterId } : {}) };
      const [total, hadiths] = await Promise.all([
        prisma.hadith.count({ where }),
        prisma.hadith.findMany({
          where,
          orderBy: { number: 'asc' },
          take: req.query.limit,
          skip: req.query.offset,
          include: { book: { select: { slug: true, nameAr: true } }, chapter: { select: { nameAr: true } } },
        }),
      ]);
      return { total, hadiths: hadiths.map(serializeHadith) };
    },
  );

  app.get(
    '/hadith/search',
    {
      schema: {
        tags: ['hadith'],
        summary: 'Search hadith text (diacritics-insensitive); authentic results first',
        querystring: paginationSchema.extend({ q: z.string().min(2).max(200), book: z.string().max(40).optional() }),
      },
    },
    async (req) => ({ query: req.query.q, ...(await searchHadith(req.query.q, req.query)) }),
  );

  app.get(
    '/hadith/daily',
    {
      schema: {
        tags: ['hadith'],
        summary: '"حديث اليوم" from An-Nawawi\'s Forty / Riyad as-Salihin',
        querystring: z.object({ date: ymdSchema.optional(), tz: timezoneSchema.default('Asia/Riyadh') }),
      },
    },
    async (req) => {
      const date = req.query.date ? parseYMD(req.query.date) : todayIn(req.query.tz);
      const id = await dailyHadithId(formatYMD(date));
      if (!id) throw notFound('Daily hadith');
      return { date: formatYMD(date), hadith: await getHadith(id) };
    },
  );

  app.get(
    '/hadith/:id',
    { schema: { tags: ['hadith'], summary: 'One hadith with verification links', params: z.object({ id: z.coerce.number().int().positive() }) } },
    async (req) => getHadith(req.params.id),
  );
};
