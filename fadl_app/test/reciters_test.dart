import 'package:fadl/core/reciters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogue includes verified verse editions with unique IDs', () {
    const additional = {
      'ar.parhizgar': [48],
    };
    expect(reciters, hasLength(19));
    expect(reciters.map((r) => r['id']).toSet(), hasLength(reciters.length));
    for (final entry in additional.entries) {
      expect(reciterById(entry.key)?['verseBitrates'], entry.value);
    }
    for (final reciter in reciters) {
      expect(reciter['nameAr'], isNotEmpty);
      expect(reciter['nameEn'], isNotEmpty);
      expect(reciter['style'], isNotEmpty);
      expect(reciter['riwaya'], isNotEmpty);
      final bitrates = (reciter['verseBitrates'] as List).cast<int>();
      expect(bitrates, isNotEmpty);
      expect(bitrates.every((bitrate) => bitrate > 0), isTrue);
      expect(
        ayahAudioUrl(reciter['id'] as String, 1),
        verseAudioUrl(reciter['id'] as String, pickBitrate(bitrates), 1),
      );
    }
  });

  test('Arabic variants and Latin names match reciters', () {
    final husary = reciterById('ar.husary')!;
    expect(matchesReciterSearch(husary, 'محمود خليل الحصرى'), isTrue);
    expect(matchesReciterSearch(husary, 'AL-HUSARY'), isTrue);
    expect(matchesReciterSearch(husary, '   '), isTrue);
    expect(matchesReciterSearch(husary, 'المنشاوي'), isFalse);
    expect(
      matchesReciterSearch(reciterById('ar.parhizgar')!, 'parhizgar'),
      isTrue,
    );
  });

  test('default reciter exists and is the only default', () {
    final reciter = reciterById(defaultReciterId);
    expect(reciter, isNotNull);
    expect(reciter!['isDefault'], isTrue);
    expect(reciters.where((r) => r['isDefault'] == true), hasLength(1));
  });

  test('ayah URL follows the server CDN template', () {
    expect(
      ayahAudioUrl('ar.alafasy', 1),
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3',
    );
    expect(() => ayahAudioUrl('unknown', 1), throwsArgumentError);
  });

  test('bitrate choice mirrors the server', () {
    expect(pickBitrate([64, 192]), 192);
    expect(pickBitrate([192, 64], 128), 64);
    expect(pickBitrate([128, 64], 32), 64);
  });
}
