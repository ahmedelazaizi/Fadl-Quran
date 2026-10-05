import { Prisma, type Dhikr } from '@prisma/client';
import { searchTerms } from '../../lib/arabic.js';
import { notFound } from '../../lib/errors.js';
import { prisma } from '../../lib/prisma.js';
import { getSurahMeta } from '../quran/service.js';

export function serializeDhikr(d: Dhikr) {
  return {
    id: d.id,
    categoryId: d.categoryId,
    text: d.text,
    virtue: d.virtue,
    repeat: d.repeat,
    reference: d.reference,
    amenKey: `dhikr:${d.id}`,
  };
}

/** Resolves "17:24" or "14:40-41" into display text with its reference. */
export async function resolveVerseRange(range: string) {
  const m = /^(\d+):(\d+)(?:-(\d+))?$/.exec(range);
  if (!m) throw notFound(`Verse range ${range}`);
  const surahId = Number(m[1]);
  const from = Number(m[2]);
  const to = Number(m[3] ?? m[2]);
  const [surah, ayahs] = await Promise.all([
    getSurahMeta(surahId),
    prisma.ayah.findMany({ where: { surahId, number: { gte: from, lte: to } }, orderBy: { number: 'asc' } }),
  ]);
  const numbers = from === to ? `آية ${from}` : `الآيات ${from}-${to}`;
  return {
    verseRange: range,
    text: ayahs.map((a) => a.textUthmani).join(' ۝ '),
    reference: `سورة ${surah.nameAr} - ${numbers}`,
    amenKey: `verse:${range}`,
  };
}

export async function getCollection(slug: string) {
  const collection = await prisma.duaCollection.findUnique({
    where: { slug },
    include: { items: { orderBy: { sortOrder: 'asc' }, include: { dhikr: true } } },
  });
  if (!collection) throw notFound(`Dua collection "${slug}"`);
  const amenKeys: string[] = [];
  const items = await Promise.all(
    collection.items.map(async (item) => {
      if (item.dhikr) {
        const d = serializeDhikr(item.dhikr);
        amenKeys.push(d.amenKey);
        return { kind: 'dhikr' as const, ...d, repeat: Math.max(item.repeat, d.repeat) };
      }
      const v = await resolveVerseRange(item.verseRange!);
      amenKeys.push(v.amenKey);
      return { kind: 'verse' as const, ...v, virtue: null, repeat: item.repeat };
    }),
  );
  const counters = await prisma.amenCounter.findMany({ where: { targetKey: { in: amenKeys } } });
  const amen = new Map(counters.map((c) => [c.targetKey, c.count]));
  return {
    slug: collection.slug,
    nameAr: collection.nameAr,
    items: items.map((i) => ({ ...i, amenCount: amen.get(i.amenKey) ?? 0 })),
  };
}

/** Valid amen targets are existing dhikr ids or verse ranges used by a collection. */
export async function isValidAmenTarget(key: string): Promise<boolean> {
  const dhikr = /^dhikr:(\d+)$/.exec(key);
  if (dhikr) return (await prisma.dhikr.count({ where: { id: Number(dhikr[1]) } })) > 0;
  const verse = /^verse:(.+)$/.exec(key);
  if (verse) return (await prisma.duaCollectionItem.count({ where: { verseRange: verse[1] } })) > 0;
  return false;
}

export async function searchAthkar(query: string, limit: number) {
  const terms = searchTerms(query);
  if (terms.length === 0) return [];
  const conditions = terms.map((t) => Prisma.sql`d."textSearch" LIKE ${'%' + t + '%'}`);
  const rows = await prisma.$queryRaw<{ id: number }[]>`
    SELECT d.id FROM "Dhikr" d
    WHERE ${Prisma.join(conditions, ' AND ')}
    ORDER BY d."categoryId", d."sortOrder"
    LIMIT ${limit}`;
  const items = await prisma.dhikr.findMany({
    where: { id: { in: rows.map((r) => r.id) } },
    include: { category: true },
  });
  const order = new Map(rows.map((r, i) => [r.id, i]));
  return items
    .sort((a, b) => order.get(a.id)! - order.get(b.id)!)
    .map((d) => ({ ...serializeDhikr(d), category: { slug: d.category.slug, nameAr: d.category.nameAr } }));
}
