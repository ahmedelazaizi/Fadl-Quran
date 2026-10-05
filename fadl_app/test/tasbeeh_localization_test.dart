import 'package:fadl/core/api.dart';
import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/local_user_data.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/tasbeeh_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('English tasbeeh counts offline without changing source dhikr', (
    tester,
  ) async {
    expect(Api.hasBackend, isFalse);
    final state = AppState();
    await tester.runAsync(state.load);
    await state.setLanguage('en');
    final before = await LocalUserData.instance.tasbeehSummary();
    final first = (before['dhikrs'] as List).first as Map<String, dynamic>;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          locale: state.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const TasbeehScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Tasbeeh'), findsOneWidget);
    expect(find.text('Choose a remembrance'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Daily goal'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Daily goal'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 650));
    await tester.pump();
    expect(
      Directionality.of(tester.element(find.text('Tasbeeh'))),
      TextDirection.ltr,
    );
    final sourceText = find.text(first['text'] as String);
    expect(sourceText, findsWidgets);
    for (final text in tester.widgetList<Text>(sourceText)) {
      expect(text.textDirection, TextDirection.rtl);
    }
    final counter = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Count a remembrance, current count 0',
    );
    expect(counter, findsOneWidget);
    expect(find.text('Target: 33 times • today 0'), findsWidgets);

    await tester.tap(find.text('Vibration on'));
    await tester.pump();
    expect(find.text('Vibration off'), findsOneWidget);
    await tester.tap(counter);
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Count a remembrance, current count 1',
      ),
      findsOneWidget,
    );
    expect(find.text('Today: 1'), findsOneWidget);
    expect(find.text('Target: 33 times • today 1'), findsOneWidget);
    final after = await LocalUserData.instance.tasbeehSummary();
    final retained = (after['dhikrs'] as List).first as Map<String, dynamic>;
    expect(retained['id'], first['id']);
    expect(retained['text'], first['text']);
    expect(retained['target'], first['target']);
  });

  testWidgets('tasbeeh defaults to Arabic without localization delegate', (
    tester,
  ) async {
    final state = AppState();
    await tester.runAsync(state.load);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(locale: Locale('ar'), home: TasbeehScreen()),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('المسبحة'), findsOneWidget);
    expect(find.text('اختر الذكر'), findsOneWidget);
  });
}
