// Migrates and seeds the test database (TEST_DATABASE_URL or the fadl_test default).
// Seeding reuses data/cache, so after the first `npm run seed` it works offline.
import { execSync } from 'node:child_process';

export const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL ?? 'postgresql://fadl:fadl@localhost:5433/fadl_test?schema=public';

export function prepareTestDb() {
  const env = { ...process.env, DATABASE_URL: TEST_DATABASE_URL, PRISMA_HIDE_UPDATE_MESSAGE: '1' };
  execSync('npx prisma migrate deploy', { stdio: 'inherit', env });
  execSync('npx tsx scripts/seed.ts', { stdio: 'inherit', env });
}

if (process.argv[1]?.endsWith('prepare-test-db.mjs')) {
  prepareTestDb();
}
