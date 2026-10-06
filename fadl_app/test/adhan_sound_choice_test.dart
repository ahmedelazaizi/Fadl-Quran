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
}
