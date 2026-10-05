import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { notFound } from '../../lib/errors.js';
import { prisma } from '../../lib/prisma.js';
import { requireUserId } from '../auth/plugin.js';
import { upcomingFor } from './dispatcher.js';

const security = [{ bearerAuth: [] }];

export const notificationRoutes: FastifyPluginAsyncZod = async (app) => {
  app.post(
    '/me/devices',
    {
      schema: {
        tags: ['notifications'],
        security,
        summary: 'Register or refresh an FCM token for this user (call on every app start and token refresh)',
        body: z.object({
          fcmToken: z.string().min(20).max(4096),
          platform: z.enum(['android', 'ios', 'web']),
          locale: z.string().max(10).default('ar'),
          appVersion: z.string().max(30).optional(),
        }),
      },
    },
    async (req) => {
      const userId = requireUserId(req);
      // A token belongs to one installation: re-assign it if another account had it.
      return prisma.device.upsert({
        where: { fcmToken: req.body.fcmToken },
        create: { ...req.body, userId },
        update: { ...req.body, userId, lastSeenAt: new Date() },
      });
    },
  );

  app.delete(
    '/me/devices/:token',
    {
      schema: {
        tags: ['notifications'],
        security,
        summary: 'Unregister a device token (e.g. on logout)',
        params: z.object({ token: z.string().min(20).max(4096) }),
      },
    },
    async (req, reply) => {
      const deleted = await prisma.device.deleteMany({ where: { fcmToken: req.params.token, userId: requireUserId(req) } });
      if (deleted.count === 0) throw notFound('Device');
      reply.code(204);
    },
  );

  app.get(
    '/me/notifications/upcoming',
    {
      schema: {
        tags: ['notifications'],
        security,
        summary:
          'Notifications scheduled for the next N hours. Apps can also use this list to schedule local notifications as an offline fallback.',
        querystring: z.object({ hours: z.coerce.number().int().min(1).max(168).default(24) }),
      },
    },
    async (req) => {
      const items = await upcomingFor(requireUserId(req), new Date(), req.query.hours);
      return { notifications: items.map((n) => ({ ...n, fireAt: n.fireAt.toISOString() })) };
    },
  );
};
