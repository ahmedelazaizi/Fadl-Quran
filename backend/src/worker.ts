/**
 * Notification worker: every NOTIFY_INTERVAL_SECONDS it sends due adhan and
 * reminder pushes. Safe to run several instances — NotificationLog's unique
 * (userId, key) guarantees each notification is sent at most once.
 */
import { config } from './config.js';
import { prisma } from './lib/prisma.js';
import { dispatchDue, pruneLogs } from './modules/notifications/dispatcher.js';
import { createFcmSender, createLogSender, type PushSender } from './modules/notifications/sender.js';

const sender: PushSender = config.FIREBASE_SERVICE_ACCOUNT_PATH
  ? await createFcmSender(config.FIREBASE_SERVICE_ACCOUNT_PATH)
  : createLogSender();

console.log(`[worker] started with "${sender.name}" sender, every ${config.NOTIFY_INTERVAL_SECONDS}s`);

let running = false;
let stopping = false;
let lastPrune = 0;

async function tick() {
  if (running || stopping) return;
  running = true;
  try {
    const stats = await dispatchDue(sender, new Date(), Math.max(5 * 60_000, config.NOTIFY_INTERVAL_SECONDS * 3000));
    if (stats.due > 0) console.log('[worker] tick', stats);
    if (Date.now() - lastPrune > 86400_000) {
      lastPrune = Date.now();
      const { count } = await pruneLogs(30);
      if (count) console.log(`[worker] pruned ${count} old notification logs`);
    }
  } catch (err) {
    console.error('[worker] tick failed', err);
  } finally {
    running = false;
  }
}

const timer = setInterval(tick, config.NOTIFY_INTERVAL_SECONDS * 1000);
await tick();

const shutdown = async () => {
  stopping = true;
  clearInterval(timer);
  await prisma.$disconnect();
  process.exit(0);
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
