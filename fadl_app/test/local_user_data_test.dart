import 'package:fadl/core/local_user_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  LocalUserData data() => LocalUserData(clock: () => now);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2025, 3, 10, 9);
  });

  test('tasbeeh dhikrs and daily counts persist and reset', () async {
    var summary = await data().tasbeehSummary();
    final dhikrs = summary['dhikrs'] as List;
    expect(dhikrs, hasLength(LocalUserData.defaultDhikrs.length));
    final first = (dhikrs.first as Map)['id'] as String;

    await data().addTasbeehCounts({first: 40});
    final added = await data().addDhikr('  لا حول ولا قوة إلا بالله ', 0);
    expect(added['target'], 1);
    await data().updateDhikr(added['id'] as String, target: 10);
    summary = await data().addTasbeehCounts({added['id'] as String: 3});

    expect(summary['todayTotal'], 43);
    expect(summary['streakDays'], 1);
    final firstRow = (summary['dhikrs'] as List).first as Map;
    expect(firstRow['todayCount'], 40);
    expect(firstRow['rounds'], 1);
    expect(firstRow['remainingInRound'], 33 - 40 % 33);

    // Yesterday's counts stay in the week and extend the streak.
    now = now.add(const Duration(days: 1));
    await data().addTasbeehCounts({first: 1});
    summary = await data().tasbeehSummary();
    expect(summary['streakDays'], 2);
    expect((summary['week'] as List).map((d) => (d as Map)['total']).toList(), [
      0,
      0,
      0,
      0,
      0,
      43,
      1,
    ]);

    await data().resetTasbeehToday(first);
    await data().deleteDhikr(added['id'] as String);
    summary = await data().tasbeehSummary();
    expect(summary['todayTotal'], 0);
    expect(
      (summary['dhikrs'] as List).map((d) => (d as Map)['id']),
      isNot(contains(added['id'])),
    );
  });

  test('khatma plan records progress, logs and archives', () async {
    expect(LocalUserData.khatmaPresets.first['pagesPerDay'], 21);
    final plan = await data().createKhatma(
      preset: '30-days',
      reminderTime: '05:30',
      dedicated: true,
    );
    expect(plan['today'], containsPair('target', 21));
    expect((plan['position'] as Map)['page'], 1);
    expect((plan['position'] as Map)['surahNameAr'], isNotEmpty);

    final id = plan['id'] as String;
    var result = await data().recordKhatma(id, pages: 5);
    expect(result['recordedPages'], 5);
    result = await data().recordKhatma(id, toPage: 21);
    final updated = result['plan'] as Map;
    expect(updated['pagesRead'], 21);
    expect((updated['today'] as Map)['done'], isTrue);
    await expectLater(
      data().recordKhatma(id, toPage: 10),
      throwsA(isA<LocalDataException>()),
    );

    final days = await data().khatmaLogs(id);
    expect(days.single['pages'], 21);
    expect(days.single['entries'], hasLength(2));

    final patched = await data().patchKhatma(id, {'reminderTime': null});
    expect(patched['reminderTime'], isNull);
    expect(await data().khatmas(status: 'ACTIVE'), hasLength(1));

    await data().createKhatma(preset: '7-days');
    final active = await data().khatmas(status: 'ACTIVE');
    expect(active.single['title'], 'ختمة في أسبوع');
    expect(await data().khatmas(status: 'ARCHIVED'), hasLength(1));
  });

  test('completing a khatma marks it completed', () async {
    final plan = await data().createKhatma(preset: '7-days');
    final result = await data().recordKhatma(plan['id'] as String, pages: 700);
    expect(result['recordedPages'], 604);
    expect(result['completed'], isTrue);
    expect((result['plan'] as Map)['status'], 'COMPLETED');
    expect(await data().khatmas(status: 'ACTIVE'), isEmpty);
  });

  test('bookmarks are saved, listed newest first and removed', () async {
    await data().addBookmark('2:255');
    now = now.add(const Duration(minutes: 1));
    await data().addBookmark('18:10', note: 'الكهف');
    expect((await data().bookmarks()).map((b) => b['ayahKey']), [
      '18:10',
      '2:255',
    ]);
    expect(await data().isBookmarked('2:255'), isTrue);
    await expectLater(
      data().addBookmark('bad'),
      throwsA(isA<LocalDataException>()),
    );

    await data().removeBookmark('2:255');
    expect(await data().isBookmarked('2:255'), isFalse);

    await data().clearAll();
    expect(await data().bookmarks(), isEmpty);
  });
}
