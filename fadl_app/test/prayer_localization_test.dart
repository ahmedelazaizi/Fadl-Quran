import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/offline_prayer.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/prayer/adhan_settings_screen.dart';
import 'package:fadl/screens/prayer/prayer_times_screen.dart';
import 'package:fadl/screens/prayer/qibla_screen.dart';
import 'package:fadl/screens/prayer/ramadan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> englishState(
    WidgetTester tester, {
    bool withCity = false,
  }) async {
    final state = AppState();
    await tester.runAsync(state.load);
    await state.setLanguage('en');
    if (withCity) {
      final city = presetCities.first;
      state.settings.addAll({
        'latitude': city.lat,
        'longitude': city.lng,
        'timezone': city.timezone,
        'calcMethod': city.method,
        'locationName': city.nameAr,
      });
    }
    return state;
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    AppState state,
    Widget screen,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          locale: state.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: screen,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'without location prayer screen and city picker use English LTR labels',
    (tester) async {
      final state = await englishState(tester);
      await pumpScreen(tester, state, const PrayerTimesScreen());
      expect(find.text('Prayer times'), findsOneWidget);
      expect(
        find.text('Set your location to see prayer times'),
        findsOneWidget,
      );
      expect(
        Directionality.of(tester.element(find.text('Prayer times'))),
        TextDirection.ltr,
      );
      await tester.tap(find.text('Set your location'));
      await tester.pumpAndSettle();
      expect(find.text('Use my current location (GPS)'), findsOneWidget);
      expect(find.text('Riyadh, Saudi Arabia'), findsOneWidget);
      expect(state.hasLocation, isFalse);
    },
  );

  testWidgets(
    'preset city keeps offline prayer calculation and shows English prayer and Qibla entry',
    (tester) async {
      final state = await englishState(tester, withCity: true);
      final offline = OfflinePrayer.payload(state.settings, DateTime.now());
      expect((offline['prayers'] as List).first['nameAr'], 'الفجر');
      await pumpScreen(tester, state, const PrayerTimesScreen());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Riyadh, Saudi Arabia'), findsOneWidget);
      expect(find.text('Today\'s prayer times'), findsOneWidget);
      expect(find.text('Fajr'), findsWidgets);
      expect(
        Directionality.of(tester.element(find.text('Today\'s prayer times'))),
        TextDirection.ltr,
      );
      await tester.scrollUntilVisible(find.text('Qibla compass'), 250);
      expect(find.text('Qibla compass'), findsOneWidget);
      await pumpScreen(tester, state, const QiblaScreen());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(QiblaScreen), findsOneWidget);
      expect(find.text('Qibla direction'), findsOneWidget);
      expect(find.text('Distance to Makkah'), findsOneWidget);
    },
  );

  testWidgets(
    'calculation and madhhab sheets show English labels with stable values',
    (tester) async {
      final state = await englishState(tester, withCity: true);
      await pumpScreen(tester, state, const PrayerTimesScreen());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.scrollUntilVisible(find.text('Calculation method'), 250);
      await tester.tap(find.text('Calculation method'));
      await tester.pumpAndSettle();
      expect(find.text('Umm al-Qura University, Makkah'), findsWidgets);
      expect(find.text('Egyptian General Authority of Survey'), findsOneWidget);
      expect(
        find.text('Moonsighting Committee', skipOffstage: false),
        findsOneWidget,
      );
      Navigator.of(
        tester.element(find.text('Egyptian General Authority of Survey')),
      ).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Asr school'));
      await tester.tap(find.text('Asr school'));
      await tester.pumpAndSettle();
      expect(find.text("Majority (Shafi'i, Maliki, Hanbali)"), findsWidgets);
      expect(find.text('Hanafi (later Asr)'), findsOneWidget);
      expect(state.settings['calcMethod'], 'UmmAlQura');
    },
  );

  testWidgets(
    'adhan screen displays English prayer and mode labels without hardware',
    (tester) async {
      final state = await englishState(tester);
      await pumpScreen(tester, state, const AdhanSettingsScreen());
      expect(find.text('Adhan settings'), findsOneWidget);
      expect(find.text('Alert for each prayer'), findsOneWidget);
      expect(find.text('Fajr'), findsOneWidget);
      expect(find.text('Adhan'), findsWidgets);
      expect(find.text('Notification'), findsWidgets);
      expect(find.text('Silent'), findsWidgets);
      expect(
        Directionality.of(tester.element(find.text('Fajr'))),
        TextDirection.ltr,
      );
    },
  );

  testWidgets('Ramadan without location uses English controls', (tester) async {
    final state = await englishState(tester);
    await pumpScreen(tester, state, const RamadanScreen());
    expect(find.text('Ramadan fasting timetable'), findsOneWidget);
    expect(
      find.text('Set your location to see the fasting timetable'),
      findsOneWidget,
    );
    expect(
      Directionality.of(tester.element(find.text('Ramadan fasting timetable'))),
      TextDirection.ltr,
    );
  });
}
