import 'package:fadl/core/api.dart';
import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/offline_athkar.dart';
import 'package:fadl/core/quran_data.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/athkar/athkar_reader_screen.dart';
import 'package:fadl/screens/athkar/athkar_screen.dart';
import 'package:fadl/screens/dua_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> showScreen(WidgetTester tester, Widget screen) async {
    final state = AppState();
    await tester.runAsync(state.load);
    await tester.runAsync(() => state.setLanguage('en'));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: screen,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  testWidgets(
    'English Athkar searches Arabic data and reader retains progress ID',
    (tester) async {
      expect(Api.hasBackend, isFalse);
      final local = (await tester.runAsync(OfflineAthkar.load))!;
      final morning = local.category('morning')!;
      final first = (morning['items'] as List).first as Map<String, dynamic>;
      await showScreen(tester, const AthkarScreen());
      expect(find.text('Remembrances'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('Remembrances'))),
        TextDirection.ltr,
      );
      await tester.enterText(find.byType(TextField).first, 'أذكار الصباح');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('أذكار الصباح'), findsWidgets);
      await showScreen(
        tester,
        AthkarReaderScreen(
          slug: 'morning',
          title: morning['nameAr'] as String,
          initialDhikrId: first['id'] as int,
        ),
      );
      final scripture = find.text(first['text'] as String);
      expect(scripture, findsOneWidget);
      expect(tester.widget<Text>(scripture).textDirection, TextDirection.rtl);
      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
      expect(
        find.text('Remembrance 1 of ${(morning['items'] as List).length}'),
        findsOneWidget,
      );
      expect(first['amenKey'], 'dhikr:${first['id']}');
      final progress = (await tester.runAsync(
        () => OfflineAthkarStore.progress(local),
      ))!;
      expect(
        (progress['items'] as List).where(
          (entry) => entry['dhikrId'] == first['id'],
        ),
        isEmpty,
      );
    },
  );

  testWidgets('English Athkar completion retains Arabic blessing RTL', (
    tester,
  ) async {
    final local = (await tester.runAsync(OfflineAthkar.load))!;
    final category = local.categories().firstWhere(
      (entry) => entry['count'] == 1,
    );
    final dhikr =
        (local.category(category['slug'] as String)!['items'] as List).first
            as Map<String, dynamic>;
    await tester.runAsync(
      () => OfflineAthkarStore.setProgress(
        local,
        dhikr['id'] as int,
        dhikr['repeat'] as int,
      ),
    );
    await showScreen(
      tester,
      AthkarReaderScreen(
        slug: category['slug'] as String,
        title: category['nameAr'] as String,
      ),
    );
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    final blessing = find.text('تقبّل الله منك');
    expect(blessing, findsOneWidget);
    expect(tester.widget<Text>(blessing).textDirection, TextDirection.rtl);
  });

  testWidgets('English Dua controls keep Quran source and amen key unchanged', (
    tester,
  ) async {
    expect(Api.hasBackend, isFalse);
    final local = (await tester.runAsync(OfflineAthkar.load))!;
    final quran = (await tester.runAsync(QuranData.load))!;
    final parents = local.duaCollection('parents', quran)!;
    final first = (parents['items'] as List).first as Map<String, dynamic>;
    await showScreen(tester, const DuaScreen());
    expect(find.text('Prayer for a parent'), findsOneWidget);
    final mercy = find.text('رحم الله والدي');
    expect(mercy, findsOneWidget);
    expect(tester.widget<Text>(mercy).textDirection, TextDirection.rtl);
    expect(
      Directionality.of(tester.element(find.text('Prayer for a parent'))),
      TextDirection.ltr,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.drag(find.byType(ListView).first, const Offset(0, -650));
    await tester.pump();
    final scripture = find.text('﴿${first['text']}﴾');
    expect(scripture, findsOneWidget);
    expect(tester.widget<Text>(scripture).textDirection, TextDirection.rtl);
    expect(find.text('Amen 0'), findsWidgets);
    expect(find.text('Read 0/1'), findsWidgets);
    expect(first['amenKey'], 'verse:${first['verseRange']}');
    await tester.tap(find.text('Read 0/1').first);
    await tester.pump();
    final reads = (await tester.runAsync(OfflineAthkarStore.reads))!;
    expect(reads[first['amenKey']], 1);
    await tester.tap(find.text('Amen 0').first);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('آمين، تقبّل الله'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(
        'بين الأذان والإقامة، الثلث الأخير من الليل، وساعة الجمعة — أكثر فيها من الدعاء لوالدك',
      ),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    final reminder = find.text(
      'بين الأذان والإقامة، الثلث الأخير من الليل، وساعة الجمعة — أكثر فيها من الدعاء لوالدك',
    );
    expect(reminder, findsOneWidget);
    expect(tester.widget<Text>(reminder).textDirection, TextDirection.rtl);
  });
}
