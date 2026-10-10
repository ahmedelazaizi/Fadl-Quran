// Host run of the end-to-end walkthrough: the real app on a 360×800 phone,
// with bundled data and no network or phone plugins. The same walkthrough
// runs on an Android emulator in CI (integration_test/app_e2e_test.dart).

import 'dart:io';

import 'package:fadl/core/app_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration_test/e2e_walkthrough.dart';

Future<void> hostWait(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

/// Real fonts, so text measures as on a phone (the test font draws every
/// glyph as a wide square and would report overflows a phone never shows).
Future<void> loadAppFonts() async {
  const families = {
    'Tajawal': [
      'assets/fonts/Tajawal-Regular.ttf',
      'assets/fonts/Tajawal-Medium.ttf',
      'assets/fonts/Tajawal-Bold.ttf',
      'assets/fonts/Tajawal-ExtraBold.ttf',
    ],
    'Amiri': ['assets/fonts/Amiri-Regular.ttf', 'assets/fonts/Amiri-Bold.ttf'],
    'AmiriQuran': ['assets/fonts/AmiriQuran.ttf'],
    'NotoNaskhArabic': ['assets/fonts/NotoNaskhArabic.ttf'],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load(file));
    }
    await loader.load();
  }
  // Text without a family falls back to Roboto, as on Android.
  final roboto = FontLoader('Roboto');
  final sdk =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    final file = File(
      '$sdk/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
    );
    if (file.existsSync()) {
      roboto.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await roboto.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final language in ['ar', 'en']) {
    testWidgets(
      'every screen and control works ($language)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final dir = Directory.systemTemp.createTempSync('fadl_e2e');
        messenger.setMockMethodCallHandler(pathChannel, (_) async => dir.path);
        // The share sheet is a phone plugin; on the host it just succeeds.
        const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
        messenger.setMockMethodCallHandler(
          shareChannel,
          (_) async => 'dev.fluttercommunity.plus/share/unavailable',
        );
        addTearDown(() {
          messenger.setMockMethodCallHandler(shareChannel, null);
          messenger.setMockMethodCallHandler(pathChannel, null);
          dir.deleteSync(recursive: true);
        });
        // E2E_SHORT=1: a small 320×640 phone with system bars.
        final short = Platform.environment['E2E_SHORT'] == '1';
        tester.view.physicalSize = short
            ? const Size(640, 1280)
            : const Size(1080, 2400);
        tester.view.devicePixelRatio = short ? 1.0 : 3;
        if (short) {
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
          tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
        }
        addTearDown(tester.view.reset);

        final state = AppState();
        await tester.runAsync(state.load);
        await state.setLanguage(language);
        final report = await E2eWalkthrough(
          tester,
          wait: hostWait,
          ignore: hostOnlyPluginError,
        ).run(state);
        printReport(report);
        expect(report.screens, hasLength(21));
        expect(report.issues, isEmpty, reason: report.summary());
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }
}
