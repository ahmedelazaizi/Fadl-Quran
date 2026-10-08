import 'dart:io';

import 'package:fadl/core/audio_store.dart';
import 'package:fadl/core/full_surah_store.dart';
import 'package:fadl/core/offline_hadith.dart';
import 'package:fadl/core/offline_tafsir.dart';
import 'package:fadl/core/offline_tajweed.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/downloads_screen.dart';
import 'package:fadl/screens/library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory testStorage;
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() async {
    testStorage = await Directory.systemTemp.createTemp('fadl_library_l10n_');
    messenger.setMockMethodCallHandler(channel, (_) async => testStorage.path);
    // Warm the shared stores outside the widget tests' fake-async zones so a
    // later test never awaits a load started (and frozen) in an earlier one.
    SharedPreferences.setMockInitialValues({});
    await Future.wait([
      AudioStore.instance.ready(),
      FullSurahStore.instance.ready(),
      OfflineTafsir.instance.ready(),
      OfflineTajweed.instance.ready(),
      OfflineHadith.instance.ready(),
    ]);
  });
  tearDownAll(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await testStorage.delete(recursive: true);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Stores read the bundled mushaf and scan real files, so wait in real time
  // until every loading spinner is gone.
  Future<void> settleLoading(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
    }
    fail('screen kept loading');
  }

  Future<void> showEnglish(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: screen,
      ),
    );
    await settleLoading(tester);
  }

  testWidgets('empty downloads show English offline guidance in LTR', (
    tester,
  ) async {
    await showEnglish(tester, const DownloadsScreen());
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Space used'), findsOneWidget);
    expect(find.text('0 B'), findsOneWidget);
    expect(
      find.text(
        'No recitations downloaded yet.\nDownload surahs from the audio library to listen offline.',
      ),
      findsOneWidget,
    );
    expect(
      Directionality.of(tester.element(find.text('Downloads'))),
      TextDirection.ltr,
    );
  });

  testWidgets(
    'library English controls preserve Arabic titles and source notices',
    (tester) async {
      await showEnglish(tester, const LibraryScreen());
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Search the library'), findsOneWidget);
      expect(find.text('Installed'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('Library'))),
        TextDirection.ltr,
      );

      await tester.tap(find.text('Download').first);
      await tester.pumpAndSettle();
      expect(find.text('Tafsir'), findsOneWidget);
      expect(find.text('التفسير الميسر'), findsOneWidget);
      // Inspect source attribution from the visible catalog without requesting a download.
      await tester.tap(find.text('About').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('alquran.cloud API'), findsWidgets);
      expect(
        find.textContaining('https://api.alquran.cloud/v1/quran/ar.muyassar'),
        findsWidgets,
      );
      expect(
        find.textContaining('نص من واجهة alquran.cloud؛ راجع شروط المصدر.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      final book = find.text('صحيح البخاري');
      await tester.scrollUntilVisible(
        book,
        300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      expect(find.text('Hadith books'), findsOneWidget);
      expect(book, findsOneWidget);
    },
  );

  testWidgets('Arabic fallback works without localization delegates', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DownloadsScreen()));
    await settleLoading(tester);
    expect(find.text('التنزيلات'), findsOneWidget);
    expect(find.text('٠ بايت'), findsOneWidget);
    expect(find.textContaining('لا توجد تلاوات منزّلة بعد.'), findsOneWidget);
  });
}
