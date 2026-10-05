import 'package:fadl/core/memorization.dart';
import 'package:fadl/core/quran_audio.dart';
import 'package:fadl/core/quran_data.dart';
import 'package:fadl/screens/quran/reader_audio_focus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'external recitation follows page crossing and retains selection',
    () async {
      final focus = ReaderAudioFocus();
      final quran = await QuranData.load();
      const selected = '1:1';

      expect(focus.update(ayahKey: '1:7', sourceActive: true), isTrue);
      final earlierRevision = focus.revision;
      expect(quran.ayah(focus.highlightedKey(selected)!)?['page'], 1);

      expect(focus.update(ayahKey: '2:1', sourceActive: true), isTrue);
      expect(focus.isCurrent(earlierRevision), isFalse);
      expect(quran.ayah(focus.highlightedKey(selected)!)?['page'], 2);

      expect(focus.update(ayahKey: '2:1', sourceActive: true), isFalse);
      expect(focus.highlightedKey(selected), '2:1');
      expect(focus.update(ayahKey: '2:1', sourceActive: false), isTrue);
      expect(focus.highlightedKey(selected), selected);
    },
  );

  group('continuous playlist selection', () {
    test('ordinary listening includes a single-play range', () {
      expect(usesContinuousPlaylist(const MemorizationSettings()), isTrue);
      expect(
        usesContinuousPlaylist(
          const MemorizationSettings(rangeStart: 2, rangeEnd: 4),
        ),
        isTrue,
      );
    });

    test('repeats and pauses retain memorization playback', () {
      for (final settings in [
        const MemorizationSettings(ayahRepeats: 2),
        const MemorizationSettings(ayahRepeats: 0),
        const MemorizationSettings(pauseMode: 3),
        const MemorizationSettings(rangeStart: 2, rangeEnd: 4, rangeRepeats: 2),
      ]) {
        expect(usesContinuousPlaylist(settings), isFalse);
      }
    });
  });

  test('zero-based playback indices map to audible ayah metadata', () {
    final ayahs = <Map<String, dynamic>>[
      {'key': '2:1', 'number': 1},
      {'key': '2:2', 'number': 2},
      {'key': '2:3', 'number': 3},
    ];
    expect(ayahAtAudioIndex(ayahs, 0)?['key'], '2:1');
    expect(ayahAtAudioIndex(ayahs, 1)?['number'], 2);
    expect(ayahAtAudioIndex(ayahs, 2)?['key'], '2:3');
    expect(ayahAtAudioIndex(ayahs, null), isNull);
    expect(ayahAtAudioIndex(ayahs, -1), isNull);
    expect(ayahAtAudioIndex(ayahs, 3), isNull);
  });

  test('next surah is available only for continuous unrestricted playback', () {
    expect(nextContinuousSurah(1, true, false), 2);
    expect(nextContinuousSurah(113, true, false), 114);
    expect(nextContinuousSurah(114, true, false), isNull);
    expect(nextContinuousSurah(1, false, false), isNull);
    expect(nextContinuousSurah(1, true, true), isNull);
  });
}
