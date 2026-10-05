import 'dart:io';

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
  });
  tearDownAll(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await testStorage.delete(recursive: true);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> showEnglish(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: screen,
    ));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  testWidgets('empty downloads show English offline guidance in LTR', (
    tester,
  ) async {
    await showEnglish(tester, const DownloadsScreen());
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Space used'), findsOneWidget);
    expect(
      find.text('No recitations downloaded yet.\nDownload surahs from the audio library to listen offline.'),
      findsOneWidget,
    );
    expect(Directionality.of(tester.element(find.text('Downloads'))), TextDirection.ltr);
  });

  testWidgets('library English controls preserve Arabic titles and source notices', (
    tester,
  ) async {
    await showEnglish(tester, const LibraryScreen());
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Search the library'), findsOneWidget);
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Library'))), TextDirection.ltr);

    await tester.tap(find.text('Download').first);
    await tester.pumpAndSettle();
    expect(find.text('Tafsir'), findsOneWidget);
    expect(find.text('التفسير الميسر'), findsOneWidget);
    expect(find.text('Hadith books'), findsOneWidget);
    final book = find.text('صحيح البخاري');
    await tester.ensureVisible(book);
    expect(book, findsOneWidget);
    final about = find.ancestor(of: book, matching: find.byType(Card));
    // Inspect source attribution from the visible catalog without requesting a download.
    await tester.ensureVisible(find.text('About').first);
    await tester.tap(find.text('About').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('alquran.cloud API'), findsWidgets);
    expect(find.textContaining('https://api.alquran.cloud/v1/quran/ar.muyassar'), findsWidgets);
    expect(find.textContaining('نص من واجهة alquran.cloud؛ راجع شروط المصدر.'), findsOneWidget);
  });

  testWidgets('Arabic fallback works without localization delegates', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DownloadsScreen()));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(find.text('التنزيلات'), findsOneWidget);
    expect(find.textContaining('لا توجد تلاوات منزّلة بعد.'), findsOneWidget);
  });
}
