import 'package:fadl/core/app_state.dart';
import 'package:fadl/screens/more_screen.dart';
import 'package:fadl/screens/devotion/prayer_tracker_screen.dart';
import 'package:fadl/core/worship_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('more menu opens worship screens and edits zakat inputs', (
    tester,
  ) async {
    final state = AppState();
    await tester.runAsync(() => state.load());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: MoreScreen()),
      ),
    );
    expect(find.text('متابعة الصلاة'), findsOneWidget);
    expect(find.text('التقويم الهجري'), findsOneWidget);
    expect(find.text('متابعة الصيام'), findsOneWidget);
    expect(find.text('حاسبة الزكاة'), findsOneWidget);
    await tester.tap(find.text('حاسبة الزكاة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'النقد'), '8500');
    await tester.enterText(
      find.widgetWithText(TextField, 'سعر غرام الذهب'),
      '100',
    );
    await tester.pump();
    tester.testTextInput.hide();
    await tester.scrollUntilVisible(
      find.text('الزكاة التقديرية (٢٫٥٪)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('212.50'), findsOneWidget);
  });

  testWidgets('prayer tracker records a chosen status from the screen', (
    tester,
  ) async {
    final state = AppState();
    await tester.runAsync(() => state.load());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: PrayerTrackerScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('تسجيل الفجر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فائتة').last);
    await tester.pump();
    expect((await WorshipStore().qada())['fajr'], 1);
  });
}
