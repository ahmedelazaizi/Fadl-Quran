import 'dart:io';

import 'package:fadl/core/app_state.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/devotion/fasting_tracker_screen.dart';
import 'package:fadl/screens/devotion/hijri_calendar_screen.dart';
import 'package:fadl/screens/devotion/prayer_tracker_screen.dart';
import 'package:fadl/screens/devotion/zakat_screen.dart';
import 'package:fadl/screens/more_screen.dart';
import 'package:fadl/screens/settings_screen.dart';
import 'package:fadl/screens/shell.dart';
import 'package:fadl/screens/tasbeeh_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every main screen lays out without overflow at 200% system text size
/// on a typical phone, in both UI languages.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storage;
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() async {
    storage = await Directory.systemTemp.createTemp('fadl_text_scale_');
    messenger.setMockMethodCallHandler(pathProvider, (_) async => storage.path);
  });
  tearDownAll(() async {
    messenger.setMockMethodCallHandler(pathProvider, null);
    await storage.delete(recursive: true);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final screens = <String, Widget Function()>{
    'home shell': AppShell.new,
    'more': MoreScreen.new,
    'settings': SettingsScreen.new,
    'prayer tracker': PrayerTrackerScreen.new,
    'fasting tracker': FastingTrackerScreen.new,
    'Hijri calendar': HijriCalendarScreen.new,
    'zakat': ZakatScreen.new,
    'tasbeeh': TasbeehScreen.new,
  };
  for (final lang in ['ar', 'en']) {
    for (final MapEntry(key: name, value: screen) in screens.entries) {
      testWidgets('$name fits 200% text in $lang', (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final state = AppState();
        await tester.runAsync(state.load);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: state,
            child: MaterialApp(
              locale: Locale(lang),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: screen(),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump(const Duration(milliseconds: 300));
        // Overflow is reported as a framework exception, failing the test.
        expect(tester.takeException(), isNull);
      });
    }
  }
}
