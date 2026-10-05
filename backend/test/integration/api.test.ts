import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { buildApp } from '../../src/app.js';
import { normalizeArabic } from '../../src/lib/arabic.js';
import { prisma } from '../../src/lib/prisma.js';
import { dispatchDue } from '../../src/modules/notifications/dispatcher.js';
import type { PushSender } from '../../src/modules/notifications/sender.js';

let app: FastifyInstance;
const API = '/api/v1';

async function call(method: 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE', url: string, opts: { token?: string; body?: unknown } = {}) {
  const res = await app.inject({
    method,
    url: API + url,
    headers: opts.token ? { authorization: `Bearer ${opts.token}` } : {},
    ...(opts.body !== undefined ? { payload: opts.body as object } : {}),
  });
  return { status: res.statusCode, body: res.body ? JSON.parse(res.body) : null };
}

async function guest() {
  const res = await call('POST', '/auth/anonymous', { body: { timezone: 'Asia/Riyadh' } });
  expect(res.status).toBe(201);
  return res.body as { accessToken: string; deviceSecret: string; userId: string };
}

async function guestWithLocation() {
  const g = await guest();
  const res = await call('PATCH', '/me/settings', {
    token: g.accessToken,
    body: { latitude: 24.7136, longitude: 46.6753, locationName: 'الرياض', dedicateeName: 'فضل سليم محمد صالح' },
  });
  expect(res.status).toBe(200);
  return g;
}

beforeAll(async () => {
  await prisma.user.deleteMany();
  await prisma.amenCounter.deleteMany();
  app = await buildApp({ logger: false });
  await app.ready();
});

afterAll(async () => {
  await app.close();
  await prisma.$disconnect();
});

describe('public content', () => {
  it('lists the 114 surahs', async () => {
    const res = await call('GET', '/quran/surahs');
    expect(res.body.surahs).toHaveLength(114);
    expect(res.body.surahs[1]).toMatchObject({ nameAr: 'البقرة', ayahCount: 286, revelationTypeAr: 'مدنية' });
  });

  it('returns a surah with tafsir and translation, without the basmala in ayah 1', async () => {
    const res = await call('GET', '/quran/surahs/2?from=1&to=2&tafsir=ar.muyassar&translation=en.sahih');
    expect(res.status).toBe(200);
    expect(res.body.showBasmala).toBe(true);
    expect(res.body.ayahs).toHaveLength(2);
    expect(res.body.ayahs[0].text).toBe('الٓمٓ');
    expect(res.body.ayahs[1].tafsir).toBeTruthy();
    expect(res.body.ayahs[1].translation).toContain('Book');
  });

  it('serves mushaf pages and juz', async () => {
    const page = await call('GET', '/quran/pages/604');
    expect(page.body.surahs.map((s: { id: number }) => s.id)).toEqual([112, 113, 114]);
    const juz = await call('GET', '/quran/juz/30');
    expect(juz.body.startPage).toBe(582);
    expect(juz.body.ayahs.at(-1).key).toBe('114:6');
  });

  it('rejects remote tafsirs on bulk endpoints and validates input', async () => {
    expect((await call('GET', '/quran/surahs/1?tafsir=ar.saddi')).status).toBe(400);
    expect((await call('GET', '/quran/surahs/115')).status).toBe(400);
    expect((await call('GET', '/quran/ayahs/2:999')).status).toBe(404);
  });

  it('builds an audio playlist', async () => {
    const res = await call('GET', '/quran/audio/surahs/1?reciter=ar.minshawi&bitrate=192');
    expect(res.body.bitrate).toBe(128);
    expect(res.body.surahUrl).toBeNull();
    expect(res.body.ayahs[0].url).toBe('https://cdn.islamic.network/quran/audio/128/ar.minshawi/1.mp3');
  });

  it('lists a teaching reciter and builds its seven-ayah Fatiha playlist', async () => {
    const reciters = await call('GET', '/quran/reciters');
    expect(reciters.status).toBe(200);
    const teacher = reciters.body.reciters.find((reciter: { style: string }) => reciter.style === 'معلم');
    expect(teacher).toBeDefined();
    expect(teacher.riwaya).toBe('حفص عن عاصم');

    const playlist = await call('GET', `/quran/audio/surahs/1?reciter=${teacher.id}`);
    expect(playlist.status).toBe(200);
    expect(playlist.body.reciter.style).toBe('معلم');
    expect(playlist.body.ayahs).toHaveLength(7);
    expect(playlist.body.ayahs[0].url).toBe(`https://cdn.islamic.network/quran/audio/${playlist.body.bitrate}/${teacher.id}/1.mp3`);
  });

  it('returns prayer times, qibla and the Ramadan imsakiya', async () => {
    const times = await call('GET', '/prayer/times?lat=24.7136&lng=46.6753&tz=Asia/Riyadh&date=2025-09-15');
    expect(times.body.prayers.find((p: { name: string }) => p.name === 'maghrib').local).toBe('17:57');
    expect(times.body.qibla.bearing).toBeGreaterThan(240);
    const bad = await call('GET', '/prayer/times?lat=200&lng=46');
    expect(bad.status).toBe(400);
    expect(bad.body.error).toBe('VALIDATION_ERROR');

    const r = await call('GET', '/ramadan/imsakiya?lat=24.7136&lng=46.6753&tz=Asia/Riyadh&hijriYear=1447&period=last');
    expect(r.body.startDate).toBe('2026-02-18');
    expect(r.body.days[0].ramadanDay).toBe(21);
    expect(r.body.days[0].note).toBe('بداية العشر الأواخر');
  });

  it('serves athkar and dua collections', async () => {
    const cats = await call('GET', '/athkar/categories?featured=true');
    expect(cats.body.categories[0].slug).toBe('morning');
    const morning = await call('GET', '/athkar/categories/morning');
    expect(morning.body.items.length).toBeGreaterThan(20);
    expect(morning.body.items[0]).toHaveProperty('virtue');

    const parents = await call('GET', '/duas/collections/parents');
    expect(parents.body.items[0]).toMatchObject({ kind: 'verse', reference: 'سورة الإسراء - آية 24' });
    const relief = await call('GET', '/duas/collections/relief');
    expect(relief.body.items.some((i: { kind: string }) => i.kind === 'dhikr')).toBe(true);
  });

  it('searches the Quran and athkar ignoring diacritics', async () => {
    const res = await call('GET', `/search?q=${encodeURIComponent('بالوالدين احسانا')}`);
    expect(res.body.verses.hits.map((h: { key: string }) => h.key)).toContain('17:23');
    const surah = await call('GET', `/search?q=${encodeURIComponent('سورة الكهف')}&type=quran`);
    expect(surah.body.surahs[0].id).toBe(18);
    const athkar = await call('GET', `/athkar/search?q=${encodeURIComponent('سيد الاستغفار')}`);
    expect(athkar.status).toBe(200);
  });

  it('answers topic questions with pinned verses (retrieval mode without an API key)', async () => {
    const res = await call('POST', '/assistant/ask', { body: { topic: 'parents' } });
    expect(res.body.mode).toBe('retrieval');
    expect(res.body.sources.verses[0].key).toBe('17:23');
    expect(res.body.sources.verses[0].tafsir).toBeTruthy();
  });

  it('serves a curated daily ayah', async () => {
    const a = await call('GET', '/quran/daily-ayah?date=2026-10-03');
    const b = await call('GET', '/quran/daily-ayah?date=2026-10-04');
    expect(a.body.ayah.key).not.toBe(b.body.ayah.key);
  });
});

describe('hadith', () => {
  it('lists the embedded collections and their chapters', async () => {
    const books = await call('GET', '/hadith/books');
    const slugs = books.body.books.map((b: { slug: string }) => b.slug);
    expect(slugs.slice(0, 2)).toEqual(['bukhari', 'muslim']);
    expect(slugs).toContain('riyad');
    expect(books.body.books[0].nameAr).toBe('صحيح البخاري');

    const bukhari = await call('GET', '/hadith/books/bukhari');
    expect(bukhari.body.chapters[0].nameAr).toContain('الوحى');
    const first = await call('GET', `/hadith/books/bukhari/hadiths?chapterId=${bukhari.body.chapters[0].id}&limit=1`);
    expect(normalizeArabic(first.body.hadiths[0].textAr)).toContain('انما الاعمال بالنيات');
    expect(first.body.hadiths[0]).toMatchObject({ grade: 'صحيح', number: 1 });
    expect(first.body.hadiths[0].links.dorar).toMatch(/^https:\/\/dorar\.net\/hadith\/search\?q=/);
  });

  it('searches hadith ignoring diacritics, authentic first, with grades for the Sunan', async () => {
    const res = await call('GET', `/hadith/search?q=${encodeURIComponent('إنما الأعمال بالنيات')}&limit=5`);
    expect(res.body.total).toBeGreaterThan(0);
    expect(res.body.results[0].grade).toMatch(/^صحيح/);
    const sunan = await call('GET', `/hadith/search?q=${encodeURIComponent('الطهور شطر الإيمان')}&book=tirmidhi`);
    expect(sunan.status).toBe(200);
    const graded = await call('GET', '/hadith/books/abudawud/hadiths?limit=50');
    expect(graded.body.hadiths.filter((h: { grade: string | null }) => h.grade).length).toBeGreaterThan(30);
  });

  it('is part of global search, the assistant and the daily card', async () => {
    const all = await call('GET', `/search?q=${encodeURIComponent('بر الوالدين')}&type=hadith`);
    expect(all.body.hadith.results.length).toBeGreaterThan(0);
    expect(all.body.verses.hits).toEqual([]);
    const ask = await call('POST', '/assistant/ask', { body: { topic: 'patience' } });
    expect(ask.body.sources.hadith.length).toBeGreaterThan(0);
    const daily = await call('GET', '/hadith/daily?date=2026-10-03');
    expect(daily.body.hadith.book.slug).toMatch(/nawawi40|riyad/);
  });
});

describe('auth', () => {
  it('requires a token for /me routes', async () => {
    expect((await call('GET', '/me')).status).toBe(401);
    expect((await call('GET', '/me', { token: 'garbage' })).status).toBe(401);
  });

  it('creates an anonymous identity with default settings (no sign-in)', async () => {
    const g = await guest();
    const me = await call('GET', '/me', { token: g.accessToken });
    expect(me.body.user).not.toHaveProperty('email');
    expect(me.body.settings.calcMethod).toBe('UmmAlQura');
    expect(me.body.notifications.adhan.fajr).toBe(true);
    expect((await call('POST', '/auth/login', { body: { email: 'a@b.c', password: 'x' } })).status).toBe(404);
  });

  it('exchanges the device secret for new access tokens, repeatedly', async () => {
    const g = await guest();
    for (let i = 0; i < 2; i++) {
      const res = await call('POST', '/auth/token', { body: { deviceSecret: g.deviceSecret } });
      expect(res.status).toBe(200);
      expect(res.body.userId).toBe(g.userId);
      expect((await call('GET', '/me', { token: res.body.accessToken })).status).toBe(200);
    }
    expect((await call('POST', '/auth/token', { body: { deviceSecret: 'x'.repeat(43) } })).status).toBe(401);
  });
});

describe('synced user data', () => {
  it('validates settings and returns the dashboard', async () => {
    const g = await guest();
    const bad = await call('PATCH', '/me/settings', { token: g.accessToken, body: { latitude: 24 } });
    expect(bad.status).toBe(400);
    expect((await call('PATCH', '/me/settings', { token: g.accessToken, body: { reciterId: 'nobody' } })).status).toBe(400);
    const ok = await call('PATCH', '/me/settings', { token: g.accessToken, body: { reciterId: 'ar.alafasy', tafsirSlug: 'ar.saddi' } });
    expect(ok.body).toMatchObject({ reciterId: 'ar.alafasy', tafsirSlug: 'ar.saddi' });
    const noLocation = await call('GET', '/me/prayer', { token: g.accessToken });
    expect(noLocation.status).toBe(400);

    const withLoc = await guestWithLocation();
    const dash = await call('GET', '/me/dashboard', { token: withLoc.accessToken });
    expect(dash.status).toBe(200);
    expect(dash.body.dedicateeName).toBe('فضل سليم محمد صالح');
    expect(dash.body.prayer.next.name).toBeTruthy();
    expect(dash.body.dailyAyah.ayah.tafsir).toBeTruthy();
    expect(dash.body.tasbeeh.dailyGoal).toBe(100);
  });

  it('runs a khatma plan end to end', async () => {
    const g = await guestWithLocation();
    const presets = await call('GET', '/khatma/presets');
    expect(presets.body.presets[0]).toMatchObject({ key: '30-days', pagesPerDay: 21 });

    const created = await call('POST', '/me/khatmas', { token: g.accessToken, body: { preset: '30-days', reminderTime: '20:30', dedicated: true } });
    expect(created.status).toBe(201);
    expect(created.body.today.target).toBe(21);
    const id = created.body.id;

    const p1 = await call('POST', `/me/khatmas/${id}/progress`, { token: g.accessToken, body: { toPage: 20 } });
    expect(p1.body.recordedPages).toBe(20);
    expect(p1.body.plan.today).toMatchObject({ read: 20, remaining: 1 });
    expect(p1.body.plan.position.page).toBe(21);
    expect((await call('POST', `/me/khatmas/${id}/progress`, { token: g.accessToken, body: { toPage: 10 } })).status).toBe(400);

    const done = await call('POST', `/me/khatmas/${id}/progress`, { token: g.accessToken, body: { pages: 1000 } });
    expect(done.body).toMatchObject({ recordedPages: 584, completed: true });
    expect(done.body.plan.status).toBe('COMPLETED');

    const stats = await call('GET', '/me/dedications/stats', { token: g.accessToken });
    expect(stats.body.byType.KHATMA.amount).toBe(1);

    const logs = await call('GET', `/me/khatmas/${id}/logs`, { token: g.accessToken });
    expect(logs.body.days[0].pages).toBe(604);

    const other = await guest();
    expect((await call('GET', `/me/khatmas/${id}`, { token: other.accessToken })).status).toBe(404);
  });

  it('syncs tasbeeh idempotently', async () => {
    const g = await guestWithLocation();
    const summary = await call('GET', '/me/tasbeeh', { token: g.accessToken });
    const subhan = summary.body.dhikrs[0];
    expect(subhan.target).toBe(33);

    const entries = [
      { dhikrId: subhan.id, count: 33, clientEventId: `evt-${g.userId}-1` },
      { dhikrId: subhan.id, count: 10, clientEventId: `evt-${g.userId}-2` },
    ];
    const first = await call('POST', '/me/tasbeeh/entries', { token: g.accessToken, body: { entries } });
    expect(first.body).toMatchObject({ accepted: 2, ignored: 0 });
    const again = await call('POST', '/me/tasbeeh/entries', { token: g.accessToken, body: { entries } });
    expect(again.body).toMatchObject({ accepted: 0, ignored: 2 });
    expect(again.body.summary.todayTotal).toBe(43);
    expect(again.body.summary.dhikrs[0]).toMatchObject({ todayCount: 43, rounds: 1, remainingInRound: 23 });
    expect(again.body.summary.streakDays).toBe(1);

    const custom = await call('POST', '/me/tasbeeh/dhikrs', { token: g.accessToken, body: { text: 'لا حول ولا قوة إلا بالله', target: 100 } });
    expect(custom.status).toBe(201);
    const other = await guest();
    const foreign = await call('POST', '/me/tasbeeh/entries', { token: other.accessToken, body: { entries: [{ dhikrId: custom.body.id, count: 1 }] } });
    expect(foreign.status).toBe(400);
  });

  it('stores bookmarks, last read position, athkar progress and checklist', async () => {
    const g = await guestWithLocation();
    const bm = await call('POST', '/me/bookmarks', { token: g.accessToken, body: { ayahKey: '2:255', note: 'آية الكرسي' } });
    expect(bm.status).toBe(201);
    await call('POST', '/me/bookmarks', { token: g.accessToken, body: { ayahKey: '2:255' } });
    const list = await call('GET', '/me/bookmarks', { token: g.accessToken });
    expect(list.body.bookmarks).toHaveLength(1);
    expect(list.body.bookmarks[0].note).toBe('آية الكرسي');

    await call('PUT', '/me/last-read', { token: g.accessToken, body: { ayahKey: '17:23' } });
    await call('PUT', '/me/last-read', { token: g.accessToken, body: { ayahKey: '17:24' } });
    const last = await call('GET', '/me/last-read', { token: g.accessToken });
    expect(last.body.lastRead.ayah.key).toBe('17:24');

    const morning = await call('GET', '/athkar/categories/morning');
    const first = morning.body.items[0];
    await call('PUT', '/me/athkar/progress', { token: g.accessToken, body: { dhikrId: first.id, count: first.repeat } });
    const progress = await call('GET', '/me/athkar/progress', { token: g.accessToken });
    const cat = progress.body.categories.find((c: { slug: string }) => c.slug === 'morning');
    expect(cat).toMatchObject({ completed: 1, status: 'PARTIAL' });

    await call('PUT', '/me/checklist', { token: g.accessToken, body: { key: 'suhoor', done: true } });
    const checklist = await call('GET', '/me/checklist', { token: g.accessToken });
    expect(checklist.body.done).toEqual(['suhoor']);
  });

  it('counts amen once per user per day and dedications globally', async () => {
    const a = await guestWithLocation();
    const b = await guestWithLocation();
    const key = 'verse:17:24';
    expect((await call('POST', '/duas/amen', { token: a.accessToken, body: { targetKey: key } })).body).toMatchObject({ counted: true, amenCount: 1 });
    expect((await call('POST', '/duas/amen', { token: a.accessToken, body: { targetKey: key } })).body).toMatchObject({ counted: false, amenCount: 1 });
    expect((await call('POST', '/duas/amen', { token: b.accessToken, body: { targetKey: key } })).body.amenCount).toBe(2);
    expect((await call('POST', '/duas/amen', { token: b.accessToken, body: { targetKey: 'verse:1:1' } })).status).toBe(400);

    const parents = await call('GET', '/duas/collections/parents');
    expect(parents.body.items[0].amenCount).toBe(2);

    const before = (await call('GET', '/stats/dedications')).body.total;
    const ded = await call('POST', '/me/dedications', { token: a.accessToken, body: { type: 'TASBEEH', amount: 100 } });
    expect(ded.body.dedicateeName).toBe('فضل سليم محمد صالح');
    expect((await call('GET', '/stats/dedications')).body.total).toBe(before + 1);
  });

  it('deletes the account with all its data', async () => {
    const g = await guestWithLocation();
    expect((await call('DELETE', '/me', { token: g.accessToken })).status).toBe(204);
    expect(await prisma.user.findUnique({ where: { id: g.userId } })).toBeNull();
  });
});

describe('notifications', () => {
  it('registers devices, previews upcoming pushes and dispatches each once', async () => {
    const g = await guestWithLocation();
    const token = `fcm-token-${g.userId}`;
    expect((await call('POST', '/me/devices', { token: g.accessToken, body: { fcmToken: token, platform: 'android' } })).status).toBe(200);
    await call('PATCH', '/me/notifications', { token: g.accessToken, body: { adhan: { sunrise: true }, qiyamEnabled: true } });
    const prefs = await call('GET', '/me/notifications', { token: g.accessToken });
    expect(prefs.body.adhan).toMatchObject({ fajr: true, sunrise: true });

    const upcoming = await call('GET', '/me/notifications/upcoming?hours=24', { token: g.accessToken });
    expect(upcoming.body.notifications.filter((n: { type: string }) => n.type === 'adhan').length).toBeGreaterThanOrEqual(5);

    // Pick the next fajr adhan and simulate the worker running just after it.
    const fajr = upcoming.body.notifications.find((n: { key: string }) => n.key.startsWith('adhan:fajr'));
    const sent: string[] = [];
    const sender: PushSender = {
      name: 'test',
      async send(tokens, n) {
        if (tokens.includes(token)) sent.push(n.key);
        return { successCount: tokens.length, invalidTokens: [] };
      },
    };
    const at = new Date(new Date(fajr.fireAt).getTime() + 30_000);
    await dispatchDue(sender, at);
    await dispatchDue(sender, at); // second tick must not resend
    expect(sent.filter((k) => k === fajr.key)).toHaveLength(1);

    const log = await prisma.notificationLog.findUnique({ where: { userId_key: { userId: g.userId, key: fajr.key } } });
    expect(log?.status).toBe('SENT');
  });

  it('removes tokens that FCM reports as invalid', async () => {
    const g = await guestWithLocation();
    const token = `dead-token-${g.userId}`;
    await call('POST', '/me/devices', { token: g.accessToken, body: { fcmToken: token, platform: 'ios' } });
    const upcoming = await call('GET', '/me/notifications/upcoming?hours=24', { token: g.accessToken });
    const first = upcoming.body.notifications[0];
    const sender: PushSender = {
      name: 'test',
      async send(tokens) {
        return { successCount: 0, invalidTokens: tokens.filter((t) => t === token), error: 'not registered' };
      },
    };
    await dispatchDue(sender, new Date(new Date(first.fireAt).getTime() + 1000));
    expect(await prisma.device.findUnique({ where: { fcmToken: token } })).toBeNull();
  });
});
