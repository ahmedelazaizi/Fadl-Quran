import 'package:fadl/core/adhan_service.dart';
import 'package:fadl/core/app_state.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/prayer/adhan_settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pluginChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  testWidgets('missing exact-alarm access is explained, opens system '
      'settings, and re-arms alarms once granted', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    var exact = false;
    final adhanCalls = <String>[];
    messenger.setMockMethodCallHandler(AdhanService.channel, (call) async {
      adhanCalls.add(call.method);
      return switch (call.method) {
        'canScheduleExactAlarms' => exact,
        'isIgnoringBatteryOptimizations' => true,
        'listImported' => <Object>[],
        _ => null,
      };
    });
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final pluginCalls = <String>[];
    messenger.setMockMethodCallHandler(_pluginChannel, (call) async {
      pluginCalls.add(call.method);
      return switch (call.method) {
        'initialize' || 'requestNotificationsPermission' => true,
        'canScheduleExactNotifications' => exact,
        _ => null,
      };
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(AdhanService.channel, null);
      messenger.setMockMethodCallHandler(_pluginChannel, null);
    });

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

    final allow = find.text('Allow exact alarms');
    await tester.scrollUntilVisible(
      allow,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('The adhan may be delayed by several minutes'),
      findsOneWidget,
    );
    await tester.ensureVisible(allow);
    await tester.pumpAndSettle();
    await tester.tap(allow);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(adhanCalls, contains('openExactAlarmSettings'));

    // The user grants access in system settings and returns.
    exact = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0; i < 20 && !pluginCalls.contains('cancelAll'); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      find.text('The adhan can sound at the exact minute of prayer'),
      findsOneWidget,
    );
    expect(allow, findsNothing);
    expect(pluginCalls, contains('cancelAll'));
    debugDefaultTargetPlatformOverride = null;
  });
}
