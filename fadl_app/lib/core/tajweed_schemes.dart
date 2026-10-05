import 'dart:ui' show Color;

import 'offline_tajweed.dart';

const tajweedSchemePreferenceKey = 'fadl.tajweedScheme';

class TajweedCategory {
  const TajweedCategory(this.label, this.rules, this.dayColor, this.darkColor);

  final String label;
  final List<String> rules;
  final Color dayColor;
  final Color darkColor;
}

enum TajweedScheme {
  simple('الألوان المبسطة'),
  darAlMaarifa('دار المعرفة');

  const TajweedScheme(this.label);
  final String label;

  List<TajweedCategory> get categories => switch (this) {
    simple => const [
      TajweedCategory(
        'مد',
        [
          'madda_normal',
          'madda_permissible',
          'madda_obligatory',
          'madda_necessary',
        ],
        Color(0xFF146A94),
        Color(0xFF74C9EE),
      ),
      TajweedCategory(
        'غنة/إخفاء',
        ['ghunnah', 'ikhafa', 'ikhafa_shafawi', 'idgham_ghunnah'],
        Color(0xFFBD414C),
        Color(0xFFFF8792),
      ),
      TajweedCategory(
        'إدغام/إقلاب',
        [
          'idgham_wo_ghunnah',
          'idgham_shafawi',
          'idgham_mutajanisayn',
          'idgham_mutaqaribayn',
          'iqlab',
        ],
        Color(0xFF8B579D),
        Color(0xFFD4A3E5),
      ),
      TajweedCategory(
        'قلقلة',
        ['qalaqah'],
        Color(0xFFB15D1B),
        Color(0xFFFFB879),
      ),
      TajweedCategory(
        'وصل/لام',
        ['ham_wasl', 'laam_shamsiyah'],
        Color(0xFF497E51),
        Color(0xFF94D59D),
      ),
      TajweedCategory(
        'حروف صامتة',
        ['slnt'],
        Color(0xFF757575),
        Color(0xFFBBBBBB),
      ),
    ],
    darAlMaarifa => const [
      TajweedCategory(
        'مدّ حركتان',
        ['madda_normal'],
        Color(0xFF986500),
        Color(0xFFFFCD69),
      ),
      TajweedCategory(
        'مدّ ٢ أو ٤ أو ٦ جوازًا',
        ['madda_permissible'],
        Color(0xFFAD4E00),
        Color(0xFFFFA86A),
      ),
      TajweedCategory(
        'مدّ واجب ٤ أو ٥ حركات',
        ['madda_obligatory'],
        Color(0xFFBB2630),
        Color(0xFFFF828B),
      ),
      TajweedCategory(
        'مدّ ٦ حركات لزومًا',
        ['madda_necessary'],
        Color(0xFF861831),
        Color(0xFFFF6788),
      ),
      TajweedCategory(
        'إخفاء ومواقع الغنّة (حركتان)',
        ['ghunnah', 'ikhafa', 'ikhafa_shafawi', 'idgham_ghunnah', 'iqlab'],
        Color(0xFF287339),
        Color(0xFF87D996),
      ),
      TajweedCategory(
        'إدغام وما لا يُلفظ',
        [
          'idgham_wo_ghunnah',
          'idgham_shafawi',
          'idgham_mutajanisayn',
          'idgham_mutaqaribayn',
          'ham_wasl',
          'laam_shamsiyah',
          'slnt',
        ],
        Color(0xFF62666D),
        Color(0xFFC5C9CE),
      ),
      TajweedCategory(
        'قلقلة',
        ['qalaqah'],
        Color(0xFF20739E),
        Color(0xFF8DD4F9),
      ),
    ],
  };

  Color? colorFor(String? rule, {bool dark = false}) {
    if (rule == null || !tajweedColors.containsKey(rule)) return null;
    for (final category in categories) {
      if (category.rules.contains(rule)) {
        return dark ? category.darkColor : category.dayColor;
      }
    }
    return null;
  }
}
