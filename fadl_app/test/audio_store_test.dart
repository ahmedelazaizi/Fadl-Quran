import 'dart:io';
import 'dart:typed_data';

import 'package:fadl/core/audio_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _reciter = 'ar.alafasy';

/// Global ayah number from a CDN URL such as `.../ar.alafasy/4.mp3`.
int _global(Uri url) => int.parse(url.pathSegments.last.replaceAll('.mp3', ''));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late List<int> requested;
  late Set<int> failing;
  late AudioStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fadl_audio_test');
    requested = [];
    failing = {};
    final client = MockClient((request) async {
      final global = _global(request.url);
      requested.add(global);
      if (failing.contains(global)) return http.Response('', 503);
      return http.Response.bytes(
        Uint8List.fromList(List.filled(100, global)),
        200,
      );
    });
    store = AudioStore(client: client, root: () async => root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  List<String> files() => Directory(
    '${root.path}/audio/$_reciter',
  ).listSync().map((entry) => entry.uri.pathSegments.last).toList()..sort();

  test('downloading Al-Fatiha writes 7 files and completes', () async {
    expect(store.status(_reciter, 1), DownloadStatus.none);
    await store.downloadSurah(_reciter, 1);

    expect(requested.toSet(), {1, 2, 3, 4, 5, 6, 7});
    expect(files(), [for (var n = 1; n <= 7; n++) '$n.mp3']..sort());
    expect(files().where((name) => name.endsWith('.part')), isEmpty);
    expect(store.status(_reciter, 1), DownloadStatus.complete);
    expect(store.progress(_reciter, 1), isNull);
    expect(await store.reciterSize(_reciter), 700);
    expect((await store.localFile(_reciter, 1))?.lengthSync(), 100);
    expect(await store.localFile(_reciter, 8), isNull);
  });

  test('a failed request leaves a partial surah that resumes', () async {
    failing = {4};
    await expectLater(
      store.downloadSurah(_reciter, 1),
      throwsA(isA<AudioDownloadException>()),
    );
    expect(store.status(_reciter, 1), DownloadStatus.partial);
    expect(files().where((name) => name.endsWith('.part')), isEmpty);
    final present = files().map((name) => int.parse(name.split('.')[0]));
    expect(present, isNot(contains(4)));

    failing = {};
    requested = [];
    await store.downloadSurah(_reciter, 1);
    final missing = {1, 2, 3, 4, 5, 6, 7}.difference(present.toSet());
    expect(requested..sort(), missing.toList()..sort());
    expect(store.status(_reciter, 1), DownloadStatus.complete);
  });

  test('a fresh store sees files downloaded earlier', () async {
    await store.downloadSurah(_reciter, 1);
    final reopened = AudioStore(
      client: MockClient((_) async => http.Response('', 500)),
      root: () async => root,
    );
    await reopened.ready();
    expect(reopened.status(_reciter, 1), DownloadStatus.complete);
    expect(reopened.completeSurahCount(_reciter), 1);
  });

  test('deleting a surah, a reciter or everything frees the space', () async {
    await store.downloadSurah(_reciter, 1);
    await store.deleteSurah(_reciter, 1);
    expect(store.status(_reciter, 1), DownloadStatus.none);
    expect(await store.reciterSize(_reciter), 0);

    await store.downloadSurah(_reciter, 1);
    await store.deleteReciter(_reciter);
    expect(store.status(_reciter, 1), DownloadStatus.none);
    expect(await store.reciterSize(_reciter), 0);
    expect(store.downloadedReciters, isEmpty);

    await store.downloadSurah(_reciter, 1);
    await store.deleteAll();
    expect(store.status(_reciter, 1), DownloadStatus.none);
    expect(await store.totalSize(), 0);
  });
}
