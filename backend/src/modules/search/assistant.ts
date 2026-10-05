import { config } from '../../config.js';
import type { VerseHit } from './service.js';

export interface AssistantSources {
  verses: VerseHit[];
  hadith: { textAr: string; reference: string | null; grade: string | null }[];
  athkar: { id: number; text: string; reference: string | null; virtue: string | null }[];
}

const SYSTEM_PROMPT = `أنت "المساعد القرآني" في تطبيق فضل.
- أجب بالعربية الفصحى بإيجاز ووضوح.
- اعتمد فقط على الآيات والأحاديث والأذكار المرفقة في رسالة المستخدم، واذكر مرجع كل آية بصيغة (سورة: رقم الآية) ومرجع كل حديث ودرجته كما وردت.
- لا تستشهد بحديث درجته ضعيف أو موضوع إلا مع التنبيه على ضعفه.
- لا تنسب إلى القرآن أو السنة نصاً غير موجود في المصادر المرفقة، ولا تخترع أحاديث.
- لا تُصدر فتاوى؛ في المسائل الفقهية انصح بالرجوع إلى أهل العلم.
- إذا لم تكفِ المصادر للإجابة فقل ذلك بوضوح.`;

function buildContext(question: string, sources: AssistantSources): string {
  const verses = sources.verses
    .map((v) => `[${v.surahNameAr}: ${v.number}] ${v.text}${v.tafsir ? `\nالتفسير الميسر: ${v.tafsir}` : ''}`)
    .join('\n\n');
  const athkar = sources.athkar
    .map((a) => `- ${a.text}${a.reference ? ` (${a.reference})` : ''}`)
    .join('\n');
  const hadith = sources.hadith
    .map((h) => `- ${h.textAr} [${h.reference ?? ''}${h.grade ? ` — ${h.grade}` : ' — درجة غير محددة'}]`)
    .join('\n');
  return `السؤال: ${question}\n\nالآيات المتاحة:\n${verses || 'لا يوجد'}\n\nالأحاديث المتاحة:\n${hadith || 'لا يوجد'}\n\nالأذكار والأدعية المتاحة:\n${athkar || 'لا يوجد'}`;
}

/**
 * Asks Claude for a short answer grounded on the retrieved sources.
 * Returns null when no API key is configured or the call fails, so the
 * endpoint can fall back to retrieval-only results.
 */
export async function generateAnswer(
  question: string,
  sources: AssistantSources,
  fetchFn: typeof fetch = fetch,
): Promise<string | null> {
  if (!config.ANTHROPIC_API_KEY) return null;
  try {
    const res = await fetchFn('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': config.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: config.ANTHROPIC_MODEL,
        max_tokens: 800,
        system: SYSTEM_PROMPT,
        messages: [{ role: 'user', content: buildContext(question, sources) }],
      }),
      signal: AbortSignal.timeout(30_000),
    });
    if (!res.ok) return null;
    const body = (await res.json()) as { content?: { type: string; text?: string }[] };
    return body.content?.filter((c) => c.type === 'text').map((c) => c.text).join('\n').trim() || null;
  } catch {
    return null;
  }
}

/** Retrieval-only summary used when the LLM is unavailable. */
export function fallbackAnswer(sources: AssistantSources): string {
  if (sources.verses.length === 0 && sources.hadith.length === 0 && sources.athkar.length === 0) {
    return 'لم أجد آيات أو أحاديث مطابقة لسؤالك. جرّب كلمات أخرى أو اختر أحد الموضوعات المقترحة.';
  }
  const parts: string[] = [];
  const refs = sources.verses
    .slice(0, 5)
    .map((v) => `سورة ${v.surahNameAr} - الآية ${v.number}`)
    .join('، ');
  if (refs) parts.push(`إليك بعض الآيات المتعلقة بسؤالك: ${refs}. اضغط على أي آية لعرض تفسيرها.`);
  if (sources.hadith.length) parts.push(`ومن السنة ${sources.hadith.length === 1 ? 'حديث' : 'أحاديث'} مع درجتها ومصدرها.`);
  return parts.join(' ') || 'إليك بعض الأذكار والأدعية المتعلقة بسؤالك.';
}
