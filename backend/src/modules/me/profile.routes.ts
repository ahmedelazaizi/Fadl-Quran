import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { badRequest } from '../../lib/errors.js';
import { prisma } from '../../lib/prisma.js';
import { hmSchema, latitudeSchema, longitudeSchema, timezoneSchema, ymdSchema } from '../../lib/schemas.js';
import { requireUserId } from '../auth/plugin.js';
import { CALC_METHOD_KEYS, HIGH_LAT_RULES, MADHABS, PRAYERS } from '../prayer/calc.js';
import { prayerDayPayload } from '../prayer/routes.js';
import { getSettings, prayerOptionsFromSettings, resolveDate } from './context.js';

const adjustmentsSchema = z.partialRecord(z.enum(PRAYERS), z.number().int().min(-30).max(30));

const settingsPatch = z
  .object({
    latitude: latitudeSchema,
    longitude: longitudeSchema,
    locationName: z.string().max(120).nullable(),
    timezone: timezoneSchema,
    calcMethod: z.enum(CALC_METHOD_KEYS),
    madhab: z.enum(MADHABS),
    highLatRule: z.enum(HIGH_LAT_RULES).nullable(),
    adjustments: adjustmentsSchema,
    hijriAdjustment: z.number().int().min(-3).max(3),
    theme: z.enum(['light', 'dark', 'auto']),
    mushafScript: z.enum(['uthmani_hafs', 'warsh', 'naskh']),
    fontSize: z.number().int().min(18).max(32),
    reciterId: z.string().max(60),
    audioQuality: z.union([z.literal(64), z.literal(128), z.literal(192)]),
    continuousPlay: z.boolean(),
    tafsirSlug: z.string().max(40),
    language: z.enum(['ar', 'en']),
    dedicateeName: z.string().max(120).nullable(),
    tasbeehDailyGoal: z.number().int().min(1).max(100000),
  })
  .partial()
  .refine(
    (s) => (s.latitude === undefined) === (s.longitude === undefined),
    'latitude and longitude must be sent together',
  );

const notificationsPatch = z
  .object({
    enabled: z.boolean(),
    adhan: z.partialRecord(z.enum(PRAYERS), z.boolean()),
    adhanSound: z.string().max(40),
    preAlertMinutes: z.number().int().min(0).max(60),
    morningAthkarTime: hmSchema.nullable(),
    eveningAthkarTime: hmSchema.nullable(),
    sleepAthkarTime: hmSchema.nullable(),
    qiyamEnabled: z.boolean(),
    duhaEnabled: z.boolean(),
    fridayKahf: z.boolean(),
    fridayHour: z.boolean(),
    mondayThursdayFast: z.boolean(),
    whiteDaysFast: z.boolean(),
    khatmaReminder: z.boolean(),
  })
  .partial();

export const profileRoutes: FastifyPluginAsyncZod = async (app) => {
  const security = [{ bearerAuth: [] }];

  app.get('/me', { schema: { tags: ['me'], security, summary: 'Profile, settings and notification preferences' } }, async (req) => {
    const userId = requireUserId(req);
    const user = await prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { id: true, displayName: true, createdAt: true },
    });
    const [settings, notifications] = await Promise.all([
      getSettings(userId),
      prisma.notificationSettings.upsert({ where: { userId }, create: { userId }, update: {} }),
    ]);
    return { user, settings, notifications };
  });

  app.patch(
    '/me',
    {
      schema: { tags: ['me'], security, summary: 'Update profile', body: z.object({ displayName: z.string().max(80).nullable() }) },
    },
    async (req) =>
      prisma.user.update({
        where: { id: requireUserId(req) },
        data: { displayName: req.body.displayName },
        select: { id: true, displayName: true },
      }),
  );

  app.delete(
    '/me',
    { schema: { tags: ['me'], security, summary: 'Delete the account and all synced data' } },
    async (req, reply) => {
      await prisma.user.delete({ where: { id: requireUserId(req) } });
      reply.code(204);
    },
  );

  app.get('/me/settings', { schema: { tags: ['me'], security, summary: 'App settings' } }, async (req) =>
    getSettings(requireUserId(req)),
  );

  app.patch(
    '/me/settings',
    { schema: { tags: ['me'], security, summary: 'Update app settings (partial)', body: settingsPatch } },
    async (req) => {
      const userId = requireUserId(req);
      const { reciterId, tafsirSlug } = req.body;
      if (reciterId && !(await prisma.reciter.findUnique({ where: { id: reciterId } }))) {
        throw badRequest(`Unknown reciter "${reciterId}"`);
      }
      if (tafsirSlug && !(await prisma.textEdition.findFirst({ where: { slug: tafsirSlug, type: 'TAFSIR' } }))) {
        throw badRequest(`Unknown tafsir "${tafsirSlug}"`);
      }
      await getSettings(userId);
      return prisma.userSettings.update({ where: { userId }, data: req.body });
    },
  );

  app.get(
    '/me/notifications',
    { schema: { tags: ['notifications'], security, summary: 'Notification preferences' } },
    async (req) => {
      const userId = requireUserId(req);
      return prisma.notificationSettings.upsert({ where: { userId }, create: { userId }, update: {} });
    },
  );

  app.patch(
    '/me/notifications',
    {
      schema: { tags: ['notifications'], security, summary: 'Update notification preferences (partial)', body: notificationsPatch },
    },
    async (req) => {
      const userId = requireUserId(req);
      const current = await prisma.notificationSettings.upsert({ where: { userId }, create: { userId }, update: {} });
      const { adhan, ...rest } = req.body;
      return prisma.notificationSettings.update({
        where: { userId },
        data: {
          ...rest,
          // Merge per-prayer toggles instead of replacing the whole map.
          ...(adhan ? { adhan: { ...(current.adhan as Record<string, boolean>), ...adhan } } : {}),
        },
      });
    },
  );

  app.get(
    '/me/prayer',
    {
      schema: {
        tags: ['prayer'],
        security,
        summary: "Prayer times for the user's saved location and calculation settings",
        querystring: z.object({ date: ymdSchema.optional() }),
      },
    },
    async (req) => {
      const settings = await getSettings(requireUserId(req));
      const payload = prayerDayPayload(prayerOptionsFromSettings(settings), resolveDate(settings, req.query.date));
      return { ...payload, locationName: settings.locationName };
    },
  );
};
