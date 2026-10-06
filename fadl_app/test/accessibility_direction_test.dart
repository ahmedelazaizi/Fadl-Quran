import 'package:fadl/core/app_state.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/devotion/fasting_tracker_screen.dart';
import 'package:fadl/screens/devotion/hijri_calendar_screen.dart';
import 'package:fadl/screens/devotion/prayer_tracker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> show(WidgetTester tester, Widget screen, String lang) async {
    final state = AppState();
    await tester.runAsync(() => state.load());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          locale: Locale(lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: screen,
        ),
      ),
    );
    await tester.pump();
  }

  /// Whether [icon] is drawn horizontally flipped (Flutter mirrors
  /// direction-aware icons in RTL).
  bool mirrored(WidgetTester tester, Finder icon) {
    final flips = find.descendant(of: icon, matching: find.byType(Transform));
    return flips.evaluate().any(
      (e) => (e.widget as Transform).transform.storage[0] == -1,
    );
  }

  for (final (name, screen, previous, next) in [
    ('prayer tracker', const PrayerTrackerScreen(), 'Previous day', 'Next day'),
    (
      'fasting tracker',
      const FastingTrackerScreen(),
      'Previous day',
      'Next day',
    ),
    (
      'Hijri calendar',
      const HijriCalendarScreen(),
      'Previous month',
      'Next month',
    ),
  ]) {
    testWidgets('$name tap targets are labeled and large enough', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final lang in ['en', 'ar']) {
        await show(tester, screen, lang);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      }
      handle.dispose();
    });

    testWidgets('$name previous/next arrows point the reading direction', (
      tester,
    ) async {
      await show(tester, screen, 'en');
      final back = find.descendant(
        of: find.byTooltip(previous),
        matching: find.byType(Icon),
      );
      final forward = find.descendant(
        of: find.byTooltip(next),
        matching: find.byType(Icon),
      );
      expect(tester.widget<Icon>(back).icon, Icons.chevron_left);
      expect(tester.widget<Icon>(forward).icon, Icons.chevron_right);
      expect(mirrored(tester, back), isFalse);
      // "Previous" sits at the start edge and points outward in both
      // directions: left in English, right in Arabic.
      expect(tester.getCenter(back).dx, lessThan(tester.getCenter(forward).dx));

      await show(tester, screen, 'ar');
      final arBack = find.descendant(
        of: find.byTooltip(
          previous == 'Previous day' ? 'اليوم السابق' : 'الشهر السابق',
        ),
        matching: find.byType(Icon),
      );
      final arForward = find.descendant(
        of: find.byTooltip(
          next == 'Next day' ? 'اليوم التالي' : 'الشهر التالي',
        ),
        matching: find.byType(Icon),
      );
      expect(mirrored(tester, arBack), isTrue);
      expect(
        tester.getCenter(arBack).dx,
        greaterThan(tester.getCenter(arForward).dx),
      );
    });
  }
}
