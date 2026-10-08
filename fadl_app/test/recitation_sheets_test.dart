import 'dart:io';
import 'dart:typed_data';

import 'package:fadl/core/audio_store.dart';
import 'package:fadl/core/auto_download.dart';
import 'package:fadl/core/reciters.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/screens/quran/recitation_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _index =
    '{"1":{"subfolder":"Yasser_Ad-Dussary_128kbps","name":"Yasser Ad-Dussary","bitrate":"128kbps"}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReciterCatalog.instance.everyAyah = parseEveryAyahIndex(_index);
    ReciterCatalog.instance.favorites = {};
  });
  tearDown(() => ReciterCatalog.instance.everyAyah = const []);

  testWidgets(
    'reciter picker searches, stars favourites and returns a choice',
    (tester) async {
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  picked = await showReciterPicker(context, 'ar.alafasy'),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('اختر القارئ'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'الدوسري');
      await tester.pumpAndSettle();
      expect(find.text('ياسر الدوسري'), findsOneWidget);
      expect(find.text('مشاري راشد العفاسي'), findsNothing);

      await tester.tap(find.byTooltip('إضافة إلى المفضلة'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(
        ReciterCatalog.instance.isFavorite('ea.Yasser_Ad-Dussary_128kbps'),
        isTrue,
      );

      await tester.tap(find.text('ياسر الدوسري'));
      await tester.pumpAndSettle();
      expect(picked, 'ea.Yasser_Ad-Dussary_128kbps');
    },
  );

  test(
    'auto download is off by default and saves a surah once when on',
    () async {
      final root = await Directory.systemTemp.createTemp('fadl_auto_dl_');
      addTearDown(() => root.delete(recursive: true));
      var requests = 0;
      final store = AudioStore(
        root: () async => root,
        client: MockClient((_) async {
          requests++;
          return http.Response.bytes(Uint8List.fromList([1]), 200);
        }),
      );
      final auto = AutoDownload(store: store);
      const id = 'ea.Yasser_Ad-Dussary_128kbps';

      await auto.consider(id, 1);
      expect(requests, 0);

      await AutoDownload.setEnabled(true);
      await auto.consider(id, 1);
      for (
        var i = 0;
        i < 100 && store.status(id, 1) != DownloadStatus.complete;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(store.status(id, 1), DownloadStatus.complete);
      expect(requests, 7);

      await auto.consider(id, 1);
      expect(requests, 7);
      await auto.consider('unknown', 1);
      expect(requests, 7);
    },
  );
}
