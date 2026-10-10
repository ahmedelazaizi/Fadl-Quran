// On-device run of the end-to-end walkthrough (an Android emulator in CI:
// .github/workflows/android-e2e.yml). Unlike the host run, this uses the
// phone's real fonts, plugins, storage and network.
//
//   flutter test integration_test/app_e2e_test.dart -d <device>

import 'package:fadl/core/app_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'e2e_walkthrough.dart';

Future<void> deviceWait(WidgetTester tester) async {
  await tester.pump();
  await Future<void>.delayed(const Duration(milliseconds: 700));
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'every screen and control works on a phone',
    (tester) async {
      // The share sheet would take the walkthrough out of the app.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            (_) async => 'dev.fluttercommunity.plus/share/unavailable',
          );
      final state = AppState();
      await state.load();
      final report = await E2eWalkthrough(tester, wait: deviceWait).run(state);
      printReport(report);
      expect(report.screens, hasLength(21));
      expect(report.issues, isEmpty, reason: report.summary());
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
