import 'package:flutter_test/flutter_test.dart';
import 'package:fadl/core/tajweed_schemes.dart';

void main() {
  const groups = <String, List<String>>{
    'مدّ حركتان': ['madda_normal'],
    'مدّ ٢ أو ٤ أو ٦ جوازًا': ['madda_permissible'],
    'مدّ واجب ٤ أو ٥ حركات': ['madda_obligatory'],
    'مدّ ٦ حركات لزومًا': ['madda_necessary'],
    'إخفاء ومواقع الغنّة (حركتان)': [
      'ghunnah',
      'ikhafa',
      'ikhafa_shafawi',
      'idgham_ghunnah',
      'iqlab',
    ],
    'إدغام وما لا يُلفظ': [
      'idgham_wo_ghunnah',
      'idgham_shafawi',
      'idgham_mutajanisayn',
      'idgham_mutaqaribayn',
      'ham_wasl',
      'laam_shamsiyah',
      'slnt',
    ],
    'قلقلة': ['qalaqah'],
  };

  test('all source tags have readable colors in both palettes', () {
    final rules = groups.values.expand((tags) => tags).toSet();
    expect(rules.length, 17);
    for (final scheme in TajweedScheme.values) {
      for (final rule in rules) {
        expect(scheme.colorFor(rule), isNotNull, reason: '$scheme: $rule');
        expect(
          scheme.colorFor(rule, dark: true),
          isNotNull,
          reason: '$scheme (dark): $rule',
        );
      }
    }
  });

  test('Dar Al-Maarifa groups exactly match the provider tags', () {
    final actual = {
      for (final category in TajweedScheme.darAlMaarifa.categories)
        category.label: category.rules,
    };
    expect(actual, groups);
    for (final category in TajweedScheme.darAlMaarifa.categories) {
      for (final rule in category.rules) {
        expect(TajweedScheme.darAlMaarifa.colorFor(rule), category.dayColor);
        expect(
          TajweedScheme.darAlMaarifa.colorFor(rule, dark: true),
          category.darkColor,
        );
      }
    }
  });

  test(
    'no legend advertises unsupported tafkheem and unknown tags stay plain',
    () {
      for (final scheme in TajweedScheme.values) {
        expect(
          scheme.categories.any((category) => category.label.contains('تفخيم')),
          isFalse,
        );
        expect(scheme.colorFor('tafkheem'), isNull);
        expect(scheme.colorFor('unknown'), isNull);
      }
    },
  );
}
