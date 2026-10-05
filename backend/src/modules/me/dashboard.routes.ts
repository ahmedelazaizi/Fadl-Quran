import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { prisma } from '../../lib/prisma.js';
import { formatYMD } from '../../lib/time.js';
import { requireUserId } from '../auth/plugin.js';
import { dailyHadithId, getHadith } from '../hadith/service.js';
import { serializePlan } from '../khatma/routes.js';
import { prayerDayPayload } from '../prayer/routes.js';
import { dailyAyahId, getSurahMeta, loadAyahs, serializeSurah } from '../quran/service.js';
import { tasbeehSummary } from '../tasbeeh/routes.js';
import { getSettings, hasLocation, prayerOptionsFromSettings, resolveDate } from './context.js';

export const dashboardRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get(
    '/me/dashboard',
    {
      schema: {
        tags: ['me'],
        security: [{ bearerAuth: [] }],
        summary: 'Everything the home screen needs in one call',
      },
    },
    async (req) => {
      const userId = requireUserId(req);
      const settings = await getSettings(userId);
      const today = resolveDate(settings);

      const ayahId = await dailyAyahId(formatYMD(today));
      const hadithId = await dailyHadithId(formatYMD(today));
      const [[dailyAyah], plan, tasbeeh, lastRead] = await Promise.all([
        loadAyahs({ id: { gte: ayahId, lte: ayahId } }, { tafsir: 'ar.muyassar' }),
        prisma.khatmaPlan.findFirst({ where: { userId, status: 'ACTIVE' }, orderBy: { createdAt: 'desc' } }),
        tasbeehSummary(userId, today, settings.tasbeehDailyGoal),
        prisma.bookmark.findFirst({
          where: { userId, kind: 'LAST_READ' },
          include: { ayah: { select: { key: true, page: true, surah: { select: { nameAr: true } } } } },
        }),
      ]);

      const prayer = hasLocation(settings)
        ? (() => {
            const p = prayerDayPayload(prayerOptionsFromSettings(settings), today);
            return { locationName: settings.locationName, hijri: p.hijri, gregorianAr: p.gregorianAr, next: p.next, prayers: p.prayers };
          })()
        : null;

      return {
        date: formatYMD(today),
        dedicateeName: settings.dedicateeName,
        dailyAyah: dailyAyah ? { surah: serializeSurah(await getSurahMeta(dailyAyah.surahId)), ayah: dailyAyah } : null,
        dailyHadith: hadithId ? await getHadith(hadithId) : null,
        prayer,
        khatma: plan ? await serializePlan(plan, today) : null,
        tasbeeh: { todayTotal: tasbeeh.todayTotal, dailyGoal: tasbeeh.dailyGoal, goalPercent: tasbeeh.goalPercent, streakDays: tasbeeh.streakDays },
        lastRead: lastRead
          ? { ayahKey: lastRead.ayah.key, page: lastRead.ayah.page, surahNameAr: lastRead.ayah.surah.nameAr }
          : null,
      };
    },
  );
};

export const statsRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get(
    '/stats/dedications',
    { schema: { tags: ['dedications'], summary: 'Global dedication counter ("١٤٬٢٥١ إهداء")' } },
    async () => {
      const byType = await prisma.dedication.groupBy({ by: ['type'], _count: true, _sum: { amount: true } });
      return {
        total: byType.reduce((s, t) => s + t._count, 0),
        byType: Object.fromEntries(byType.map((t) => [t.type, { count: t._count, amount: t._sum.amount ?? 0 }])),
      };
    },
  );
};
