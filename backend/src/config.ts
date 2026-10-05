import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().default(3000),
  HOST: z.string().default('0.0.0.0'),
  CORS_ORIGIN: z.string().default('*'),
  DATABASE_URL: z.string().min(1),
  JWT_SECRET: z.string().min(16, 'JWT_SECRET must be at least 16 characters'),
  ACCESS_TOKEN_TTL: z.string().default('15m'),
  QURAN_COM_API: z.string().url().default('https://api.quran.com/api/v4'),
  AUDIO_CDN: z.string().url().default('https://cdn.islamic.network/quran'),
  FIREBASE_SERVICE_ACCOUNT_PATH: z.string().optional().default(''),
  NOTIFY_INTERVAL_SECONDS: z.coerce.number().int().positive().default(60),
  ANTHROPIC_API_KEY: z.string().optional().default(''),
  ANTHROPIC_MODEL: z.string().default('claude-sonnet-4-5'),
});

export type Config = z.infer<typeof schema>;

export const config: Config = schema.parse(process.env);
