import 'package:fadl/core/adhan_service.dart';
import 'package:fadl/core/app_state.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/prayer/adhan_settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  testWidgets('every bundled muezzin can be previewed and chosen', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(AdhanService.channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'canScheduleExactAlarms' || 'isIgnoringBatteryOptimizations' => true,
        'listImported' => <Object>[],
        _ => null,
      };
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(AdhanService.channel, null),
    );
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
          home: const AdhanSettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    final makkah = find.text('Masjid al-Haram, Makkah (2013 recording)');
    await tester.scrollUntilVisible(
      makkah,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Default adhan (calm)'), findsOneWidget);
    expect(find.text("Prophet's Mosque, Madinah (recording)"), findsOneWidget);

    final preview = find.descendant(
      of: find.ancestor(of: makkah, matching: find.byType(ListTile)),
      matching: find.byTooltip('Preview'),
    );
    await tester.tap(preview);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(
      calls.where((c) => c.method == 'preview').map((c) => c.arguments),
      contains(containsPair('soundId', 'adhan_makkah')),
    );

    await tester.tap(makkah);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(state.notifications['regularSound'], 'adhan_makkah');
    expect(soundForPrayer(state.notifications, 'maghrib'), 'adhan_makkah');
    debugDefaultTargetPlatformOverride = null;
  });

  test('iOS rings the chosen clip, bundled or imported', () {
    final base = {
      'adhanModes': {'fajr': 'adhan', 'dhuhr': 'adhan', 'asr': 'notify'},
    };
    expect(iosAdhanClip(base, 'dhuhr'), 'adhan_default.caf');
    expect(iosAdhanClip(base, 'asr'), isNull);
    expect(iosAdhanClip(base, 'sunrise'), isNull);
    // Fajr has no bundled clip with the Fajr words: a short alert unless a
    // Fajr adhan was imported.
    expect(iosAdhanClip(base, 'fajr'), isNull);
    expect(
      iosAdhanClip({...base, 'fajrSound': 'fajr_1'}, 'fajr'),
      'fajr_1.caf',
    );
    expect(
      iosAdhanClip({...base, 'regularSound': 'adhan_makkah'}, 'dhuhr'),
      'adhan_makkah.caf',
    );
    // Imports live in Library/Sounds under the same ids as on Android.
    expect(
      iosAdhanClip({...base, 'regularSound': 'regular_7'}, 'dhuhr'),
      'regular_7.caf',
    );
    expect(iosAdhanClip({...base, 'enabled': false}, 'dhuhr'), isNull);
  });

  testWidgets('iOS offers muezzins and imports without Android options', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(AdhanService.channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'listImported' => [
          {'id': 'fajr_1700000000000', 'name': 'Fajr Alafasy', 'kind': 'fajr'},
        ],
        _ => null,
      };
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(AdhanService.channel, null),
    );
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
          home: const AdhanSettingsScreen(),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.textContaining('first 30 seconds'), findsOneWidget);
    // A Fajr adhan imported on this iPhone is offered for Fajr.
    await tester.scrollUntilVisible(
      find.text('Fajr Alafasy'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Fajr Alafasy'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Import Fajr adhan from phone'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final madinah = find.text("Prophet's Mosque, Madinah (recording)");
    await tester.scrollUntilVisible(
      madinah,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Import from phone'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Battery optimization'), findsNothing);

    final preview = find.descendant(
      of: find.ancestor(of: madinah, matching: find.byType(ListTile)),
      matching: find.byTooltip('Preview'),
    );
    await tester.ensureVisible(preview);
    await tester.pumpAndSettle();
    await tester.tap(preview);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(
      calls.where((c) => c.method == 'preview').map((c) => c.arguments),
      contains(containsPair('soundId', 'adhan_madinah')),
    );
    // Clips and imports only: no alarm or battery calls.
    expect(calls.map((c) => c.method).toSet(), {'listImported', 'preview'});

    final more = find.text('Open the Islamweb adhan library');
    await tester.scrollUntilVisible(
      more,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(more, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
