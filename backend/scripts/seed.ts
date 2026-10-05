/**
 * Seeds reference data: Quran (Uthmani + simple text, page/juz/hizb metadata),
 * local tafsir/translation editions, remote tafsir registry, reciters,
 * athkar (Hisn al-Muslim) and dua collections.
 *
 *   npm run seed            # idempotent; skips parts that are already seeded
 *   npm run seed -- --force # re-imports Quran text and editions
 *
 * Downloads are cached in data/cache so re-runs work offline.
 */
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { PrismaClient, type Prisma } from '@prisma/client';
import { normalizeArabic } from '../src/lib/arabic.js';
import {
  DUA_COLLECTIONS,
  FEATURED_CATEGORIES,
  GRADE_AR,
  HADITH_BOOKS,
  LOCAL_EDITIONS,
  RECITERS,
  REMOTE_EDITIONS,
  SOURCES,
} from './seed-data.js';

const prisma = new PrismaClient();
const force = process.argv.includes('--force');
const CACHE_DIR = path.resolve('data/cache');

async function cachedJson<T>(name: string, url: string): Promise<T> {
  const file = path.join(CACHE_DIR, `${name}.json`);
  if (existsSync(file)) return JSON.parse(await readFile(file, 'utf8')) as T;
  console.log(`  ↓ downloading ${url}`);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`GET ${url} → HTTP ${res.status}`);
  const text = await res.text();
  await mkdir(CACHE_DIR, { recursive: true });
  await writeFile(file, text);
  return JSON.parse(text) as T;
}

interface CloudAyah {
  number: number;
  text: string;
  numberInSurah: number;
  juz: number;
  manzil: number;
  page: number;
  ruku: number;
  hizbQuarter: number;
  sajda: boolean | object;
}
interface CloudSurah {
  number: number;
  name: string;
  englishName: string;
  englishNameTranslation: string;
  revelationType: 'Meccan' | 'Medinan';
  ayahs: CloudAyah[];
}
interface CloudQuran {
  data: { surahs: CloudSurah[] };
}

const DIACRITICS = /[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]/g;

function plainSurahName(name: string): string {
  return name.replace(DIACRITICS, '').replace(/\u0671/g, 'ا').replace(/^سورة\s+/, '').trim();
}

const BOM = /^\uFEFF/;

/**
 * The alquran.cloud text prefixes the first ayah of every surah (except
 * Al-Fatiha and At-Tawbah) with the basmala; strip it so ayah 1 is the ayah.
 * Compared word-by-word after normalization because the Uthmani basmala is
 * not byte-identical in every surah.
 */
function stripBasmala(raw: string, surah: number, ayah: number): string {
  const text = raw.replace(BOM, '').trim();
  if (surah === 1 || surah === 9 || ayah !== 1) return text;
  const words = text.split(/\s+/);
  if (normalizeArabic(words.slice(0, 4).join(' ')) === 'بسم الله الرحمن الرحيم') {
    return words.slice(4).join(' ');
  }
  return text;
}

async function chunked<T>(items: T[], size: number, fn: (chunk: T[]) => Promise<unknown>) {
  for (let i = 0; i < items.length; i += size) await fn(items.slice(i, i + size));
}

async function seedQuran() {
  const existing = await prisma.ayah.count();
  if (existing === 6236 && !force) {
    console.log('• Quran already seeded (6236 ayahs) — skipping');
    return;
  }
  console.log('• Seeding Quran text');
  const uthmani = await cachedJson<CloudQuran>('quran-uthmani', `${SOURCES.alquranCloud}/quran/quran-uthmani`);
  const simple = await cachedJson<CloudQuran>('quran-simple-clean', `${SOURCES.alquranCloud}/quran/quran-simple-clean`);

  const simpleById = new Map<number, string>();
  for (const s of simple.data.surahs) {
    for (const a of s.ayahs) simpleById.set(a.number, stripBasmala(a.text, s.number, a.numberInSurah));
  }

  await prisma.$transaction([prisma.ayahText.deleteMany(), prisma.ayah.deleteMany(), prisma.surah.deleteMany()]);

  await prisma.surah.createMany({
    data: uthmani.data.surahs.map((s) => ({
      id: s.number,
      nameAr: plainSurahName(s.name),
      nameEn: s.englishNameTranslation,
      nameTranslit: s.englishName,
      revelationType: s.revelationType === 'Meccan' ? 'MECCAN' : 'MEDINAN',
      ayahCount: s.ayahs.length,
      startPage: s.ayahs[0]!.page,
    })),
  });

  const ayahs: Prisma.AyahCreateManyInput[] = uthmani.data.surahs.flatMap((s) =>
    s.ayahs.map((a) => {
      const textSimple = simpleById.get(a.number) ?? '';
      return {
        id: a.number,
        surahId: s.number,
        number: a.numberInSurah,
        key: `${s.number}:${a.numberInSurah}`,
        textUthmani: stripBasmala(a.text, s.number, a.numberInSurah),
        textSimple,
        textSearch: normalizeArabic(textSimple),
        juz: a.juz,
        hizbQuarter: a.hizbQuarter,
        page: a.page,
        manzil: a.manzil,
        ruku: a.ruku,
        sajda: Boolean(a.sajda),
      };
    }),
  );
  await chunked(ayahs, 1000, (data) => prisma.ayah.createMany({ data }));
  console.log(`  ✓ ${ayahs.length} ayahs, ${uthmani.data.surahs.length} surahs`);
}

async function seedEditions() {
  for (const e of REMOTE_EDITIONS) {
    await prisma.textEdition.upsert({
      where: { slug: e.slug },
      create: { ...e, source: 'QURAN_COM' },
      update: { ...e, source: 'QURAN_COM' },
    });
  }
  for (const e of LOCAL_EDITIONS) {
    await prisma.textEdition.upsert({
      where: { slug: e.slug },
      create: { ...e, source: 'LOCAL' },
      update: { ...e, source: 'LOCAL' },
    });
    const count = await prisma.ayahText.count({ where: { editionSlug: e.slug } });
    if (count === 6236 && !force) {
      console.log(`• Edition ${e.slug} already seeded — skipping`);
      continue;
    }
    console.log(`• Seeding edition ${e.slug}`);
    const data = await cachedJson<CloudQuran>(e.slug, `${SOURCES.alquranCloud}/quran/${e.slug}`);
    await prisma.ayahText.deleteMany({ where: { editionSlug: e.slug } });
    const rows = data.data.surahs.flatMap((s) =>
      s.ayahs.map((a) => ({ editionSlug: e.slug, ayahId: a.number, text: a.text.replace(BOM, '').trim() })),
    );
    await chunked(rows, 1000, (chunk) => prisma.ayahText.createMany({ data: chunk }));
    console.log(`  ✓ ${rows.length} entries`);
  }
}

async function seedReciters() {
  for (const [i, r] of RECITERS.entries()) {
    const data = { ...r, isDefault: r.isDefault ?? false, sortOrder: i };
    await prisma.reciter.upsert({ where: { id: r.id }, create: data, update: data });
  }
  console.log(`• ${RECITERS.length} reciters`);
}

interface AthkarDump {
  rows: [category: string, zekr: string, description: string | null, count: number | null, reference: string | null, search: string][];
}

async function seedAthkar() {
  if ((await prisma.dhikr.count()) > 0 && !force) {
    console.log('• Athkar already seeded — skipping');
    return;
  }
  console.log('• Seeding athkar (Hisn al-Muslim)');
  const dump = await cachedJson<AthkarDump>('azkar', SOURCES.athkar);
  const categoryOrder: string[] = [];
  for (const row of dump.rows) if (!categoryOrder.includes(row[0])) categoryOrder.push(row[0]);

  // Keep ids stable for users' progress: upsert categories, replace items only on --force.
  if (force) {
    await prisma.duaCollectionItem.deleteMany();
    await prisma.athkarProgress.deleteMany();
    await prisma.dhikr.deleteMany();
  }
  for (const [index, name] of categoryOrder.entries()) {
    const featured = FEATURED_CATEGORIES[name.trim()];
    const slug = featured?.slug ?? `hisn-${index + 1}`;
    const category = await prisma.athkarCategory.upsert({
      where: { nameAr: name.trim() },
      create: { nameAr: name.trim(), slug, featured: Boolean(featured), sortOrder: featured?.order ?? 100 + index },
      update: { slug, featured: Boolean(featured), sortOrder: featured?.order ?? 100 + index },
    });
    const items = dump.rows.filter((r) => r[0] === name);
    await prisma.dhikr.createMany({
      data: items.map(([, zekr, description, count, reference], i) => ({
        categoryId: category.id,
        text: zekr.trim(),
        virtue: description?.trim() || null,
        repeat: count && count > 0 ? count : 1,
        reference: reference?.trim() || null,
        sortOrder: i,
        textSearch: normalizeArabic(zekr),
      })),
    });
  }
  console.log(`  ✓ ${dump.rows.length} athkar in ${categoryOrder.length} categories`);
}

function parseRange(range: string): { surah: number; from: number; to: number } {
  const m = /^(\d+):(\d+)(?:-(\d+))?$/.exec(range);
  if (!m) throw new Error(`Bad verse range ${range}`);
  return { surah: Number(m[1]), from: Number(m[2]), to: Number(m[3] ?? m[2]) };
}

async function seedDuaCollections() {
  console.log('• Seeding dua collections');
  await prisma.duaCollection.deleteMany();
  for (const [order, c] of DUA_COLLECTIONS.entries()) {
    const items: { dhikrId?: number; verseRange?: string; sortOrder: number }[] = [];
    for (const v of c.verses) {
      const { surah, from, to } = parseRange(v);
      const found = await prisma.ayah.count({ where: { surahId: surah, number: { gte: from, lte: to } } });
      if (found !== to - from + 1) throw new Error(`Collection ${c.slug}: verse range ${v} not found`);
      items.push({ verseRange: v, sortOrder: items.length });
    }
    for (const name of c.categories) {
      const cat = await prisma.athkarCategory.findUnique({ where: { nameAr: name }, include: { items: { orderBy: { sortOrder: 'asc' } } } });
      if (!cat) throw new Error(`Collection ${c.slug}: athkar category "${name}" not found`);
      for (const d of cat.items) items.push({ dhikrId: d.id, sortOrder: items.length });
    }
    await prisma.duaCollection.create({
      data: { slug: c.slug, nameAr: c.nameAr, sortOrder: order, items: { create: items } },
    });
  }
  console.log(`  ✓ ${DUA_COLLECTIONS.length} collections`);
}

interface HadithJsonBook {
  metadata: { arabic: { title: string; author: string }; english: { title: string } };
  chapters: { id: number; arabic: string; english?: string }[];
  hadiths: {
    idInBook: number;
    chapterId: number | null;
    arabic: string;
    english?: { narrator?: string; text?: string };
  }[];
}
interface GradeEdition {
  hadiths: { hadithnumber: number; text: string; grades: { name: string; grade: string }[] }[];
}

function arabicGrade(raw: string): string | null {
  const key = raw.toLowerCase().replace(/\(.*?\)/g, '').replace(/\s+/g, ' ').trim();
  return GRADE_AR[key] ?? null;
}

async function seedHadith() {
  const existing = await prisma.hadith.count();
  if (existing > 0 && !force) {
    console.log(`• Hadith already seeded (${existing}) — skipping`);
    return;
  }
  console.log('• Seeding hadith collections');
  await prisma.hadithBook.deleteMany();
  for (const [index, def] of HADITH_BOOKS.entries()) {
    const data = await cachedJson<HadithJsonBook>(`hadith-${def.slug}`, `${SOURCES.hadithJson}/${def.path}.json`);
    const bookId = index + 1;
    await prisma.hadithBook.create({
      data: {
        id: bookId,
        slug: def.slug,
        nameAr: data.metadata.arabic.title.trim(),
        nameEn: data.metadata.english.title.trim(),
        authorAr: data.metadata.arabic.author.trim(),
        group: def.group,
        hadithCount: data.hadiths.length,
        sortOrder: index,
      },
    });
    await prisma.hadithChapter.createMany({
      data: data.chapters
        .filter((c) => c.arabic?.trim())
        .map((c) => ({ bookId, number: c.id, nameAr: c.arabic.trim(), nameEn: c.english?.trim() || null })),
      skipDuplicates: true,
    });
    const chapters = await prisma.hadithChapter.findMany({ where: { bookId }, select: { id: true, number: true } });
    const chapterIdByNumber = new Map(chapters.map((c) => [c.number, c.id]));

    // The two datasets number hadiths differently, so grades are matched by
    // the opening 120 normalized letters (isnad + start of matn). Only
    // prefixes that identify exactly one hadith are used, so an ambiguous
    // match never produces a wrong grade.
    const grades = new Map<number, { grade: string; source: string }>();
    if (def.gradeEdition) {
      const g = await cachedJson<GradeEdition>(`grades-${def.slug}`, `${SOURCES.hadithGrades}/${def.gradeEdition}.json`);
      const prefix = (t: string) => normalizeArabic(t).replace(/\s/g, '').slice(0, 120);
      const byPrefix = new Map<string, GradeEdition['hadiths'][number] | null>();
      for (const h of g.hadiths) {
        const k = prefix(h.text);
        byPrefix.set(k, byPrefix.has(k) ? null : h);
      }
      const ownPrefixCount = new Map<string, number>();
      for (const h of data.hadiths) ownPrefixCount.set(prefix(h.arabic), (ownPrefixCount.get(prefix(h.arabic)) ?? 0) + 1);
      for (const h of data.hadiths) {
        const k = prefix(h.arabic);
        const candidate = byPrefix.get(k);
        if (k.length < 60 || !candidate?.grades?.length || ownPrefixCount.get(k) !== 1) continue;
        const pick = candidate.grades.find((x) => /albani/i.test(x.name)) ?? candidate.grades[0]!;
        const grade = arabicGrade(pick.grade);
        if (grade) grades.set(h.idInBook, { grade, source: /albani/i.test(pick.name) ? 'الألباني' : pick.name });
      }
    }

    const seen = new Set<number>();
    const rows = data.hadiths
      .filter((h) => h.arabic?.trim() && !seen.has(h.idInBook) && seen.add(h.idInBook))
      .map((h) => {
        const grade = def.defaultGrade ?? grades.get(h.idInBook);
        return {
          bookId,
          chapterId: h.chapterId != null ? (chapterIdByNumber.get(h.chapterId) ?? null) : null,
          number: h.idInBook,
          textAr: h.arabic.trim(),
          textSearch: normalizeArabic(h.arabic),
          textEn: h.english?.text?.trim() || null,
          narratorEn: h.english?.narrator?.trim() || null,
          grade: grade?.grade ?? null,
          gradeSource: grade?.source ?? null,
        };
      });
    await chunked(rows, 1000, (chunk) => prisma.hadith.createMany({ data: chunk }));
    const graded = rows.filter((r) => r.grade).length;
    console.log(`  ✓ ${def.slug}: ${rows.length} hadiths, ${data.chapters.length} chapters, ${graded} graded`);
  }
}

async function main() {
  await seedQuran();
  await seedEditions();
  await seedReciters();
  await seedAthkar();
  await seedDuaCollections();
  await seedHadith();
  console.log('Seed complete.');
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
