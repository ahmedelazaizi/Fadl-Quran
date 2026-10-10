// The mushaf on a small phone (320×640, status and navigation bars), the
// size of the CI emulator: surah title frames must fit their mushaf line
// and the juz grid cells must fit their content. Real fonts, since overflow
// depends on the Quran font's line height.

import 'dart:io';

import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/mushaf_layout.dart';
import 'package:fadl/core/quran_data.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/quran/mushaf_index_screen.dart';
import 'package:fadl/screens/quran/mushaf_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_e2e_test.dart' show loadAppFonts;

Future<void> pumpSmallPhone(WidgetTester tester, Widget home) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => Directory.systemTemp.path,
      );
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
  addTearDown(tester.view.reset);
  final state = AppState();
  await tester.runAsync(state.load);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppFonts();
    await QuranData.load();
    await MushafLayout.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Pages 1 and 2 open with a surah title frame (and basmala) line.
  for (final page in [1, 2]) {
    testWidgets('mushaf page $page fits a small phone with the bars shown', (
      tester,
    ) async {
      await pumpSmallPhone(tester, MushafReaderScreen(initialPage: page));
      expect(find.byType(Slider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('juz grid fits a small phone', (tester) async {
    await pumpSmallPhone(tester, const MushafIndexScreen());
    await tester.tap(find.text('الأجزاء'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('الجزء الأول'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
