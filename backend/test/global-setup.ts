// @ts-expect-error -- plain ESM helper without type declarations
import { prepareTestDb } from '../scripts/prepare-test-db.mjs';

export default function setup() {
  if (process.env.SKIP_DB_PREPARE !== '1') prepareTestDb();
}
