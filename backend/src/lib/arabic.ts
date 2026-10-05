/**
 * Arabic text normalization used for search: strips diacritics and Quranic
 * annotation marks and unifies letter variants so that user input like
 * "الوالدين" matches "وَبِالْوَالِدَيْنِ".
 */
const DIACRITICS = /[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u08D3-\u08FF]/g;
const TATWEEL = /\u0640/g;

export function normalizeArabic(input: string): string {
  return input
    .replace(DIACRITICS, '')
    .replace(TATWEEL, '')
    .replace(/[\u0622\u0623\u0625\u0671\u0672\u0673]/g, '\u0627') // آ أ إ ٱ → ا
    .replace(/\u0649/g, '\u064A') // ى → ي
    .replace(/\u0629/g, '\u0647') // ة → ه
    .replace(/\u0624/g, '\u0648') // ؤ → و
    .replace(/\u0626/g, '\u064A') // ئ → ي
    .replace(/[^\u0621-\u064A0-9a-zA-Z\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

/**
 * Splits a query into normalized search terms. The definite article "ال" is
 * stripped so "الصبر" also matches "بالصبر" / "وصبر" when used as a substring
 * match. Other prefixes are kept because stripping them is ambiguous
 * (e.g. "والدين" is not "و" + "الدين").
 */
export function searchTerms(query: string): string[] {
  const words = normalizeArabic(query).split(' ').filter(Boolean);
  const terms = words.map((w) => (w.startsWith('ال') && w.length >= 5 ? w.slice(2) : w));
  return [...new Set(terms.filter((t) => t.length >= 2))];
}

const EASTERN_DIGITS = '٠١٢٣٤٥٦٧٨٩';

export function toArabicDigits(value: string | number): string {
  return String(value).replace(/[0-9]/g, (d) => EASTERN_DIGITS[Number(d)]!);
}
