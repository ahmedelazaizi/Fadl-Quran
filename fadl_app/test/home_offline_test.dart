import 'package:fadl/core/api.dart';
import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/quran_data.dart';
import 'package:fadl/screens/home_screen.dart';
import 'package:fadl/screens/shell.dart';
import 'package:fadl/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('offline home shows the daily ayah without API errors', (
    tester,
  ) async {
    expect(Api.hasBackend, isFalse);
    final state = AppState();
    await tester.runAsync(() async {
      await state.load();
      await QuranData.load();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    // The cached mushaf future completed in the real zone; let its listeners
    // run there before pumping the rebuilt frame.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.textContaining(state.dedicatee), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('آية اليوم'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('آية اليوم'), findsOneWidget);
    expect(find.textContaining('API_BASE'), findsNothing);
    expect(find.text('إعادة المحاولة'), findsNothing);
  });

  testWidgets('offline shortcut groups expose worship actions', (tester) async {
    expect(Api.hasBackend, isFalse);
    final state = AppState();
    await tester.runAsync(state.load);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: AppShell()),
      ),
    );

    for (final heading in ['قراءة القرآن', 'الصلاة والعبادة', 'أدوات يومية']) {
      expect(find.text(heading, skipOffstage: false), findsOneWidget);
    }
    for (final shortcut in [
      'المصحف',
      'الأذكار',
      'القبلة',
      'المسبحة',
      'المواقيت',
      'متابعة الصلاة',
    ]) {
      expect(find.text(shortcut, skipOffstage: false), findsWidgets);
    }

    final offlineBody = find.byType(OfflineHomeBody);
    final qibla = find.descendant(
      of: offlineBody,
      matching: find.text('القبلة'),
    );
    final homeScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(qibla, 250, scrollable: homeScroll);
    await tester.ensureVisible(qibla);
    await tester.pump();
    await tester.tap(qibla);
    await tester.pumpAndSettle();
    expect(find.text('اتجاه القبلة'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    final tasbeeh = find.descendant(
      of: offlineBody,
      matching: find.text('المسبحة'),
    );
    await tester.scrollUntilVisible(tasbeeh, 250, scrollable: homeScroll);
    await tester.ensureVisible(tasbeeh);
    await tester.pump();
    await tester.tap(tasbeeh);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('المسبحة')),
      findsOneWidget,
    );
  });

  testWidgets('offline reciters and daily tools lead to their browsers', (
    tester,
  ) async {
    final state = AppState();
    await tester.runAsync(state.load);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: AppShell()),
      ),
    );

    final offlineBody = find.byType(OfflineHomeBody);
    final homeScroll = find.byType(Scrollable).first;
    expect(find.textContaining('استمع للقراء'), findsOneWidget);
    final reciters = find.descendant(
      of: offlineBody,
      matching: find.text('القراء'),
    );
    await tester.scrollUntilVisible(reciters, 250, scrollable: homeScroll);
    await tester.ensureVisible(reciters);
    await tester.pump();
    await tester.tap(reciters);
    await tester.pumpAndSettle();
    expect(find.text('المكتبة الصوتية'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final dailyTools = find.descendant(
      of: offlineBody,
      matching: find.textContaining('التقويم الهجري • متابعة الصيام'),
    );
    await tester.scrollUntilVisible(dailyTools, 250, scrollable: homeScroll);
    await tester.ensureVisible(dailyTools);
    await tester.pump();
    expect(find.textContaining('حاسبة الزكاة في المزيد'), findsOneWidget);
    await tester.tap(dailyTools);
    await tester.pump();
    for (final tool in ['التقويم الهجري', 'متابعة الصيام', 'حاسبة الزكاة']) {
      expect(find.text(tool), findsOneWidget);
    }
  });

  test('daily ayah is stable for a date and changes across days', () async {
    final quran = await QuranData.load();
    final today = pickDailyAyah(quran, DateTime(2026, 4, 10, 8));
    expect(
      pickDailyAyah(quran, DateTime(2026, 4, 10, 23))['key'],
      today['key'],
    );
    expect(
      pickDailyAyah(quran, DateTime(2026, 4, 11))['key'],
      isNot(today['key']),
    );
    expect((today['text'] as String).length, lessThanOrEqualTo(110));
  });

  testWidgets('offline API error shows a friendly message without retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorCard(
            message: 'x',
            error: ApiException(
              0,
              'الخادم غير مهيأ. استخدم التطبيق دون اتصال أو حدد API_BASE.',
            ),
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text(offlineFeatureMessage), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
  });

  testWidgets('other errors keep their message and retry button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorCard(
            message: 'خطأ 500',
            error: ApiException(500, 'خطأ 500'),
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('خطأ 500'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });
}
