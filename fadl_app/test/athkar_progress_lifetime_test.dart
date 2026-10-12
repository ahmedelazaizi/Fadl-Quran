import 'package:fadl/core/offline_athkar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OfflineAthkar athkar;
  late int id;
  late int repeat;

  setUpAll(() async {
    athkar = await OfflineAthkar.load();
    final dhikr = (athkar.category('morning')!['items'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((d) => (d['repeat'] as int) > 1);
    id = dhikr['id'] as int;
    repeat = dhikr['repeat'] as int;
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<int> countAt(DateTime now) async {
    final items =
        (await OfflineAthkarStore.progress(athkar, now: now))['items'] as List;
    return items
                .cast<Map<String, dynamic>>()
                .where((i) => i['dhikrId'] == id)
                .firstOrNull?['count']
            as int? ??
        0;
  }

  test(
    'a finished dhikr stays finished for 24 hours, across midnight',
    () async {
      final done = DateTime(2026, 10, 12, 20);
      await OfflineAthkarStore.setProgress(athkar, id, repeat, now: done);
      // Next morning, after midnight: still finished.
      expect(await countAt(done.add(const Duration(hours: 10))), repeat);
      // More rounds later do not extend the 24 hours.
      await OfflineAthkarStore.setProgress(
        athkar,
        id,
        repeat * 2,
        now: done.add(const Duration(hours: 12)),
      );
      expect(
        await countAt(done.add(const Duration(hours: 23, minutes: 59))),
        repeat * 2,
      );
      // 24 hours after it was finished it starts again from zero.
      expect(await countAt(done.add(const Duration(hours: 24))), 0);
    },
  );

  test('an unfinished count is kept for 24 hours after the last tap', () async {
    final tap = DateTime(2026, 10, 12, 9);
    await OfflineAthkarStore.setProgress(athkar, id, repeat - 1, now: tap);
    expect(await countAt(tap.add(const Duration(hours: 23))), repeat - 1);
    expect(await countAt(tap.add(const Duration(hours: 24))), 0);
  });

  test("today's counts from the old day-based store carry over", () async {
    SharedPreferences.setMockInitialValues({
      OfflineAthkarStore.legacyProgressKey:
          '{"date":"2026-10-12","counts":{"$id":$repeat}}',
    });
    final now = DateTime(2026, 10, 12, 15);
    expect(await countAt(now), repeat);
    expect(await countAt(now.add(const Duration(hours: 24))), 0);
  });
}
