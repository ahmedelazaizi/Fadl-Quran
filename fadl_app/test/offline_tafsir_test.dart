import 'dart:convert';
import 'dart:io';

import 'package:fadl/core/app_state.dart';
import 'package:fadl/core/offline_tafsir.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tiny alquran.cloud `/v1/quran/{edition}` response.
String _payload(String slug) => jsonEncode({
  'code': 200,
  'status': 'OK',
  'data': {
    'surahs': [
      {
        'number': 1,
        'ayahs': [
          {'number': 1, 'numberInSurah': 1, 'text': '$slug 1:1'},
          {'number': 2, 'numberInSurah': 2, 'text': '$slug 1:2'},
        ],
      },
      {
        'number': 2,
        'ayahs': [
          {'number': 3, 'numberInSurah': 1, 'text': '$slug 2:1'},
        ],
      },
    ],
    'edition': {'identifier': slug},
  },
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late List<Uri> requested;
  late bool failing;
  late OfflineTafsir store;

  OfflineTafsir open() => OfflineTafsir(
    client: MockClient((request) async {
      requested.add(request.url);
      if (failing) return http.Response('', 503);
      final slug = request.url.pathSegments.last;
      return http.Response.bytes(utf8.encode(_payload(slug)), 200);
    }),
    root: () async => root,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('fadl_tafsir_test');
    requested = [];
    failing = false;
    store = open();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('nothing is available before the user downloads', () async {
    expect(await store.resolve('ar.muyassar'), isNull);
    expect(await store.text('ar.muyassar', '1:1'), isNull);
    expect(await store.ayahTafsir('1:1', 'ar.muyassar'), isNull);
    expect(await store.totalSize(), 0);
    expect(requested, isEmpty);
  });

  test('a downloaded edition is read locally by ayah and surah', () async {
    await store.download('ar.muyassar');

    expect(requested.single.toString(), endsWith('/v1/quran/ar.muyassar'));
    expect(store.isDownloaded('ar.muyassar'), isTrue);
    expect(await store.text('ar.muyassar', '1:2'), 'ar.muyassar 1:2');
    expect(await store.text('ar.muyassar', '2:1'), 'ar.muyassar 2:1');
    expect(await store.text('ar.muyassar', '2:9'), isNull);
    expect(await store.surah('ar.muyassar', 1), {
      '1:1': 'ar.muyassar 1:1',
      '1:2': 'ar.muyassar 1:2',
    });
    final sheet = await store.ayahTafsir('1:1', 'ar.muyassar');
    expect(sheet?['text'], 'ar.muyassar 1:1');
    expect((sheet?['edition'] as Map)['nameAr'], 'التفسير الميسر');
    expect(await store.size('ar.muyassar'), greaterThan(0));

    // A new instance (app restart) finds it on disk without the network.
    requested.clear();
    final reopened = open();
    expect(await reopened.text('ar.muyassar', '1:1'), 'ar.muyassar 1:1');
    expect(requested, isEmpty);
  });

  test('a failed download leaves nothing on disk', () async {
    failing = true;
    await expectLater(
      store.download('ar.jalalayn'),
      throwsA(isA<TafsirDownloadException>()),
    );
    expect(store.isDownloaded('ar.jalalayn'), isFalse);
    expect(await store.totalSize(), 0);
    expect(
      Directory('${root.path}/tafsir').existsSync()
          ? Directory('${root.path}/tafsir').listSync()
          : const [],
      isEmpty,
    );
  });

  test('deleting an edition frees its space', () async {
    await store.download('ar.muyassar');
    await store.download('ar.jalalayn');
    await store.delete('ar.muyassar');

    expect(store.isDownloaded('ar.muyassar'), isFalse);
    expect(await store.size('ar.muyassar'), 0);
    expect(await store.text('ar.muyassar', '1:1'), isNull);
    expect(await store.text('ar.jalalayn', '1:1'), 'ar.jalalayn 1:1');
    expect(await store.totalSize(), await store.size('ar.jalalayn'));
  });

  test('the saved tafsir setting picks a downloaded edition', () async {
    final first = AppState();
    await first.load();
    await first.updateSettings({'tafsirSlug': 'ar.jalalayn'});

    final restored = AppState();
    await restored.load();
    final preferred = restored.settings['tafsirSlug'] as String?;
    expect(preferred, 'ar.jalalayn');

    await store.download('ar.muyassar');
    // Not downloaded yet: falls back to what is on the device.
    expect(await store.resolve(preferred), 'ar.muyassar');
    await store.download('ar.jalalayn');
    expect(await store.resolve(preferred), 'ar.jalalayn');
  });
}
