/// Short adhkar and supplications for periodic reminders. Each text is
/// quoted from an authentic report (or the Quran) named in [source]; the
/// Arabic stays untranslated in every UI language.
class DhikrReminder {
  const DhikrReminder(this.text, this.source);
  final String text;
  final String source;
}

const dhikrReminders = <DhikrReminder>[
  DhikrReminder(
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
    'البخاري ٦٤٠٦، مسلم ٢٦٩٤',
  ),
  DhikrReminder(
    'سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ',
    'مسلم ٢١٣٧',
  ),
  DhikrReminder(
    'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
    'البخاري ٣٢٩٣، مسلم ٢٦٩١',
  ),
  DhikrReminder(
    'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    'البخاري ٤٢٠٥، مسلم ٢٧٠٤',
  ),
  DhikrReminder('أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ', 'البخاري ٦٣٠٧'),
  DhikrReminder(
    'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
    'من صلّى عليّ واحدة صلّى الله عليه بها عشرًا — مسلم ٤٠٨',
  ),
  DhikrReminder(
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ',
    'مسلم ٢٧٢٦',
  ),
  DhikrReminder(
    'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
    'البقرة ٢٠١؛ وكان أكثر دعاء النبي ﷺ — البخاري ٦٣٨٩',
  ),
  DhikrReminder(
    'يَا مُقَلِّبَ الْقُلُوبِ، ثَبِّتْ قَلْبِي عَلَى دِينِكَ',
    'الترمذي ٢١٤٠، وصححه الألباني',
  ),
  DhikrReminder(
    'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ',
    'أبو داود ١٥٢٢، وصححه الألباني',
  ),
  DhikrReminder(
    'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ',
    'ابن ماجه ٣٨٧١، وصححه الألباني',
  ),
  DhikrReminder(
    'رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ، إِنَّكَ أَنْتَ التَّوَّابُ الرَّحِيمُ',
    'أبو داود ١٥١٦، وصححه الألباني',
  ),
  DhikrReminder(
    'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ، وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
    'التوبة ١٢٩',
  ),
  DhikrReminder('الْحَمْدُ لِلَّهِ', 'والحمد لله تملأ الميزان — مسلم ٢٢٣'),
];

/// Reminder intervals offered in settings, in hours.
const dhikrReminderIntervals = [1, 2, 3, 4, 6];

/// Local hours (inclusive start, exclusive end) when reminders may fire, so
/// they never wake anyone at night.
const dhikrReminderStartHour = 8;
const dhikrReminderEndHour = 22;
