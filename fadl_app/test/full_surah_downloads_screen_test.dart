import 'dart:convert';
import 'dart:io';

import 'package:fadl/core/audio_store.dart';
import 'package:fadl/core/full_surah_reciters.dart';
import 'package:fadl/core/full_surah_store.dart';
import 'package:fadl/core/quran_storage.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/downloads_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storage;
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final edition = FullSurahEdition(
    reciterId: 51,
    editionId: 7,
    nameAr: 'عبد الباسط عبد الصمد',
    nameEn: 'Abdulbasit Abdulsamad',
    editionName: 'مرتل',
    server: Uri.parse('https://server7.mp3quran.net/basit/'),
    surahs: {1, 112},
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await Directory.systemTemp.createTemp('fadl_full_surah_ui_');
    messenger.setMockMethodCallHandler(channel, (_) async => storage.path);
    // A surah saved earlier; no network or catalog is available now.
    final dir = Directory('${storage.path}/full_surah/${edition.key}')
      ..createSync(recursive: true);
    File(
      '${dir.path}/meta.json',
    ).writeAsStringSync(jsonEncode(edition.toJson()));
    File('${dir.path}/112.mp3').writeAsBytesSync(List.filled(2048, 1));
    await Future.wait([
      AudioStore.instance.ready(),
      FullSurahStore.instance.ready(),
      QuranIndex.surahs(),
    ]);
  });
  tearDownAll(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await storage.delete(recursive: true);
  });

  testWidgets('saved full surahs are listed and opened offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const DownloadsScreen(),
      ),
    );
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    expect(find.text('Full-surah recitations'), findsOneWidget);
    expect(find.text('عبد الباسط عبد الصمد (مرتل)'), findsOneWidget);
    expect(find.text('Saved surahs: 1 • 2.0 KB'), findsOneWidget);
    expect(find.text('Delete all'), findsOneWidget);

    await tester.tap(find.text('عبد الباسط عبد الصمد (مرتل)'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('الإخلاص'), findsOneWidget);
    expect(find.text('الفاتحة'), findsNothing);
  });
}
