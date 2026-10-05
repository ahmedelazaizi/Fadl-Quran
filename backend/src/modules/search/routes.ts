import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { z } from 'zod';
import { searchTerms } from '../../lib/arabic.js';
import { badRequest } from '../../lib/errors.js';
import { searchAthkar } from '../athkar/service.js';
import { searchHadith } from '../hadith/service.js';
import { TOPIC_PINNED_VERSES } from '../quran/curated.js';
import { fallbackAnswer, generateAnswer } from './assistant.js';
import { searchSurahs, searchVerses, TOPICS, topicTerms } from './service.js';

export const searchRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get(
    '/search',
    {
      schema: {
        tags: ['search'],
        summary: 'Search surah names, ayahs, hadith and athkar (diacritics-insensitive)',
        querystring: z.object({
          q: z.string().min(2).max(200),
          type: z.enum(['all', 'quran', 'hadith', 'athkar']).default('all'),
          limit: z.coerce.number().int().min(1).max(50).default(20),
          offset: z.coerce.number().int().min(0).default(0),
        }),
      },
    },
    async (req) => {
      const { q, type, limit, offset } = req.query;
      const terms = searchTerms(q);
      const want = (t: string) => type === 'all' || type === t;
      const [surahs, verses, hadith, athkar] = await Promise.all([
        want('quran') ? searchSurahs(q) : [],
        want('quran') ? searchVerses(terms, { limit, offset }) : { total: 0, hits: [] },
        want('hadith') ? searchHadith(q, { limit, offset }) : { total: 0, results: [] },
        want('athkar') ? searchAthkar(q, limit) : [],
      ]);
      return { query: q, terms, surahs, verses, hadith, athkar };
    },
  );

  app.get('/assistant/topics', { schema: { tags: ['assistant'], summary: 'Suggested topic chips' } }, async () => ({
    topics: TOPICS.map(({ slug, nameAr }) => ({ slug, nameAr })),
  }));

  app.post(
    '/assistant/ask',
    {
      config: { rateLimit: { max: 20, timeWindow: '1 minute' } },
      schema: {
        tags: ['assistant'],
        summary:
          'Quran assistant: retrieves relevant ayahs (with tafsir), hadith and athkar, and — when ANTHROPIC_API_KEY is set — writes a grounded answer',
        body: z
          .object({
            question: z.string().min(2).max(500).optional(),
            topic: z.string().max(40).optional(),
          })
          .refine((b) => b.question || b.topic, 'Provide a question or a topic'),
      },
    },
    async (req) => {
      const { question, topic } = req.body;
      let terms: string[];
      let mode: 'auto' | 'any' = 'auto';
      let pinned: readonly string[] = [];
      if (topic) {
        const t = topicTerms(topic);
        if (!t) throw badRequest(`Unknown topic "${topic}"`);
        terms = t;
        mode = 'any';
        pinned = TOPIC_PINNED_VERSES[topic] ?? [];
      } else {
        terms = searchTerms(question!);
      }
      const asked = question ?? TOPICS.find((t) => t.slug === topic)!.nameAr;
      const topicDef = TOPICS.find((t) => t.slug === topic);
      const [verses, hadith, athkar] = await Promise.all([
        searchVerses(terms, { limit: 6, mode, pinned }),
        searchHadith(topicDef?.hadithQuery ?? question!, { limit: 3 }),
        searchAthkar(topic ? asked : question!, 3),
      ]);
      const sources = { verses: verses.hits, hadith: hadith.results, athkar };
      const aiAnswer = await generateAnswer(asked, sources);
      return {
        question: asked,
        mode: aiAnswer ? 'ai' : 'retrieval',
        answer: aiAnswer ?? fallbackAnswer(sources),
        sources,
        suggestions: TOPICS.filter((t) => t.slug !== topic)
          .slice(0, 3)
          .map((t) => ({ slug: t.slug, nameAr: t.nameAr })),
        disclaimer: 'الإجابات مولّدة آلياً من الآيات والأحاديث والأذكار المرفقة؛ للمسائل الفقهية يُرجع إلى أهل العلم.',
      };
    },
  );
};
