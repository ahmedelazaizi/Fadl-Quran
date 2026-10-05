import { Prisma } from '@prisma/client';
import { normalizeArabic } from '../../lib/arabic.js';
import { prisma } from '../../lib/prisma.js';
import { listSurahs, serializeSurah } from '../quran/service.js';

export interface VerseHit {
  key: string;
  surahId: number;
  surahNameAr: string;
  number: number;
  text: string;
  tafsir: string | null;
  page: number;
  score: number;
}

/**
 * Ranked substring search over normalized ayah text. Every term contributes
 * its length to the score, so specific words outrank short particles.
 * `mode = 'any'` is used for topic keyword lists (synonyms).
 */
export async function searchVerses(
  terms: string[],
  {
    limit = 20,
    offset = 0,
    mode = 'auto' as 'auto' | 'any',
    tafsir = 'ar.muyassar',
    /** Curated ayah keys always included and ranked first. */
    pinned = [] as readonly string[],
  } = {},
): Promise<{ total: number; hits: VerseHit[] }> {
  if (terms.length === 0 && pinned.length === 0) return { total: 0, hits: [] };
  const strong = terms.filter((t) => t.length >= 3);
  const filterTerms = mode === 'any' || strong.length === 0 ? terms : strong;
  const like = (t: string) => Prisma.sql`a."textSearch" LIKE ${'%' + t + '%'}`;
  const conditions = filterTerms.length
    ? [Prisma.sql`(${Prisma.join(filterTerms.map(like), mode === 'any' ? ' OR ' : ' AND ')})`]
    : [];
  if (pinned.length) conditions.push(Prisma.sql`a."key" IN (${Prisma.join([...pinned])})`);
  const where = Prisma.join(conditions, ' OR ');
  const scoreParts = terms.map(
    (t) => Prisma.sql`(CASE WHEN a."textSearch" LIKE ${'%' + t + '%'} THEN ${t.length} ELSE 0 END)`,
  );
  if (pinned.length) {
    // Pinned ayahs come first, in their curated order.
    const whens = pinned.map((k, i) => Prisma.sql`WHEN ${k} THEN ${100000 - i * 1000}`);
    scoreParts.push(Prisma.sql`(CASE a."key" ${Prisma.join(whens, ' ')} ELSE 0 END)`);
  }
  const score = Prisma.join(scoreParts, ' + ');

  const [countRow] = await prisma.$queryRaw<{ total: bigint }[]>`
    SELECT count(*)::bigint AS total FROM "Ayah" a WHERE ${where}`;
  const rows = await prisma.$queryRaw<{ id: number; score: number }[]>`
    SELECT a.id, (${score})::int AS score FROM "Ayah" a
    WHERE ${where}
    ORDER BY score DESC, a.id ASC
    LIMIT ${limit} OFFSET ${offset}`;
  if (rows.length === 0) return { total: Number(countRow?.total ?? 0), hits: [] };

  const ids = rows.map((r) => r.id);
  const [ayahs, tafsirs, surahs] = await Promise.all([
    prisma.ayah.findMany({ where: { id: { in: ids } } }),
    prisma.ayahText.findMany({ where: { editionSlug: tafsir, ayahId: { in: ids } } }),
    listSurahs(),
  ]);
  const byId = new Map(ayahs.map((a) => [a.id, a]));
  const tafsirById = new Map(tafsirs.map((t) => [t.ayahId, t.text]));
  return {
    total: Number(countRow?.total ?? 0),
    hits: rows.map((r) => {
      const a = byId.get(r.id)!;
      return {
        key: a.key,
        surahId: a.surahId,
        surahNameAr: surahs[a.surahId - 1]!.nameAr,
        number: a.number,
        text: a.textUthmani,
        tafsir: tafsirById.get(a.id) ?? null,
        page: a.page,
        score: r.score,
      };
    }),
  };
}

export async function searchSurahs(query: string) {
  const q = normalizeArabic(query).replace(/^سوره\s+/, '');
  const qLatin = query.trim().toLowerCase();
  if (!q && !qLatin) return [];
  return (await listSurahs())
    .filter(
      (s) =>
        (q && normalizeArabic(s.nameAr).includes(q)) ||
        s.nameTranslit.toLowerCase().includes(qLatin) ||
        s.nameEn.toLowerCase().includes(qLatin) ||
        String(s.id) === query.trim(),
    )
    .slice(0, 10)
    .map(serializeSurah);
}

/** Topic chips on the assistant screen, each backed by a list of synonyms. */
export const TOPICS = [
  { slug: 'parents', nameAr: 'بر الوالدين', hadithQuery: 'الوالدين', keywords: ['والدين', 'والديه', 'لوالديك', 'والدي', 'والدتي', 'بوالدتي'] },
  { slug: 'patience', nameAr: 'الصبر والاحتساب', hadithQuery: 'الصبر', keywords: ['صبر', 'صابر', 'اصبر'] },
  { slug: 'provision', nameAr: 'الرزق والبركة', hadithQuery: 'الرزق', keywords: ['رزق', 'الرزاق', 'بركات', 'مبارك'] },
  { slug: 'healing', nameAr: 'الشفاء من المرض', hadithQuery: 'الشفاء', keywords: ['شفاء', 'يشفين', 'مرضت', 'الضر'] },
  { slug: 'night-prayer', nameAr: 'قيام الليل والوتر', hadithQuery: 'قيام الليل', keywords: ['تهجد', 'قم الليل', 'ناشيه الليل', 'بالاسحار', 'يبيتون'] },
  { slug: 'repentance', nameAr: 'التوبة والرحمة', hadithQuery: 'التوبة', keywords: ['توبوا', 'التواب', 'يتوب', 'استغفروا', 'تقنطوا'] },
] as const;

export function topicTerms(slug: string): string[] | null {
  const topic = TOPICS.find((t) => t.slug === slug);
  return topic ? topic.keywords.map((k) => normalizeArabic(k)) : null;
}
