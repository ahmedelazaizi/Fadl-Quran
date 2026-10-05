import 'package:fadl/core/memorization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const duration = Duration(seconds: 4);

  test(
    'repeats each ayah before advancing and pauses for configured duration',
    () {
      const settings = MemorizationSettings(ayahRepeats: 3, pauseMode: 2);
      final replay = nextMemorizationAction(
        settings: settings,
        ayah: 2,
        ayahCount: 5,
        ayahPlay: 2,
        rangePlay: 1,
        ayahDuration: duration,
      );
      final advance = nextMemorizationAction(
        settings: settings,
        ayah: 2,
        ayahCount: 5,
        ayahPlay: 3,
        rangePlay: 1,
        ayahDuration: duration,
      );
      expect(replay.move, MemorizationMove.replay);
      expect(replay.pause, const Duration(seconds: 8));
      expect(advance.move, MemorizationMove.advance);
    },
  );

  test('unlimited ayah repetitions do not advance', () {
    const settings = MemorizationSettings(ayahRepeats: 0);
    expect(
      nextMemorizationAction(
        settings: settings,
        ayah: 5,
        ayahCount: 5,
        ayahPlay: 99,
        rangePlay: 1,
        ayahDuration: duration,
      ).move,
      MemorizationMove.replay,
    );
  });

  test('range loops at its end then stops after the final pass', () {
    const settings = MemorizationSettings(
      rangeStart: 2,
      rangeEnd: 4,
      rangeRepeats: 2,
      pauseMode: 3,
    );
    final loop = nextMemorizationAction(
      settings: settings,
      ayah: 4,
      ayahCount: 5,
      ayahPlay: 1,
      rangePlay: 1,
      ayahDuration: duration,
    );
    final stop = nextMemorizationAction(
      settings: settings,
      ayah: 4,
      ayahCount: 5,
      ayahPlay: 1,
      rangePlay: 2,
      ayahDuration: duration,
    );
    expect(loop.move, MemorizationMove.rangeStart);
    expect(loop.pause, const Duration(seconds: 3));
    expect(stop.move, MemorizationMove.stop);
  });

  test(
    'last ayah without a range stops for controller to decide continuous play',
    () {
      expect(
        nextMemorizationAction(
          settings: const MemorizationSettings(),
          ayah: 5,
          ayahCount: 5,
          ayahPlay: 1,
          rangePlay: 1,
          ayahDuration: duration,
        ).move,
        MemorizationMove.stop,
      );
    },
  );
}
