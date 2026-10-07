import 'dart:io';

import 'package:fadl/core/adhan_catalog.dart';
import 'package:fadl/core/adhan_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = Directory('android/app/src/main/res/raw');
  final pbxproj = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();

  test('every bundled adhan ships on Android and iOS with a credit', () {
    final ids = bundledAdhans.map((a) => a.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    for (final adhan in bundledAdhans) {
      expect(adhan.id, matches(RegExp(r'^adhan_[a-z0-9_]+$')));
      expect(
        File('${raw.path}/${adhan.id}.ogg').existsSync(),
        isTrue,
        reason: adhan.id,
      );
      expect(
        File('ios/Runner/${adhan.id}.caf').existsSync(),
        isTrue,
        reason: adhan.id,
      );
      expect(
        pbxproj,
        contains('${adhan.id}.caf in Resources'),
        reason: adhan.id,
      );
      expect(adhan.nameAr, isNotEmpty);
      expect(adhan.nameEn, isNotEmpty);
      expect(adhan.credit, contains('https://'), reason: adhan.id);
      expect(
        adhan.credit,
        matches(RegExp('CC0|CC BY|[Pp]ublic domain')),
        reason: adhan.id,
      );
    }
  });

  test('every adhan file in the app is listed in the catalog', () {
    final files = [
      for (final f in raw.listSync())
        if (f.path.endsWith('.ogg'))
          f.uri.pathSegments.last.replaceAll('.ogg', ''),
    ];
    expect(files.toSet(), bundledAdhans.map((a) => a.id).toSet());
  });

  test('Fajr adhans serve Fajr only and the others never serve Fajr', () {
    expect(bundledAdhanSounds, contains(defaultAdhanSound));
    for (final id in bundledAdhanSounds) {
      expect(soundForPrayer({'fajrSound': id}, 'fajr'), isNull, reason: id);
    }
    for (final id in bundledFajrAdhanSounds) {
      expect(soundForPrayer({'fajrSound': id}, 'fajr'), id);
      expect(soundForPrayer({'regularSound': id}, 'dhuhr'), defaultAdhanSound);
    }
  });
}
