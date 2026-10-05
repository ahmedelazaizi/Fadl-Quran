import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { Prisma } from '@prisma/client';
import Fastify, { type FastifyServerOptions } from 'fastify';
import {
  hasZodFastifySchemaValidationErrors,
  jsonSchemaTransform,
  serializerCompiler,
  validatorCompiler,
  type ZodTypeProvider,
} from 'fastify-type-provider-zod';
import { config } from './config.js';
import { HttpError } from './lib/errors.js';
import { prisma } from './lib/prisma.js';
import { athkarRoutes } from './modules/athkar/routes.js';
import { authPlugin } from './modules/auth/plugin.js';
import { authRoutes } from './modules/auth/routes.js';
import { hadithRoutes } from './modules/hadith/routes.js';
import { khatmaRoutes } from './modules/khatma/routes.js';
import { dashboardRoutes, statsRoutes } from './modules/me/dashboard.routes.js';
import { libraryRoutes } from './modules/me/library.routes.js';
import { profileRoutes } from './modules/me/profile.routes.js';
import { notificationRoutes } from './modules/notifications/routes.js';
import { prayerRoutes } from './modules/prayer/routes.js';
import { quranRoutes } from './modules/quran/routes.js';
import { ramadanRoutes } from './modules/ramadan/routes.js';
import { searchRoutes } from './modules/search/routes.js';
import { tasbeehRoutes } from './modules/tasbeeh/routes.js';

export const API_PREFIX = '/api/v1';

export async function buildApp(opts: FastifyServerOptions = {}) {
  const app = Fastify({ logger: config.NODE_ENV !== 'test', ...opts }).withTypeProvider<ZodTypeProvider>();
  app.setValidatorCompiler(validatorCompiler);
  app.setSerializerCompiler(serializerCompiler);

  await app.register(helmet, { contentSecurityPolicy: false });
  await app.register(cors, {
    origin: config.CORS_ORIGIN === '*' ? true : config.CORS_ORIGIN.split(',').map((o) => o.trim()),
  });
  await app.register(rateLimit, {
    max: 300,
    timeWindow: '1 minute',
    // The test suite creates many accounts from one address.
    allowList: () => config.NODE_ENV === 'test',
  });
  await app.register(swagger, {
    openapi: {
      info: { title: 'Fadl API', version: '1.0.0', description: 'Backend for the Fadl Quran, prayer and athkar app' },
      components: { securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } } },
    },
    transform: jsonSchemaTransform,
  });
  await app.register(swaggerUi, { routePrefix: '/docs' });
  await app.register(authPlugin);

  app.setErrorHandler((err: Error, req, reply) => {
    if (hasZodFastifySchemaValidationErrors(err)) {
      return reply.code(400).send({
        error: 'VALIDATION_ERROR',
        message: 'Request validation failed',
        details: err.validation.map((v) => ({ path: v.instancePath, message: v.message })),
      });
    }
    if (err instanceof HttpError) {
      return reply.code(err.statusCode).send({ error: err.code, message: err.message });
    }
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
      return reply.code(404).send({ error: 'NOT_FOUND', message: 'Resource not found' });
    }
    const status = (err as { statusCode?: number }).statusCode;
    if (status && status < 500) {
      return reply.code(status).send({ error: (err as { code?: string }).code ?? 'BAD_REQUEST', message: err.message });
    }
    req.log.error(err);
    return reply.code(500).send({ error: 'INTERNAL_ERROR', message: 'Something went wrong' });
  });

  app.get('/health', { schema: { hide: true } }, async () => {
    await prisma.$queryRaw`SELECT 1`;
    return { status: 'ok' };
  });

  await app.register(
    async (api) => {
      // Everything under /me requires a valid access token.
      api.addHook('onRequest', async (req, reply) => {
        if (req.routeOptions.url?.startsWith(`${API_PREFIX}/me`)) await app.authenticate(req, reply);
      });
      await api.register(authRoutes);
      await api.register(prayerRoutes);
      await api.register(ramadanRoutes);
      await api.register(quranRoutes);
      await api.register(athkarRoutes);
      await api.register(hadithRoutes);
      await api.register(searchRoutes);
      await api.register(statsRoutes);
      await api.register(profileRoutes);
      await api.register(dashboardRoutes);
      await api.register(libraryRoutes);
      await api.register(khatmaRoutes);
      await api.register(tasbeehRoutes);
      await api.register(notificationRoutes);
    },
    { prefix: API_PREFIX },
  );

  return app;
}
