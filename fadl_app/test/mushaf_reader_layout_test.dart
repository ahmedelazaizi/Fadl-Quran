import 'dart:io';

import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/mushaf_layout.dart';
import 'package:fadl/core/quran_data.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/quran/mushaf_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lets the panels report their heights, then the page padding animate.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await QuranData.load();
    await MushafLayout.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('mushaf lines stay clear of the notch and the floating bars', (
    tester,
  ) async {
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      pathChannel,
      (call) async => '${Directory.systemTemp.path}/fadl_mushaf_layout_test',
    );
    addTearDown(() => messenger.setMockMethodCallHandler(pathChannel, null));
    // A 1080×2400 phone with a 40 px notch and a gesture bar.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 120, bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(top: 120, bottom: 48);
    addTearDown(tester.view.reset);

    final state = AppState();
    await tester.runAsync(state.load);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MushafReaderScreen(initialPage: 3),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(tester);

    final page = find.byType(PageView);
    final back = find.byIcon(Icons.arrow_back_rounded);
    final slider = find.byType(Slider);
    expect(back, findsOneWidget);
    expect(slider, findsOneWidget);
    // Chrome shown: the page sits between the top bar and the bottom panels.
    final topBarBottom = tester.getBottomLeft(back).dy;
    final bottomPanelsTop = tester.getTopLeft(slider).dy;
    expect(tester.getTopLeft(page).dy, greaterThanOrEqualTo(topBarBottom));
    expect(tester.getBottomLeft(page).dy, lessThanOrEqualTo(bottomPanelsTop));

    // Chrome hidden: the page fills the screen but stays below the notch.
    // The page margin, beside the lines, toggles the bars.
    await tester.tapAt(
      Offset(tester.getTopLeft(page).dx + 4, tester.getCenter(page).dy),
    );
    await settle(tester);
    expect(back, findsNothing);
    expect(tester.getTopLeft(page).dy, 40);
    expect(tester.getBottomLeft(page).dy, 800 - 16);
  });
}
