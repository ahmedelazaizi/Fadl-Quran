import 'dart:io';

import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/mushaf_layout.dart';
import 'package:fadl/core/quran_data.dart';
import 'package:fadl/core/quran_storage.dart';
import 'package:fadl/main.dart';
import 'package:fadl/screens/quran/audio_library_screen.dart';
import 'package:fadl/screens/quran/mushaf_index_screen.dart';
import 'package:fadl/screens/quran/mushaf_reader_screen.dart';
import 'package:fadl/screens/quran/quran_learning_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await QuranData.load();
    await QuranIndex.surahs();
    await MushafLayout.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('language selector changes locale, direction and navigation', (
    tester,
  ) async {
    final state = AppState();
    await tester.runAsync(state.load);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const FadlApp()),
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('ar'),
    );
    expect(
      Directionality.of(tester.element(find.text('الرئيسية'))),
      TextDirection.rtl,
    );
    expect(find.text('قراءة القرآن', skipOffstage: false), findsOneWidget);

    await state.setLanguage('en');
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('en'),
    );
    expect(
      Directionality.of(tester.element(find.text('Home'))),
      TextDirection.ltr,
    );
    expect(find.text('Read the Quran', skipOffstage: false), findsOneWidget);
    expect(find.text('Reciters', skipOffstage: false), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('App language'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arabic').last);
    await tester.pumpAndSettle();
    expect(state.language, 'ar');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('ar'),
    );
    expect(find.text('لغة التطبيق'), findsOneWidget);
  });

  testWidgets('English reciter shortcut opens the audio library', (
    tester,
  ) async {
    final state = AppState();
    await tester.runAsync(state.load);
    await state.setLanguage('en');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const FadlApp()),
    );
    final reciters = find.text('Reciters');
    await tester.scrollUntilVisible(
      reciters,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(reciters);
    await tester.pumpAndSettle();
    expect(find.byType(AudioLibraryScreen), findsOneWidget);
    expect(find.text('Audio library'), findsOneWidget);
    expect(
      find.text('Verse-by-verse recitation — synchronized verses'),
      findsOneWidget,
    );
  });

  testWidgets('English shell opens LTR Mushaf quiz with RTL Quran text', (
    tester,
  ) async {
    final state = AppState();
    await tester.runAsync(state.load);
    await state.setLanguage('en');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const FadlApp()),
    );
    final shortcut = find.text('Mushaf').last;
    await tester.scrollUntilVisible(
      shortcut,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(shortcut);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MushafIndexScreen), findsOneWidget);
    expect(find.text('Surahs'), findsOneWidget);
    expect(find.text('Juz'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Surahs'))),
      TextDirection.ltr,
    );

    await tester.tap(find.text('Quran memorization quiz • Review pages'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () async => await Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.byType(QuranLearningScreen), findsOneWidget);
    expect(find.text('Quiz type'), findsOneWidget);
    expect(find.text('Complete the next verse'), findsOneWidget);
    expect(find.text('Show answer'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Quiz type'))),
      TextDirection.ltr,
    );
    final ayah = tester.widget<SelectableText>(
      find.byType(SelectableText).first,
    );
    expect(ayah.textDirection, TextDirection.rtl);
    await tester.tap(find.text('Show answer'));
    await tester.pump();
    expect(find.text('Answer'), findsOneWidget);
  });

  testWidgets('English reader keeps its controls LTR and Mushaf ayahs RTL', (
    tester,
  ) async {
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      pathChannel,
      (call) async =>
          '${Directory.systemTemp.path}/fadl_localization_reader_test',
    );
    addTearDown(() => messenger.setMockMethodCallHandler(pathChannel, null));
    final state = AppState();
    await tester.runAsync(state.load);
    await state.setLanguage('en');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const FadlApp()),
    );
    final shortcut = find.text('Mushaf').last;
    await tester.scrollUntilVisible(
      shortcut,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(shortcut);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MushafIndexScreen), findsOneWidget);
    await tester.runAsync(
      () async => await Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.textContaining('Surah '), findsWidgets);
    await tester.tap(find.textContaining('Surah ').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () async => await Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.byType(MushafReaderScreen), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byTooltip('Back'))),
      TextDirection.ltr,
    );
    final pages = find.descendant(
      of: find.byType(MushafReaderScreen),
      matching: find.byType(PageView),
    );
    expect(pages, findsOneWidget);
    expect(Directionality.of(tester.element(pages)), TextDirection.rtl);
    final ayahs = find.descendant(
      of: pages,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.textSpan != null &&
            widget.textSpan!.toPlainText().trim().isNotEmpty,
      ),
    );
    expect(ayahs, findsWidgets);
    expect(tester.widget<Text>(ayahs.first).textDirection, TextDirection.rtl);
    expect(Directionality.of(tester.element(ayahs.first)), TextDirection.rtl);
  });
}
