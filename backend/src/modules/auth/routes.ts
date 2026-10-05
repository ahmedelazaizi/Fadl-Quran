import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { unauthorized } from '../../lib/errors.js';
import { prisma } from '../../lib/prisma.js';
import { timezoneSchema } from '../../lib/schemas.js';
import { DEFAULT_TASBEEH } from '../tasbeeh/defaults.js';
import { newDeviceSecret, sha256 } from './secret.js';

/**
 * The app is free and has no sign-in. Each installation gets an anonymous
 * identity on first launch: a long-lived device secret (kept on the device)
 * that is exchanged for short-lived access tokens.
 */
export const authRoutes: FastifyPluginAsyncZod = async (app) => {
  const strictLimit = { config: { rateLimit: { max: 10, timeWindow: '1 minute' } } };

  app.post(
    '/auth/anonymous',
    {
      ...strictLimit,
      schema: {
        tags: ['auth'],
        summary: 'Create the anonymous identity of an installation (called once on first launch)',
        body: z.object({ timezone: timezoneSchema.optional() }).default({}),
      },
    },
    async (req, reply) => {
      const secret = newDeviceSecret();
      const user = await prisma.user.create({
        data: {
          settings: { create: { timezone: req.body.timezone } },
          notifications: { create: {} },
          tasbeehDhikrs: {
            create: DEFAULT_TASBEEH.map((d, i) => ({ text: d.text, target: d.target, sortOrder: i })),
          },
          credentials: { create: { secretHash: secret.hash } },
        },
      });
      reply.code(201);
      return {
        userId: user.id,
        deviceSecret: secret.token,
        accessToken: app.jwt.sign({ sub: user.id }),
        tokenType: 'Bearer' as const,
      };
    },
  );

  app.post(
    '/auth/token',
    {
      ...strictLimit,
      schema: {
        tags: ['auth'],
        summary: 'Exchange the device secret for a fresh access token',
        body: z.object({ deviceSecret: z.string().min(20).max(200) }),
      },
    },
    async (req) => {
      const credential = await prisma.deviceCredential.findUnique({
        where: { secretHash: sha256(req.body.deviceSecret) },
      });
      if (!credential || credential.revokedAt) throw unauthorized('Unknown device');
      await prisma.deviceCredential.update({ where: { id: credential.id }, data: { lastUsedAt: new Date() } });
      return {
        userId: credential.userId,
        accessToken: app.jwt.sign({ sub: credential.userId }),
        tokenType: 'Bearer' as const,
      };
    },
  );
};
