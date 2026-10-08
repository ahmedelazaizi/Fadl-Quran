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
    expect(AppState.gpsMethodFix(gps), 'Egyptian');
    expect(AppState.gpsMethodFix({...gps, 'calcMethod': null}), 'Egyptian');
    // A choice the user made is kept.
    expect(AppState.gpsMethodFix({...gps, 'calcMethodManual': true}), isNull);
    expect(AppState.gpsMethodFix({...gps, 'calcMethod': 'Karachi'}), isNull);
    // Cities carry their own method.
    expect(AppState.gpsMethodFix({...gps, 'locationName': 'القاهرة'}), isNull);
    expect(AppState.gpsMethodFix({...gps, 'timezone': 'Asia/Riyadh'}), isNull);
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
