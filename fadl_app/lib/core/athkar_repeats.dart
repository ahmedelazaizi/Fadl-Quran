import 'offline_athkar.dart';

/// Counter targets for adhkar whose count the bundled Hisn al-Muslim data
/// leaves empty while the text itself states it ("مائة مرة", "ثلاث مرات").
/// Each entry is a phrase found in exactly one such dhikr (matched after
/// [normalizeArabic]) and the count its text gives; when a text gives
/// several, the target is the repeated phrase the user counts. Texts that
/// already write out their repetitions, or that describe an act rather than
/// a dhikr, keep a single count.
const athkarStatedRepeats = <(String, int)>[
  ('سبحان ربي العظيم)). ثلاث مرات', 3),
  ('سبحان ربي الأعلى)) ثلاث مرات', 3),
  // أستغفر الله ثلاثًا، ثم الدعاء مرة.
  ('أستغفر الله (ثلاثا) اللهم أنت السلام', 3),
  ('والله أكبر (ثلاثا وثلاثين) لا إله إلا الله', 33),
  ('يحيي ويميت وهو على كل شيء قدير)) عشر مرات', 10),
  // المعوذات مع النفث والمسح، ثلاث مرات.
  ('يجمع كفيه ثم ينفث فيهما', 3),
  // ٣٣ + ٣٣ + ٣٤.
  ('والله أكبر (أربعا وثلاثين)', 100),
  ('سبحان الملك القدوس)) ثلاث مرات', 3),
  ('الله أعز من خلقه جميعا', 3),
  ('واتفل على يسارك (ثلاثا)', 3),
  ('رب اغفر لي، وتب علي، إنك أنت التواب الغفور', 100),
  ('قال مثل هذا ثلاث مرات', 3),
  // بسم الله ثلاثًا، والمعدود: أعوذ بالله وقدرته… سبع مرات.
  ('ضع يدك على الذي تألم من جسدك', 7),
  ('وأتوب إليه في اليوم أكثر من سبعين مرة', 70),
  ('فإني أتوب في اليوم إليه مائة مرة', 100),
  ('وإني لأستغفر الله في اليوم مائة مرة', 100),
  ('سبحان الله وبحمده في يوم مائة مرة', 100),
  ('وهو على كل شيء قدير عشر مرار', 10),
  ('يسبح مائة تسبيحة', 100),
  ('أعوذ بالله وقدرته من شر ما أجد وأحاذر (سبع مرات)', 7),
];

final _normalizedRepeats = [
  for (final (phrase, repeat) in athkarStatedRepeats)
    (normalizeArabic(phrase), repeat),
];

/// The stated count for a dhikr whose data has none, or null.
int? statedAthkarRepeat(String text) {
  final normalized = normalizeArabic(text);
  for (final (phrase, repeat) in _normalizedRepeats) {
    if (normalized.contains(phrase)) return repeat;
  }
  return null;
}
