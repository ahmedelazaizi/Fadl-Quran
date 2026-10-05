/**
 * Static reference data used by the seed script. Texts are never hard-coded
 * here: athkar come from the Hisn al-Muslim dataset and Quranic duas are
 * referenced by verse number and read from the seeded Quran text.
 */

export const SOURCES = {
  alquranCloud: 'https://api.alquran.cloud/v1',
  athkar: 'https://raw.githubusercontent.com/osamayy/azkar-db/master/azkar.json',
  /** Arabic + English text, Arabic chapter names (AhmedBaset/hadith-json). */
  hadithJson: 'https://raw.githubusercontent.com/AhmedBaset/hadith-json/main/db/by_book',
  /** Grades (Al-Albani and others) for the Sunan (fawazahmed0/hadith-api). */
  hadithGrades: 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions',
};

/**
 * Hadith collections to embed. `gradeEdition` points to the fawazahmed0
 * edition used to attach grades; `defaultGrade` applies to whole books whose
 * contents are all authentic by consensus (the two Sahihs).
 */
export const HADITH_BOOKS: {
  slug: string;
  path: string;
  group: 'nine' | 'forties' | 'other';
  defaultGrade?: { grade: string; source: string };
  gradeEdition?: string;
}[] = [
  { slug: 'bukhari', path: 'the_9_books/bukhari', group: 'nine', defaultGrade: { grade: 'صحيح', source: 'صحيح البخاري' } },
  { slug: 'muslim', path: 'the_9_books/muslim', group: 'nine', defaultGrade: { grade: 'صحيح', source: 'صحيح مسلم' } },
  { slug: 'abudawud', path: 'the_9_books/abudawud', group: 'nine', gradeEdition: 'ara-abudawud' },
  { slug: 'tirmidhi', path: 'the_9_books/tirmidhi', group: 'nine', gradeEdition: 'ara-tirmidhi' },
  { slug: 'nasai', path: 'the_9_books/nasai', group: 'nine', gradeEdition: 'ara-nasai' },
  { slug: 'ibnmajah', path: 'the_9_books/ibnmajah', group: 'nine', gradeEdition: 'ara-ibnmajah' },
  { slug: 'malik', path: 'the_9_books/malik', group: 'nine' },
  { slug: 'ahmed', path: 'the_9_books/ahmed', group: 'nine' },
  { slug: 'darimi', path: 'the_9_books/darimi', group: 'nine' },
  { slug: 'nawawi40', path: 'forties/nawawi40', group: 'forties' },
  { slug: 'qudsi40', path: 'forties/qudsi40', group: 'forties' },
  { slug: 'riyad', path: 'other_books/riyad_assalihin', group: 'other' },
  { slug: 'bulugh', path: 'other_books/bulugh_almaram', group: 'other' },
  { slug: 'adab', path: 'other_books/aladab_almufrad', group: 'other' },
  { slug: 'shamail', path: 'other_books/shamail_muhammadiyah', group: 'other' },
  { slug: 'mishkat', path: 'other_books/mishkat_almasabih', group: 'other' },
];

/** English grade labels used by the grades dataset → Arabic. */
export const GRADE_AR: Record<string, string> = {
  'sahih': 'صحيح',
  'hasan': 'حسن',
  'hasan sahih': 'حسن صحيح',
  'sahih lighairihi': 'صحيح لغيره',
  'hasan lighairihi': 'حسن لغيره',
  "da'if": 'ضعيف',
  'daif': 'ضعيف',
  'da`if': 'ضعيف',
  'da’if': 'ضعيف',
  'daif jiddan': 'ضعيف جداً',
  "da'if jiddan": 'ضعيف جداً',
  'munkar': 'منكر',
  'shadh': 'شاذ',
  "mawdu'": 'موضوع',
  'maudu': 'موضوع',
  'mawdu': 'موضوع',
  'sahih mauquf': 'صحيح موقوف',
  'sahih maqtu': 'صحيح مقطوع',
  "da'if mauquf": 'ضعيف موقوف',
  'hasan mauquf': 'حسن موقوف',
  'sahih muquf': 'صحيح موقوف',
  'sahih hadith': 'صحيح',
  'sahih mutawatir': 'صحيح متواتر',
  'very daif': 'ضعيف جداً',
  'sahih isnaad': 'صحيح الإسناد',
  'hasan isnaad': 'حسن الإسناد',
  'daif isnaad': 'ضعيف الإسناد',
  'sahih isnaad maqtu': 'صحيح الإسناد مقطوع',
  'sahih isnaad mauquf': 'صحيح الإسناد موقوف',
};

export const LOCAL_EDITIONS = [
  { slug: 'ar.muyassar', type: 'TAFSIR', language: 'ar', nameAr: 'التفسير الميسر', nameEn: 'Tafsir Al-Muyassar', isDefault: true },
  { slug: 'ar.jalalayn', type: 'TAFSIR', language: 'ar', nameAr: 'تفسير الجلالين', nameEn: 'Tafsir Al-Jalalayn', isDefault: false },
  { slug: 'en.sahih', type: 'TRANSLATION', language: 'en', nameAr: 'الترجمة الإنجليزية (صحيح إنترناشيونال)', nameEn: 'Saheeh International', isDefault: true },
] as const;

/** Large tafsirs fetched lazily from Quran.com (resource ids from /resources/tafsirs). */
export const REMOTE_EDITIONS = [
  { slug: 'ar.saddi', externalId: 91, type: 'TAFSIR', language: 'ar', nameAr: 'تفسير السعدي', nameEn: "Tafsir Al-Sa'di" },
  { slug: 'ar.ibnkathir', externalId: 14, type: 'TAFSIR', language: 'ar', nameAr: 'تفسير ابن كثير', nameEn: 'Tafsir Ibn Kathir' },
  { slug: 'ar.tabari', externalId: 15, type: 'TAFSIR', language: 'ar', nameAr: 'تفسير الطبري', nameEn: 'Tafsir Al-Tabari' },
  { slug: 'ar.qurtubi', externalId: 90, type: 'TAFSIR', language: 'ar', nameAr: 'تفسير القرطبي', nameEn: 'Tafsir Al-Qurtubi' },
  { slug: 'ar.baghawi', externalId: 94, type: 'TAFSIR', language: 'ar', nameAr: 'تفسير البغوي', nameEn: 'Tafsir Al-Baghawi' },
] as const;

/** Bitrates verified against cdn.islamic.network. */
export const RECITERS = [
  { id: 'ar.abdulbasitmurattal', nameAr: 'عبد الباسط عبد الصمد', nameEn: 'Abdul Basit Abdul Samad', style: 'مرتل', verseBitrates: [192, 64], surahBitrate: 128, isDefault: true },
  { id: 'ar.aymanswoaid', nameAr: 'أيمن سويد', nameEn: 'Ayman Sowaid', style: 'معلم', riwaya: 'حفص عن عاصم', verseBitrates: [64], surahBitrate: null },
  { id: 'ar.husary', nameAr: 'محمود خليل الحصري', nameEn: 'Mahmoud Khalil Al-Husary', style: 'مرتل', verseBitrates: [128, 64], surahBitrate: null },
  { id: 'ar.husarymujawwad', nameAr: 'محمود خليل الحصري', nameEn: 'Al-Husary (Mujawwad)', style: 'مجود', verseBitrates: [128, 64], surahBitrate: null },
  { id: 'ar.minshawi', nameAr: 'محمد صديق المنشاوي', nameEn: 'Mohamed Siddiq Al-Minshawi', style: 'مرتل', verseBitrates: [128], surahBitrate: null },
  { id: 'ar.minshawimujawwad', nameAr: 'محمد صديق المنشاوي', nameEn: 'Al-Minshawi (Mujawwad)', style: 'مجود', verseBitrates: [64], surahBitrate: null },
  { id: 'ar.alafasy', nameAr: 'مشاري راشد العفاسي', nameEn: 'Mishary Rashid Alafasy', style: 'مرتل', verseBitrates: [128, 64], surahBitrate: 128 },
  { id: 'ar.mahermuaiqly', nameAr: 'ماهر المعيقلي', nameEn: 'Maher Al-Muaiqly', style: 'مرتل', verseBitrates: [128, 64], surahBitrate: null },
  { id: 'ar.abdurrahmaansudais', nameAr: 'عبد الرحمن السديس', nameEn: 'Abdurrahman As-Sudais', style: 'مرتل', verseBitrates: [192, 64], surahBitrate: null },
  { id: 'ar.saoodshuraym', nameAr: 'سعود الشريم', nameEn: 'Saud Ash-Shuraim', style: 'مرتل', verseBitrates: [64], surahBitrate: null },
  { id: 'ar.hudhaify', nameAr: 'علي بن عبد الرحمن الحذيفي', nameEn: 'Ali Al-Hudhaify', style: 'مرتل', verseBitrates: [128, 64, 32], surahBitrate: null },
  { id: 'ar.muhammadayyoub', nameAr: 'محمد أيوب', nameEn: 'Muhammad Ayyoub', style: 'مرتل', verseBitrates: [128], surahBitrate: null },
  { id: 'ar.abdullahbasfar', nameAr: 'عبد الله بصفر', nameEn: 'Abdullah Basfar', style: 'مرتل', verseBitrates: [192, 64, 32], surahBitrate: 128 },
  { id: 'ar.shaatree', nameAr: 'أبو بكر الشاطري', nameEn: 'Abu Bakr Ash-Shaatree', style: 'مرتل', verseBitrates: [128, 64], surahBitrate: null },
  { id: 'ar.ahmedajamy', nameAr: 'أحمد بن علي العجمي', nameEn: 'Ahmed Al-Ajamy', style: 'مرتل', verseBitrates: [128, 64], surahBitrate: null },
  { id: 'ar.hanirifai', nameAr: 'هاني الرفاعي', nameEn: 'Hani Rifai', style: 'مرتل', riwaya: 'حفص عن عاصم', verseBitrates: [192, 64], surahBitrate: null },
  { id: 'ar.ibrahimakhbar', nameAr: 'إبراهيم الأخضر', nameEn: 'Ibrahim Akhdar', style: 'مرتل', riwaya: 'حفص عن عاصم', verseBitrates: [32], surahBitrate: null },
  { id: 'ar.muhammadjibreel', nameAr: 'محمد جبريل', nameEn: 'Muhammad Jibreel', style: 'مرتل', riwaya: 'حفص عن عاصم', verseBitrates: [128], surahBitrate: null },
];

/** Hisn al-Muslim category name → stable slug; featured ones appear on the athkar screen. */
export const FEATURED_CATEGORIES: Record<string, { slug: string; order: number }> = {
  'أذكار الصباح': { slug: 'morning', order: 1 },
  'أذكار المساء': { slug: 'evening', order: 2 },
  'الأذكار بعد السلام من الصلاة': { slug: 'after-prayer', order: 3 },
  'أذكار النوم': { slug: 'sleep', order: 4 },
  'أذكار الاستيقاظ من النوم': { slug: 'waking', order: 5 },
  'دعاء السفر': { slug: 'travel', order: 6 },
  'دعاء الكرب': { slug: 'distress', order: 7 },
  'دعاء الهم والحزن': { slug: 'grief', order: 8 },
  'الاستغفار و التوبة': { slug: 'istighfar', order: 9 },
  'التسبيح، التحميد، التهليل، التكبير': { slug: 'tasbih', order: 10 },
  'أذكار الآذان': { slug: 'adhan', order: 11 },
  'الرقية الشرعية من القرآن الكريم': { slug: 'ruqyah-quran', order: 12 },
  'الرقية الشرعية من السنة النبوية': { slug: 'ruqyah-sunnah', order: 13 },
};

/**
 * Dua collections for the sadaqah-jariyah screen. `categories` pull every
 * dhikr of a Hisn al-Muslim category; `verses` reference Quranic duas.
 */
export const DUA_COLLECTIONS: {
  slug: string;
  nameAr: string;
  verses: string[];
  categories: string[];
}[] = [
  {
    slug: 'parents',
    nameAr: 'للوالدين والأب',
    verses: ['17:24', '14:41', '71:28', '46:15', '27:19'],
    categories: [],
  },
  {
    slug: 'deceased',
    nameAr: 'للمتوفى',
    verses: ['59:10'],
    categories: ['الدعاء عند إغماض الميت', 'الدعاء للميت في الصلاة عليه', 'الدعاء بعد دفن الميت', 'دعاء زيارة القبور'],
  },
  {
    slug: 'comprehensive',
    nameAr: 'جوامع الدعاء',
    verses: ['2:201', '2:286', '3:8', '3:193-194', '7:23', '14:40', '25:74'],
    categories: [],
  },
  {
    slug: 'healing',
    nameAr: 'الشفاء',
    verses: ['26:80', '21:83'],
    categories: ['الدعاء للمريض في عيادته', 'ما يقول من أحس وجعا في جسده'],
  },
  {
    slug: 'relief',
    nameAr: 'تفريج الكرب',
    verses: ['21:87'],
    categories: ['دعاء الكرب', 'دعاء الهم والحزن'],
  },
  {
    slug: 'provision',
    nameAr: 'الرزق',
    verses: ['5:114', '28:24', '71:10-12'],
    categories: ['دعاء قضاء الدين'],
  },
  {
    slug: 'ramadan',
    nameAr: 'أدعية رمضان والصيام',
    verses: ['2:186'],
    categories: ['دعاء رؤية الهلال', 'الدعاء عند إفطار الصائم', 'دعاء الصائم إذا حضر الطعام ولم يفطر', 'ما يقول الصائم إذا سابه أحد', 'دعاء قنوت الوتر'],
  },
];
