import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Amiri Quran font asset loads and contains font data', () async {
    final font = await rootBundle.load('assets/fonts/AmiriQuran.ttf');
    expect(font.lengthInBytes, greaterThan(100000));

    final loader = FontLoader('AmiriQuran')..addFont(Future.value(font));
    await loader.load();
  });

  test(
    'Amiri Quran license asset includes the SIL Open Font License',
    () async {
      final license = await rootBundle.loadString(
        'assets/fonts/AmiriQuran-OFL.txt',
      );
      expect(license, contains('SIL OPEN FONT LICENSE Version 1.1'));
    },
  );

  test('every bundled font family ships its SIL Open Font License', () async {
    for (final file in const [
      'AmiriQuran-OFL.txt',
      'Tajawal-OFL.txt',
      'NotoNaskhArabic-OFL.txt',
    ]) {
      final license = await rootBundle.loadString('assets/fonts/$file');
      expect(
        license,
        contains('SIL OPEN FONT LICENSE Version 1.1'),
        reason: file,
      );
    }
  });
}
