import type { Ayah, Surah } from '@prisma/client';
import { config } from '../../config.js';
import { badRequest, notFound } from '../../lib/errors.js';
import { prisma } from '../../lib/prisma.js';
import { DAILY_AYAH_POOL } from './curated.js';

export const TOTAL_PAGES = 604;
export const TOTAL_AYAHS = 6236;

export const REVELATION_AR = { MECCAN: 'مكية', MEDINAN: 'مدنية' } as const;

let surahCache: Surah[] | null = null;

export async function listSurahs(): Promise<Surah[]> {
  surahCache ??= await prisma.surah.findMany({ orderBy: { id: 'asc' } });
  return surahCache;
}

export async function getSurahMeta(id: number): Promise<Surah> {
  const surah = (await listSurahs())[id - 1];
  if (!surah) throw notFound(`Surah ${id}`);
  return surah;
}

export function serializeSurah(s: Surah) {
  return {
    id: s.id,
    nameAr: s.nameAr,
    nameEn: s.nameEn,
    nameTranslit: s.nameTranslit,
    revelationType: s.revelationType,
    revelationTypeAr: REVELATION_AR[s.revelationType],
    ayahCount: s.ayahCount,
    startPage: s.startPage,
  };
}

export function hizbOf(hizbQuarter: number) {
  return { hizb: Math.ceil(hizbQuarter / 4), quarter: ((hizbQuarter - 1) % 4) + 1, hizbQuarter };
}

export interface AyahExtras {
  tafsir?: string;
  translation?: string;
}

/** Validates that the requested editions exist and are stored locally (bulk endpoints). */
export async function assertLocalEditions(slugs: (string | undefined)[]) {
  for (const slug of slugs) {
    if (!slug) continue;
    const edition = await prisma.textEdition.findUnique({ where: { slug } });
    if (!edition) throw notFound(`Edition "${slug}"`);
    if (edition.source !== 'LOCAL') {
      throw badRequest(
        `Edition "${slug}" is fetched on demand; request it per ayah via /quran/ayahs/{key}/tafsir`,
      );
    }
  }
}

/** Loads ayahs with optional tafsir / translation texts in one query each. */
export async function loadAyahs(where: { id?: { gte: number; lte: number }; page?: number; juz?: number }, extras: AyahExtras) {
  await assertLocalEditions([extras.tafsir, extras.translation]);
  const ayahs = await prisma.ayah.findMany({ where, orderBy: { id: 'asc' } });
  const editions = [extras.tafsir, extras.translation].filter((s): s is string => Boolean(s));
  const texts = editions.length
    ? await prisma.ayahText.findMany({
        where: { editionSlug: { in: editions }, ayahId: { in: ayahs.map((a) => a.id) } },
      })
    : [];
  const byKey = new Map(texts.map((t) => [`${t.editionSlug}:${t.ayahId}`, t.text]));
  return ayahs.map((a) => ({
    ...serializeAyah(a),
    tafsir: extras.tafsir ? (byKey.get(`${extras.tafsir}:${a.id}`) ?? null) : undefined,
    translation: extras.translation ? (byKey.get(`${extras.translation}:${a.id}`) ?? null) : undefined,
  }));
}

export function serializeAyah(a: Ayah) {
  return {
    id: a.id,
    key: a.key,
    surahId: a.surahId,
    number: a.number,
    text: a.textUthmani,
    textSimple: a.textSimple,
    juz: a.juz,
    ...hizbOf(a.hizbQuarter),
    page: a.page,
    sajda: a.sajda,
  };
}

export async function findAyahByKey(key: string): Promise<Ayah> {
  const ayah = await prisma.ayah.findUnique({ where: { key } });
  if (!ayah) throw notFound(`Ayah ${key}`);
  return ayah;
}

// ───────────────────────────── Tafsir ─────────────────────────────

function htmlToText(html: string): string {
  return html
    .replace(/<\/(p|div|h\d)>/gi, '\n')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

type FetchFn = typeof fetch;

/**
 * Returns the tafsir of one ayah. Local editions are read from the database;
 * Quran.com editions are fetched once and cached in AyahText.
 */
export async function getTafsir(key: string, editionSlug: string, fetchFn: FetchFn = fetch) {
  const [ayah, edition] = await Promise.all([
    findAyahByKey(key),
    prisma.textEdition.findUnique({ where: { slug: editionSlug } }),
  ]);
  if (!edition || edition.type !== 'TAFSIR') throw notFound(`Tafsir "${editionSlug}"`);

  const cached = await prisma.ayahText.findUnique({
    where: { editionSlug_ayahId: { editionSlug, ayahId: ayah.id } },
  });
  const base = { ayahKey: key, edition: { slug: edition.slug, nameAr: edition.nameAr, nameEn: edition.nameEn } };
  if (cached) return { ...base, text: cached.text, source: edition.source };
  if (edition.source === 'LOCAL' || !edition.externalId) return { ...base, text: null, source: edition.source };

  const res = await fetchFn(`${config.QURAN_COM_API}/tafsirs/${edition.externalId}/by_ayah/${key}`);
  if (!res.ok) throw new Error(`Quran.com tafsir request failed with HTTP ${res.status}`);
  const body = (await res.json()) as { tafsir?: { text?: string; verses?: Record<string, unknown> } };
  const text = htmlToText(body.tafsir?.text ?? '');
  if (text) {
    await prisma.ayahText.upsert({
      where: { editionSlug_ayahId: { editionSlug, ayahId: ayah.id } },
      create: { editionSlug, ayahId: ayah.id, text },
      update: { text, fetchedAt: new Date() },
    });
  }
  return {
    ...base,
    text: text || null,
    source: edition.source,
    /** Some tafsirs explain a group of ayahs together. */
    coversAyahs: Object.keys(body.tafsir?.verses ?? {}),
  };
}

// ───────────────────────────── Audio ─────────────────────────────

export async function getReciter(id: string) {
  const reciter = await prisma.reciter.findUnique({ where: { id } });
  if (!reciter) throw notFound(`Reciter "${id}"`);
  return reciter;
}

/** Highest available bitrate that does not exceed the requested one. */
export function pickBitrate(available: number[], requested?: number): number {
  const sorted = [...available].sort((a, b) => b - a);
  if (!requested) return sorted[0]!;
  return sorted.find((b) => b <= requested) ?? sorted[sorted.length - 1]!;
}

export function verseAudioUrl(reciterId: string, bitrate: number, globalAyah: number) {
  return `${config.AUDIO_CDN}/audio/${bitrate}/${reciterId}/${globalAyah}.mp3`;
}

export function surahAudioUrl(reciterId: string, bitrate: number, surah: number) {
  return `${config.AUDIO_CDN}/audio-surah/${bitrate}/${reciterId}/${surah}.mp3`;
}

// ─────────────────────────── Daily ayah ───────────────────────────

let dailyCandidates: number[] | null = null;

/**
 * "Ayah of the day": rotates through a curated pool, one per calendar day,
 * so everyone sees the same ayah on a given date.
 */
export async function dailyAyahId(dateKey: string): Promise<number> {
  if (!dailyCandidates) {
    const rows = await prisma.ayah.findMany({ where: { key: { in: DAILY_AYAH_POOL } }, select: { id: true, key: true } });
    const byKey = new Map(rows.map((r) => [r.key, r.id]));
    dailyCandidates = DAILY_AYAH_POOL.flatMap((k) => byKey.get(k) ?? []);
  }
  const dayNumber = Math.floor(Date.parse(`${dateKey}T00:00:00Z`) / 86400000);
  return dailyCandidates[dayNumber % dailyCandidates.length]!;
}
