import 'dart:io';

import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/offline_hadith.dart';
import 'package:fadl/core/offline_prayer.dart';
import 'package:fadl/core/worship_calendar.dart';
import 'package:fadl/core/worship_store.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/devotion/fasting_tracker_screen.dart';
import 'package:fadl/screens/devotion/hijri_calendar_screen.dart';
import 'package:fadl/screens/devotion/prayer_tracker_screen.dart';
import 'package:fadl/screens/devotion/zakat_screen.dart';

import 'package:fadl/screens/hadith/hadith_books_screen.dart';
import 'package:fadl/screens/hadith/hadith_card.dart';
import 'package:fadl/screens/hadith/hadith_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> showScreen(WidgetTester tester, Widget screen) async {
    final state = AppState();
    await tester.runAsync(state.load);
    await state.setLanguage('en');
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
    return state;
  }

  testWidgets('English prayer selection stores the unchanged status ID', (
    tester,
  ) async {
    await showScreen(tester, const PrayerTrackerScreen());
    expect(find.text('Prayer and make-up tracker'), findsOneWidget);
    expect(
      Directionality.of(
        tester.element(find.text('Prayer and make-up tracker')),
      ),
      TextDirection.ltr,
    );
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('On time').last);
    await tester.pumpAndSettle();
    expect((await WorshipStore().prayers()).values, contains('onTime'));
  });

  testWidgets('English fasting controls retain the stored fasting type', (
    tester,
  ) async {
    await showScreen(tester, const FastingTrackerScreen());
    expect(find.text('Fasting tracker'), findsOneWidget);
    await tester.tap(find.text('No fast recorded'));
    await tester.pumpAndSettle();
    expect(find.text('Type of fast'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ramadan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await WorshipStore().fasts()).values.first['type'], 'ramadan');
  });

  testWidgets('English zakat labels keep price preference keys', (
    tester,
  ) async {
    await showScreen(tester, const ZakatScreen());
    await tester.pumpAndSettle();
    expect(find.text('Zakat calculator'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Gold price per gram'),
      '12',
    );
    await tester.pump();
    expect(
      (await SharedPreferences.getInstance()).getString('fadl.zakat.goldPrice'),
      '12',
    );
  });

  testWidgets('English calendar labels a source white-day occasion', (
    tester,
  ) async {
    final state = await showScreen(tester, const HijriCalendarScreen());
    final today = OfflinePrayer.today(state.timezone, DateTime.now());
    final days = DateTime.utc(today.year, today.month + 1, 0).day;
    final occasionDay = [
      for (var day = 1; day <= days; day++)
        DateTime.utc(today.year, today.month, day),
    ].firstWhere((day) => hijriOccasions(day, 0).contains('الأيام البيض'));
    final dayCell = find.descendant(
      of: find.byType(GridView),
      matching: find.text('${occasionDay.day}'),
    );
    await tester.ensureVisible(dayCell);
    await tester.tap(dayCell);
    await tester.pumpAndSettle();
    expect(find.text('White days', skipOffstage: false), findsWidgets);
    expect(find.text('الأيام البيض'), findsNothing);
  });

  testWidgets(
    'offline hadith library localizes group and search prompt without network',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => '${Directory.systemTemp.path}/fadl_hadith_ui_test',
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.runAsync(OfflineHadith.instance.ready);
      await showScreen(tester, const HadithBooksScreen());
      await tester.runAsync(() => OfflineHadith.instance.size('bukhari'));
      await tester.pump();
      expect(find.text('Hadith library'), findsOneWidget);
      expect(find.text('Search hadith texts...'), findsOneWidget);
      expect(find.text('The Nine Books'), findsOneWidget);
      expect(find.text('الكتب التسعة'), findsNothing);
      expect(
        Directionality.of(tester.element(find.text('Hadith library'))),
        TextDirection.ltr,
      );
    },
  );

  testWidgets(
    'hadith card opens English controls with unchanged Arabic source',
    (tester) async {
      final hadith = <String, dynamic>{
        'textAr': 'نص الحديث الأصلي',
        'reference': 'مرجع أصلي',
        'book': <String, dynamic>{'nameAr': 'اسم الكتاب الأصلي'},
        'links': <String, dynamic>{},
      };
      await showScreen(tester, Scaffold(body: HadithCard(hadith: hadith)));
      expect(find.text('نص الحديث الأصلي'), findsOneWidget);
      expect(find.text('Not specified'), findsOneWidget);
      await tester.tap(find.text('نص الحديث الأصلي'));
      await tester.pumpAndSettle();
      expect(find.byType(HadithDetailScreen), findsOneWidget);
      expect(
        find.text('Grade not specified by the source — verify via Dorar'),
        findsOneWidget,
      );
      expect(find.text('Copy'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('Copy'))),
        TextDirection.ltr,
      );
      expect(find.text('نص الحديث الأصلي'), findsOneWidget);
    },
  );

  testWidgets('legacy Arabic material app keeps Arabic hadith navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HadithCard(
            hadith: {'textAr': 'نص محفوظ', 'reference': 'مرجع محفوظ'},
          ),
        ),
      ),
    );
    expect(find.text('غير محدد'), findsOneWidget);
    await tester.tap(find.text('نص محفوظ'));
    await tester.pumpAndSettle();
    expect(find.text('نسخ'), findsOneWidget);
  });
}
