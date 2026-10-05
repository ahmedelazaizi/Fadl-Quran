import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { notFound } from '../../lib/errors.js';
import { prisma } from '../../lib/prisma.js';
import { ayahKeySchema, timezoneSchema, ymdSchema } from '../../lib/schemas.js';
import { formatYMD, parseYMD, todayIn } from '../../lib/time.js';
import {
  dailyAyahId,
  findAyahByKey,
  getReciter,
  getSurahMeta,
  getTafsir,
  hizbOf,
  listSurahs,
  loadAyahs,
  pickBitrate,
  serializeSurah,
  surahAudioUrl,
  TOTAL_PAGES,
  verseAudioUrl,
} from './service.js';

const extrasQuery = z.object({
  tafsir: z.string().max(40).optional().describe('Local tafsir edition slug, e.g. ar.muyassar'),
  translation: z.string().max(40).optional().describe('Local translation edition slug, e.g. en.sahih'),
});

const surahId = z.coerce.number().int().min(1).max(114);

/** Surahs that appear on a set of ayahs, for page / juz headers. */
async function surahsFor(ayahs: { surahId: number }[]) {
  const all = await listSurahs();
  return [...new Set(ayahs.map((a) => a.surahId))].map((id) => serializeSurah(all[id - 1]!));
}

export const quranRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get('/quran/surahs', { schema: { tags: ['quran'], summary: 'Index of the 114 surahs' } }, async () => ({
    surahs: (await listSurahs()).map(serializeSurah),
  }));

  app.get(
    '/quran/surahs/:id',
    {
      schema: {
        tags: ['quran'],
        summary: 'A surah with its ayahs (optionally a range) and local tafsir / translation',
        params: z.object({ id: surahId }),
        querystring: extrasQuery.extend({
          from: z.coerce.number().int().min(1).optional(),
          to: z.coerce.number().int().min(1).optional(),
        }),
      },
    },
    async (req) => {
      const surah = await getSurahMeta(req.params.id);
      const from = Math.min(req.query.from ?? 1, surah.ayahCount);
      const to = Math.min(req.query.to ?? surah.ayahCount, surah.ayahCount);
      const first = await prisma.ayah.findUniqueOrThrow({ where: { surahId_number: { surahId: surah.id, number: 1 } } });
      const ayahs = await loadAyahs(
        { id: { gte: first.id + from - 1, lte: first.id + to - 1 } },
        { tafsir: req.query.tafsir, translation: req.query.translation },
      );
      return {
        surah: serializeSurah(surah),
        // Fatiha's basmala is ayah 1; At-Tawbah has none.
        showBasmala: surah.id !== 1 && surah.id !== 9,
        juz: first.juz,
        ...hizbOf(first.hizbQuarter),
        ayahs,
      };
    },
  );

  app.get(
    '/quran/pages/:page',
    {
      schema: {
        tags: ['quran'],
        summary: 'One Madani mushaf page (1–604)',
        params: z.object({ page: z.coerce.number().int().min(1).max(TOTAL_PAGES) }),
        querystring: extrasQuery,
      },
    },
    async (req) => {
      const ayahs = await loadAyahs({ page: req.params.page }, req.query);
      const first = ayahs[0]!;
      return {
        page: req.params.page,
        totalPages: TOTAL_PAGES,
        juz: first.juz,
        hizb: first.hizb,
        quarter: first.quarter,
        surahs: await surahsFor(ayahs),
        ayahs,
      };
    },
  );

  app.get(
    '/quran/juz/:juz',
    {
      schema: {
        tags: ['quran'],
        summary: 'All ayahs of a juz (1–30)',
        params: z.object({ juz: z.coerce.number().int().min(1).max(30) }),
        querystring: extrasQuery,
      },
    },
    async (req) => {
      const ayahs = await loadAyahs({ juz: req.params.juz }, req.query);
      return {
        juz: req.params.juz,
        startPage: ayahs[0]!.page,
        endPage: ayahs[ayahs.length - 1]!.page,
        surahs: await surahsFor(ayahs),
        ayahs,
      };
    },
  );

  app.get(
    '/quran/ayahs/:key',
    {
      schema: {
        tags: ['quran'],
        summary: 'A single ayah, e.g. 2:255',
        params: z.object({ key: ayahKeySchema }),
        querystring: extrasQuery,
      },
    },
    async (req) => {
      const ayah = await findAyahByKey(req.params.key);
      const [full] = await loadAyahs({ id: { gte: ayah.id, lte: ayah.id } }, req.query);
      return { surah: serializeSurah(await getSurahMeta(ayah.surahId)), ayah: full };
    },
  );

  app.get(
    '/quran/ayahs/:key/tafsir',
    {
      schema: {
        tags: ['quran'],
        summary: 'Tafsir of one ayah (local, or fetched from Quran.com and cached)',
        params: z.object({ key: ayahKeySchema }),
        querystring: z.object({ edition: z.string().max(40).default('ar.muyassar') }),
      },
    },
    async (req) => getTafsir(req.params.key, req.query.edition),
  );

  app.get(
    '/quran/editions',
    { schema: { tags: ['quran'], summary: 'Available tafsirs and translations' } },
    async () => ({
      editions: await prisma.textEdition.findMany({
        orderBy: [{ type: 'asc' }, { isDefault: 'desc' }, { slug: 'asc' }],
        select: { slug: true, type: true, language: true, nameAr: true, nameEn: true, source: true, isDefault: true },
      }),
    }),
  );

  app.get('/quran/reciters', { schema: { tags: ['quran'], summary: 'Reciters with available audio' } }, async () => ({
    reciters: await prisma.reciter.findMany({ orderBy: { sortOrder: 'asc' } }),
  }));

  app.get(
    '/quran/audio/surahs/:id',
    {
      schema: {
        tags: ['quran'],
        summary: 'Audio playlist for a surah: one file per ayah (for highlighting/repeat) and a full-surah file when available',
        params: z.object({ id: surahId }),
        querystring: z.object({
          reciter: z.string().max(60).default('ar.abdulbasitmurattal'),
          bitrate: z.coerce.number().int().optional(),
        }),
      },
    },
    async (req) => {
      const [surah, reciter] = await Promise.all([getSurahMeta(req.params.id), getReciter(req.query.reciter)]);
      const bitrate = pickBitrate(reciter.verseBitrates, req.query.bitrate);
      const ayahs = await prisma.ayah.findMany({
        where: { surahId: surah.id },
        orderBy: { id: 'asc' },
        select: { id: true, key: true, number: true },
      });
      return {
        surah: serializeSurah(surah),
        reciter: { id: reciter.id, nameAr: reciter.nameAr, style: reciter.style, riwaya: reciter.riwaya },
        bitrate,
        surahUrl: reciter.surahBitrate ? surahAudioUrl(reciter.id, reciter.surahBitrate, surah.id) : null,
        ayahs: ayahs.map((a) => ({ key: a.key, number: a.number, url: verseAudioUrl(reciter.id, bitrate, a.id) })),
      };
    },
  );

  app.get(
    '/quran/daily-ayah',
    {
      schema: {
        tags: ['quran'],
        summary: '"قبس اليوم" — the same ayah for everyone on a given date',
        querystring: extrasQuery.extend({ date: ymdSchema.optional(), tz: timezoneSchema.default('Asia/Riyadh') }),
      },
    },
    async (req) => {
      const date = req.query.date ? parseYMD(req.query.date) : todayIn(req.query.tz);
      const id = await dailyAyahId(formatYMD(date));
      const [ayah] = await loadAyahs(
        { id: { gte: id, lte: id } },
        { tafsir: req.query.tafsir ?? 'ar.muyassar', translation: req.query.translation },
      );
      if (!ayah) throw notFound('Daily ayah');
      return { date: formatYMD(date), surah: serializeSurah(await getSurahMeta(ayah.surahId)), ayah };
    },
  );
};
