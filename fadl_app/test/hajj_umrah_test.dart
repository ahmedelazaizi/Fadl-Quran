import 'package:fadl/core/hajj_umrah.dart';
import 'package:fadl/screens/hajj_umrah_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('content', () {
    for (final guide in riteGuides) {
      test('${guide.id}: unique step ids and sourced supplications', () {
        final ids = [for (final step in guide.steps) step.id];
        expect(ids.toSet().length, ids.length);
        for (final step in guide.steps) {
          expect(step.title, isNotEmpty);
          expect(step.details, isNotEmpty, reason: step.id);
          for (final dua in step.duas) {
            expect(dua.text.trim(), isNotEmpty, reason: step.id);
            expect(dua.source.trim(), isNotEmpty, reason: step.id);
          }
          for (final (label, counter) in step.counters) {
            expect(label, isNotEmpty);
            expect(counter.total, 7);
            expect(counter.hint?.call(1), anyOf(isNull, isNotEmpty));
          }
        }
      });
    }

    test('the jamarat day has three seven-pebble counters', () {
      final tashreeq = hajjGuide.steps.firstWhere((s) => s.id == 'tashreeq');
      expect(tashreeq.counters, hasLength(3));
    });
  });

  group('RiteProgress', () {
    test('counts within 0..total and persists per guide', () async {
      final prefs = await SharedPreferences.getInstance();
      final umrah = RiteProgress(prefs, umrahGuide);
      final step = umrahGuide.steps.firstWhere((s) => s.counters.isNotEmpty);

      expect(umrah.started, isFalse);
      expect(await umrah.add(step, 0, -1), 0);
      for (var i = 0; i < 9; i++) {
        await umrah.add(step, 0, 1);
      }
      expect(umrah.count(step, 0), 7);
      expect(await umrah.add(step, 0, -1), 6);

      // Hajj reuses the tawaf step id but keeps its own tally.
      expect(RiteProgress(prefs, hajjGuide).count(step, 0), 0);
      expect(RiteProgress(prefs, umrahGuide).count(step, 0), 6);

      await umrah.reset(step, 0);
      expect(umrah.count(step, 0), 0);
    });

    test('step is clamped and restart forgets everything', () async {
      final prefs = await SharedPreferences.getInstance();
      final umrah = RiteProgress(prefs, umrahGuide);
      final step = umrahGuide.steps.firstWhere((s) => s.counters.isNotEmpty);

      await umrah.setStep(99);
      expect(umrah.step, umrahGuide.steps.length - 1);
      expect(umrah.started, isTrue);
      await umrah.add(step, 0, 3);

      await umrah.restart();
      expect(umrah.started, isFalse);
      expect(umrah.step, 0);
      expect(umrah.count(step, 0), 0);
    });
  });

  testWidgets('guided umrah: navigate to tawaf and count rounds', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = RiteProgress(prefs, umrahGuide);
    final tawafIndex = umrahGuide.steps.indexWhere((s) => s.id == 'tawaf');
    await tester.pumpWidget(
      MaterialApp(home: GuidedRiteScreen(progress: progress)),
    );
    expect(find.text(umrahGuide.steps.first.title), findsOneWidget);
    expect(find.text('السابق'), findsOneWidget);

    for (var i = 0; i < tawafIndex; i++) {
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
    }
    expect(find.text('الطواف'), findsWidgets);
    expect(progress.step, tawafIndex);

    final counter = find.text('٠ / ٧');
    expect(counter, findsOneWidget);
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.textContaining(' / ٧').first);
      await tester.pumpAndSettle();
      expect(progress.count(umrahGuide.steps[tawafIndex], 0), i + 1);
    }
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(progress.count(umrahGuide.steps[tawafIndex], 0), 7);

    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();
    expect(find.text('٦ / ٧'), findsOneWidget);
  });

  testWidgets('overview lists both guides and starts the umrah', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HajjUmrahScreen()));
    await tester.pumpAndSettle();
    expect(find.text(umrahGuide.title), findsWidgets);
    expect(find.text(hajjGuide.title), findsWidgets);
    for (final step in umrahGuide.steps.take(2)) {
      expect(find.text(step.title), findsOneWidget);
    }

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(GuidedRiteScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('البدء من جديد'), findsOneWidget);
  });
}
