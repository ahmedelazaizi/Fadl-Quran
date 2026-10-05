import { readFileSync } from 'node:fs';
import type { ScheduledNotification } from './schedule.js';

export interface SendResult {
  successCount: number;
  /** Tokens FCM reported as unregistered/invalid; they should be deleted. */
  invalidTokens: string[];
  error?: string;
}

export interface PushSender {
  readonly name: string;
  send(tokens: string[], n: ScheduledNotification, opts: { adhanSound: string }): Promise<SendResult>;
}

const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/** Firebase Cloud Messaging sender (requires a service-account JSON). */
export async function createFcmSender(serviceAccountPath: string): Promise<PushSender> {
  const { initializeApp, cert, getApps } = await import('firebase-admin/app');
  const { getMessaging } = await import('firebase-admin/messaging');
  const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
  const app = getApps()[0] ?? initializeApp({ credential: cert(serviceAccount) });
  const messaging = getMessaging(app);

  return {
    name: 'fcm',
    async send(tokens, n, { adhanSound }) {
      const isAdhan = n.type === 'adhan' && n.prayer !== 'sunrise';
      const res = await messaging.sendEachForMulticast({
        tokens,
        notification: { title: n.title, body: n.body },
        data: { type: n.type, key: n.key, link: n.link, prayer: n.prayer ?? '' },
        android: {
          priority: 'high',
          // Stale prayer alerts are useless: let FCM drop them after 10 minutes.
          ttl: isAdhan || n.type === 'pre_adhan' ? 10 * 60_000 : 6 * 3600_000,
          notification: {
            channelId: isAdhan ? `adhan_${adhanSound}` : 'reminders',
            sound: isAdhan ? adhanSound : 'default',
          },
        },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: { aps: { sound: isAdhan ? `${adhanSound}.caf` : 'default' } },
        },
      });
      const invalidTokens = res.responses.flatMap((r, i) =>
        !r.success && r.error && INVALID_TOKEN_CODES.has(r.error.code) ? [tokens[i]!] : [],
      );
      const firstError = res.responses.find((r) => !r.success)?.error?.message;
      return { successCount: res.successCount, invalidTokens, error: firstError };
    },
  };
}

/** Development sender: prints instead of pushing. */
export function createLogSender(log: (msg: string) => void = console.log): PushSender {
  return {
    name: 'log',
    async send(tokens, n) {
      log(`[push:log] ${n.fireAt.toISOString()} ${n.key} → ${tokens.length} device(s): ${n.title} — ${n.body}`);
      return { successCount: tokens.length, invalidTokens: [] };
    },
  };
}
