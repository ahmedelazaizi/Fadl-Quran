import 'package:fadl/core/api.dart';
import 'package:fadl/core/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'offline cold start exposes defaults without a blocking error',
    () async {
      expect(Api.hasBackend, isFalse);
      final state = AppState();
      await state.load();

      expect(state.ready, isTrue);
      expect(state.error, isNull);
      expect(state.themeMode, ThemeMode.light);
      expect(state.language, 'ar');
      expect(state.settings['fontSize'], 24);
      expect(state.reciterId, 'ar.abdulbasitmurattal');
      expect(state.dedicatee, 'فضل سليم محمد صالح');
      expect(state.settings['continuousPlay'], isTrue);
      expect(state.timezone, 'Asia/Riyadh');
      expect(state.notifications['morningAthkarTime'], '06:00');
      expect(state.notifications['adhan']['fajr'], isTrue);
    },
  );

  test('offline settings and notifications survive a new state', () async {
    final first = AppState();
    await first.load();
    await first.updateSettings({'theme': 'dark', 'fontSize': 28});
    await first.updateNotifications({
      'qiyamEnabled': true,
      'adhan': {'fajr': false},
    });
    await first.updateNotifications({
      'adhan': {'asr': true},
    });

    final restored = AppState();
    await restored.load();

    expect(restored.ready, isTrue);
    expect(restored.error, isNull);
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.settings['fontSize'], 28);
    expect(restored.settings['continuousPlay'], isTrue);
    expect(restored.notifications['qiyamEnabled'], isTrue);
    expect(restored.notifications['adhan']['fajr'], isFalse);
    expect(restored.notifications['adhan']['asr'], isTrue);
    expect(restored.notifications['adhan']['dhuhr'], isTrue);
  });

  test('UI language persists separately from backend settings', () async {
    final state = AppState();
    await state.load();
    await state.setLanguage('en');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fadl.uiLanguage'), 'en');
    expect(state.settings.containsKey('language'), isFalse);
    expect(state.settings.containsKey('locale'), isFalse);
    expect(prefs.getString('fadl.settings'), isNull);

    final restored = AppState();
    await restored.load();
    expect(restored.language, 'en');
    expect(restored.locale, const Locale('en'));
    await expectLater(restored.setLanguage('fr'), throwsArgumentError);
    expect(restored.language, 'en');
  });

  test('unknown stored language falls back to Arabic', () async {
    SharedPreferences.setMockInitialValues({'fadl.uiLanguage': 'fr'});
    final state = AppState();
    await state.load();
    expect(state.language, 'ar');
  });

  test('offline API rejects requests without waiting for a timeout', () async {
    await expectLater(Api.instance.get('/me'), throwsA(isA<ApiException>()));
  });
}
