import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/offline_prayer.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/prayer/prayer_settings_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const cairo = {
    'latitude': 30.0444,
    'longitude': 31.2357,
    'timezone': 'Africa/Cairo',
  };

  test('the method follows the country of the time zone', () {
    expect(methodForTimezone('Africa/Cairo'), 'Egyptian');
    expect(methodForTimezone('Asia/Riyadh'), 'UmmAlQura');
    expect(methodForTimezone('Asia/Kuwait'), 'Kuwait');
    expect(methodForTimezone('Europe/Istanbul'), 'Turkey');
    expect(methodForTimezone('Asia/Amman'), 'Jordan');
    expect(methodForTimezone('America/New_York'), 'NorthAmerica');
    expect(methodForTimezone('Europe/London'), 'MuslimWorldLeague');
    expect(methodForTimezone('UTC'), isNull);
    for (final method in [
      'Egyptian',
      'UmmAlQura',
      'Kuwait',
      'Qatar',
      'Dubai',
      'Karachi',
      'Turkey',
      'Tehran',
      'Singapore',
      'NorthAmerica',
      'MuslimWorldLeague',
    ]) {
      expect(calcMethods, contains(method));
    }
  });

  test('GPS users left on the old default get their country method', () {
    final gps = {
      ...cairo,
      'locationName': AppState.gpsLocationName,
      'calcMethod': 'UmmAlQura',
    };
    expect(AppState.countryMethodFix(gps), 'Egyptian');
    expect(AppState.countryMethodFix({...gps, 'calcMethod': null}), 'Egyptian');
    // A choice the user made is kept.
    expect(
      AppState.countryMethodFix({...gps, 'calcMethodManual': true}),
      isNull,
    );
    expect(
      AppState.countryMethodFix({...gps, 'calcMethod': 'Karachi'}),
      isNull,
    );
    // Cities carry their own method.
    expect(
      AppState.countryMethodFix({...gps, 'locationName': 'القاهرة'}),
      isNull,
    );
    expect(
      AppState.countryMethodFix({...gps, 'timezone': 'Asia/Riyadh'}),
      isNull,
    );
  });

  test('Jordan gets the Awqaf method, also for saved locations', () {
    const amman = {
      'latitude': 31.9454,
      'longitude': 35.9284,
      'timezone': 'Asia/Amman',
    };
    // Saved by an older version on the generic fallback: upgraded.
    expect(
      AppState.countryMethodFix({
        ...amman,
        'locationName': 'عمّان، الأردن',
        'calcMethod': 'MuslimWorldLeague',
      }),
      'Jordan',
    );
    expect(
      AppState.countryMethodFix({
        ...amman,
        'locationName': AppState.gpsLocationName,
        'calcMethod': 'MuslimWorldLeague',
      }),
      'Jordan',
    );
    // A method the user picked is kept.
    expect(
      AppState.countryMethodFix({
        ...amman,
        'calcMethod': 'MuslimWorldLeague',
        'calcMethodManual': true,
      }),
      isNull,
    );
    // Elsewhere, Muslim World League stays.
    expect(
      AppState.countryMethodFix({
        ...cairo,
        'locationName': 'القاهرة',
        'calcMethod': 'MuslimWorldLeague',
      }),
      isNull,
    );
  });

  test('Jordan times match the Awqaf calendar (Aladhan method 23)', () {
    // Amman, from api.aladhan.com/v1/timings?method=23, local time (UTC+3).
    const amman = {
      'latitude': 31.9454,
      'longitude': 35.9284,
      'timezone': 'Asia/Amman',
      'calcMethod': 'Jordan',
    };
    final expected = {
      DateTime.utc(2026, 10, 12): {
        'fajr': '05:16',
        'sunrise': '06:37',
        'dhuhr': '12:23',
        'asr': '15:40',
        'maghrib': '18:13',
        'isha': '19:29',
      },
      DateTime.utc(2027, 1, 15): {
        'fajr': '06:11',
        'sunrise': '07:37',
        'dhuhr': '12:46',
        'asr': '15:35',
        'maghrib': '17:59',
        'isha': '19:20',
      },
    };
    for (final MapEntry(key: date, value: times) in expected.entries) {
      for (final p in OfflinePrayer.day(amman, date)['prayers'] as List) {
        final local = DateTime.parse(
          p['time'] as String,
        ).toUtc().add(const Duration(hours: 3));
        final want = (times[p['name']]!).split(':').map(int.parse).toList();
        final minutes = local.hour * 60 + local.minute - want[0] * 60 - want[1];
        // Both round to the minute, differently.
        expect(
          minutes.abs(),
          lessThanOrEqualTo(1),
          reason: '$date ${p['name']}',
        );
      }
    }
  });

  test('a stored GPS location is fixed on load', () async {
    SharedPreferences.setMockInitialValues({
      'fadl.settings':
          '{"latitude":30.0444,"longitude":31.2357,"timezone":"Africa/Cairo",'
          '"locationName":"موقعي الحالي","calcMethod":"UmmAlQura"}',
    });
    final state = AppState();
    await state.load();
    expect(state.settings['calcMethod'], 'Egyptian');
  });

  test('minute adjustments move each prayer by exactly that much', () {
    final date = DateTime.utc(2026, 10, 8);
    Map<String, DateTime> times(Map<String, dynamic> settings) => {
      for (final p in OfflinePrayer.day(settings, date)['prayers'] as List)
        p['name'] as String: DateTime.parse(p['time'] as String),
    };
    final base = times({...cairo, 'calcMethod': 'Egyptian'});
    final shifted = times({
      ...cairo,
      'calcMethod': 'Egyptian',
      'adjustments': {'fajr': 2, 'maghrib': -1},
    });
    expect(shifted['fajr']!.difference(base['fajr']!).inMinutes, 2);
    expect(shifted['maghrib']!.difference(base['maghrib']!).inMinutes, -1);
    expect(shifted['dhuhr'], base['dhuhr']);
  });

  testWidgets('the adjustments sheet saves a shift and resets it', (
    tester,
  ) async {
    final state = AppState();
    await tester.runAsync(state.load);
    await state.updateSettings({...cairo, 'calcMethod': 'Egyptian'});
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTimeAdjustmentsSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('تعديل الأوقات يدويًا'), findsOneWidget);

    final later = find.byTooltip('بعد بدقيقة');
    await tester.tap(later.first);
    await tester.pump();
    await tester.tap(later.first);
    await tester.pump();
    expect((state.settings['adjustments'] as Map)['fajr'], 2);
    expect(find.text('+٢ د'), findsOneWidget);

    await tester.tap(find.text('إعادة الضبط'));
    await tester.pump();
    expect(state.settings['adjustments'], isEmpty);
  });
}
