/// Adhan recordings bundled with the app. Android plays
/// `android/app/src/main/res/raw/<id>.ogg` in full; iOS rings the first
/// 29.5 s, `ios/Runner/<id>.caf`, with the prayer notification.
///
/// To add one: run `tool/add_adhan.py` (it writes both files and registers
/// the clip in the Xcode project), then list it here with its source and
/// licence. A recording with «الصلاة خير من النوم» is a Fajr adhan: its id
/// starts with `adhan_fajr_` (the Android player relies on this) and it is
/// offered for Fajr only.
class BundledAdhan {
  const BundledAdhan({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.credit,
  });

  final String id;
  final String nameAr;
  final String nameEn;

  /// Source, author, licence and changes, shown on the licences page.
  final String credit;

  bool get fajr => id.startsWith('adhan_fajr_');

  String name(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;
}

const bundledAdhans = <BundledAdhan>[
  BundledAdhan(
    id: 'adhan_default',
    nameAr: 'الأذان الأساسي (هادئ)',
    nameEn: 'Default adhan (calm)',
    credit:
        '"Beautiful adhan" by Adam-synagda, Wikimedia Commons\n'
        'https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg\n'
        'Dedicated to the public domain under CC0 1.0 Universal:\n'
        'https://creativecommons.org/publicdomain/zero/1.0/\n'
        'Unmodified on Android; on iOS, the first 29.5 s with a fade-out.',
  ),
  BundledAdhan(
    id: 'adhan_madinah',
    nameAr: 'أذان المسجد النبوي (تسجيل)',
    nameEn: "Prophet's Mosque, Madinah (recording)",
    credit:
        '"Call to prayer from the Prophet\'s Mosque" recorded by ejaz215 '
        '(Freesound), via Wikimedia Commons\n'
        'https://commons.wikimedia.org/wiki/File:33937_ejaz215_call-to-prayer-from-the-prophet-s-mo.ogg\n'
        'Licensed under CC BY 3.0: https://creativecommons.org/licenses/by/3.0/\n'
        'Modified: converted to mono Ogg Vorbis; on iOS, the first 29.5 s '
        'with a fade-out.',
  ),
  BundledAdhan(
    id: 'adhan_makkah',
    nameAr: 'أذان المسجد الحرام (تسجيل ٢٠١٣)',
    nameEn: 'Masjid al-Haram, Makkah (2013 recording)',
    credit:
        '"Adhan, Great Mosque of Mecca - Jan 21, 2013" by Seyfula Islam, via '
        'Wikimedia Commons\n'
        'https://commons.wikimedia.org/wiki/File:Adhan,_Great_Mosque_of_Mecca_-_Jan_21,_2013.webm\n'
        'Licensed under CC BY 3.0: https://creativecommons.org/licenses/by/3.0/\n'
        'Modified: audio extracted and converted to mono Ogg Vorbis; on iOS, '
        'the first 29.5 s with a fade-out.',
  ),
];

BundledAdhan? bundledAdhan(String? id) {
  for (final adhan in bundledAdhans) {
    if (adhan.id == id) return adhan;
  }
  return null;
}
