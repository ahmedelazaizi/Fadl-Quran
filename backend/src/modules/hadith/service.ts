import { Prisma, type Hadith, type HadithBook } from '@prisma/client';
import { normalizeArabic, searchTerms } from '../../lib/arabic.js';
import { notFound } from '../../lib/errors.js';
import { prisma } from '../../lib/prisma.js';

const PROPHET = 'صلي الله عليه وسلم';

/**
 * A short excerpt of the Prophet's words (the matn), used to build
 * verification links on hadith platforms. Falls back to the end of the text.
 */
export function matnExcerpt(textAr: string, words = 10): string {
  const normalized = normalizeArabic(textAr);
  const at = normalized.indexOf(PROPHET);
  const tail = at >= 0 ? normalized.slice(at + PROPHET.length) : normalized;
  const tokens = tail
    .split(' ')
    .filter((w) => w && !['قال', 'يقول', 'انه', 'ان'].includes(w));
  const picked = at >= 0 ? tokens.slice(0, words) : tokens.slice(-words);
  return picked.join(' ');
}

/** Links to external hadith platforms where the text and grade can be checked. */
export function verificationLinks(textAr: string) {
  const q = encodeURIComponent(matnExcerpt(textAr));
  return {
    dorar: `https://dorar.net/hadith/search?q=${q}`,
    sunnah: `https://sunnah.com/search?q=${q}`,
  };
}

export function serializeHadith(h: Hadith & { book?: Pick<HadithBook, 'slug' | 'nameAr'>; chapter?: { nameAr: string } | null }) {
  return {
    id: h.id,
    number: h.number,
    book: h.book ? { slug: h.book.slug, nameAr: h.book.nameAr } : undefined,
    chapterAr: h.chapter?.nameAr ?? null,
    textAr: h.textAr,
    textEn: h.textEn,
    narratorEn: h.narratorEn,
    grade: h.grade,
    gradeSource: h.gradeSource,
    reference: h.book ? `${h.book.nameAr} (${h.number})` : null,
    links: verificationLinks(h.textAr),
  };
}

const withBook = { book: { select: { slug: true, nameAr: true } }, chapter: { select: { nameAr: true } } } as const;

export async function getHadith(id: number) {
  const h = await prisma.hadith.findUnique({ where: { id }, include: withBook });
  if (!h) throw notFound('Hadith');
  return serializeHadith(h);
}

export async function getBook(slug: string) {
  const book = await prisma.hadithBook.findUnique({ where: { slug } });
  if (!book) throw notFound(`Hadith book "${slug}"`);
  return book;
}

/**
 * Diacritics-insensitive search. All terms (≥3 letters) must appear; results
 * from the two Sahihs and graded books come first.
 */
export async function searchHadith(query: string, { limit = 20, offset = 0, book }: { limit?: number; offset?: number; book?: string } = {}) {
  const all = searchTerms(query);
  const terms = all.filter((t) => t.length >= 3).length ? all.filter((t) => t.length >= 3) : all;
  if (terms.length === 0) return { total: 0, results: [] };
  const conditions = terms.map((t) => Prisma.sql`h."textSearch" LIKE ${'%' + t + '%'}`);
  if (book) conditions.push(Prisma.sql`b.slug = ${book}`);
  const where = Prisma.join(conditions, ' AND ');

  const [countRow] = await prisma.$queryRaw<{ total: bigint }[]>`
    SELECT count(*)::bigint AS total FROM "Hadith" h JOIN "HadithBook" b ON b.id = h."bookId" WHERE ${where}`;
  const rows = await prisma.$queryRaw<{ id: number }[]>`
    SELECT h.id FROM "Hadith" h JOIN "HadithBook" b ON b.id = h."bookId"
    WHERE ${where}
    ORDER BY (CASE WHEN h.grade LIKE 'صحيح%' THEN 0 WHEN h.grade LIKE 'حسن%' THEN 1 WHEN h.grade IS NULL THEN 2 ELSE 3 END),
             b."sortOrder", length(h."textAr"), h.number
    LIMIT ${limit} OFFSET ${offset}`;
  const hadiths = await prisma.hadith.findMany({ where: { id: { in: rows.map((r) => r.id) } }, include: withBook });
  const order = new Map(rows.map((r, i) => [r.id, i]));
  return {
    total: Number(countRow?.total ?? 0),
    results: hadiths.sort((a, b) => order.get(a.id)! - order.get(b.id)!).map(serializeHadith),
  };
}

let dailyPool: number[] | null = null;

/** "حديث اليوم": rotates through An-Nawawi's Forty and Riyad as-Salihin. */
export async function dailyHadithId(dateKey: string): Promise<number | null> {
  if (!dailyPool) {
    const rows = await prisma.hadith.findMany({
      where: { book: { slug: { in: ['nawawi40', 'riyad'] } } },
      select: { id: true, textAr: true },
      orderBy: [{ bookId: 'asc' }, { number: 'asc' }],
    });
    // Short hadiths read better on a card.
    dailyPool = rows.filter((r) => r.textAr.length <= 600).map((r) => r.id);
  }
  if (dailyPool.length === 0) return null;
  const dayNumber = Math.floor(Date.parse(`${dateKey}T00:00:00Z`) / 86400000);
  return dailyPool[dayNumber % dailyPool.length]!;
}
