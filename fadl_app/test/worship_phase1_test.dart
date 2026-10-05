import 'package:fadl/core/offline_prayer.dart';
import 'package:fadl/core/worship_calendar.dart';
import 'package:fadl/core/worship_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'prayer records persist; missed transitions increment only once',
    () async {
      final store = WorshipStore();
      await store.setPrayer('2026-04-20', 'fajr', 'missed');
      await store.setPrayer('2026-04-20', 'fajr', 'missed');
      expect((await WorshipStore().prayers())['2026-04-20/fajr'], 'missed');
      expect((await store.qada())['fajr'], 1);
      await store.setPrayer('2026-04-20', 'fajr', 'onTime');
      expect((await store.qada())['fajr'], 1);
      await store.adjustQada('fajr', -1);
      await store.adjustQada('fajr', -1);
      expect((await WorshipStore().qada())['fajr'], 0);
    },
  );

  test('weekly and monthly ranges exclude adjacent records', () async {
    final store = WorshipStore();
    await store.setPrayer('2026-04-05', 'fajr', 'late');
    await store.setPrayer('2026-04-06', 'fajr', 'onTime');
    await store.setPrayer('2026-04-30', 'isha', 'missed');
    await store.setPrayer('2026-05-01', 'fajr', 'missed');
    expect(
      (await store.prayerStats(
        DateTime.utc(2026, 4, 6),
        DateTime.utc(2026, 4, 12),
      ))['onTime'],
      1,
    );
    expect(
      (await store.prayerStats(
        DateTime.utc(2026, 4),
        DateTime.utc(2026, 4, 30),
      ))['missed'],
      1,
    );
  });

  test('prayer JSON roundtrip preserves manually adjusted qada', () async {
    final store = WorshipStore();
    await store.setPrayer('2026-04-20', 'fajr', 'missed');
    await store.adjustQada('fajr', -1);
    final exported = await store.exportPrayers();
    SharedPreferences.setMockInitialValues({});
    await WorshipStore().importPrayers(exported);
    expect((await store.qada())['fajr'], 0);
    expect((await store.prayers())['2026-04-20/fajr'], 'missed');
  });

  test(
    'fasting types and notes persist and year boundaries count correctly',
    () async {
      final store = WorshipStore();
      await store.setFast('2026-12-31', 'makeup', notes: 'ملاحظة');
      await store.setFast('2027-01-01', 'voluntary');
      expect((await WorshipStore().fasts())['2026-12-31']!['notes'], 'ملاحظة');
      expect((await store.fastingYear(2026))['makeup'], 1);
      expect((await store.fastingYear(2026))['voluntary'], 0);
      await store.adjustRamadanQada(2);
      expect(await WorshipStore().ramadanQada(), 2);
    },
  );

  test('calendar event shifts with adjustment across Hijri boundary', () {
    final date = DateTime.utc(2026, 3, 1);
    final current = OfflinePrayer.hijri(date, 1);
    final tomorrow = OfflinePrayer.hijri(date.add(const Duration(days: 1)));
    expect(current['formattedAr'], tomorrow['formattedAr']);
    final eid = DateTime.utc(2026, 3, 20);
    for (final shift in [-1, 0, 1]) {
      expect(
        hijriOccasions(eid, shift).contains('عيد الفطر'),
        OfflinePrayer.hijri(eid, shift)['month'] == 10 &&
            OfflinePrayer.hijri(eid, shift)['day'] == 1,
      );
    }
    expect(hijriOccasions(DateTime.utc(2026, 4, 20), 0), contains('الاثنين'));
  });

  test('local date follows selected timezone across midnight', () {
    expect(
      selectedLocalDate('Asia/Riyadh', DateTime.utc(2026, 4, 19, 22)),
      '2026-04-20',
    );
    expect(
      selectedLocalDate('America/New_York', DateTime.utc(2026, 4, 20, 1)),
      '2026-04-19',
    );
  });

  test('zakat uses selected gold or silver nisab and inclusive threshold', () {
    ZakatBreakdown calc(double cash, bool gold) => ZakatBreakdown(
      cash: cash,
      goldGrams: 0,
      silverGrams: 0,
      goldPrice: 100,
      silverPrice: 10,
      inventory: 0,
      receivables: 0,
      useGoldNisab: gold,
    );
    expect(calc(8499, true).due, 0);
    expect(calc(8500, true).due, 212.5);
    expect(calc(8501, true).due, closeTo(212.525, 0.0001));
    expect(calc(6000, false).due, 150);
    expect(calc(6000, true).due, 0);
    expect(calc(5950, false).due, 148.75);
  });
}
