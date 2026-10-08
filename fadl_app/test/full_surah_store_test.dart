import 'dart:async';
import 'dart:io';

import 'package:fadl/core/full_surah_reciters.dart';
import 'package:fadl/core/full_surah_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final edition = FullSurahEdition(
  reciterId: 51,
  editionId: 7,
  nameAr: 'عبد الباسط عبد الصمد',
  nameEn: 'Abdulbasit Abdulsamad',
  editionName: 'مرتل',
  server: Uri.parse('https://server7.mp3quran.net/basit/'),
  surahs: {1, 2, 112},
);

void main() {
  late Directory root;
  setUp(() async => root = await Directory.systemTemp.createTemp('fadl_fs_'));
  tearDown(() => root.delete(recursive: true));

  FullSurahStore store(MockClient client) =>
      FullSurahStore(client: client, root: () async => root);

  MockClient serving(List<int> bytes, {int status = 200, int? length}) =>
      MockClient.streaming((request, _) async {
        expect(
          request.url.toString(),
          'https://server7.mp3quran.net/basit/112.mp3',
        );
        return http.StreamedResponse(
          Stream.fromIterable([bytes.sublist(0, 2), bytes.sublist(2)]),
          status,
          contentLength: length ?? bytes.length,
        );
      });

  test('a downloaded surah plays offline and survives a restart', () async {
    final first = store(serving([1, 2, 3, 4, 5]));
    await first.download(edition, 112);
    expect(first.isDownloaded(edition, 112), isTrue);
    expect(first.localFile(edition, 112)!.readAsBytesSync(), [1, 2, 3, 4, 5]);

    // Offline: no catalog, only what was saved on the device.
    final reopened = store(
      MockClient((_) async => throw const SocketException('offline')),
    );
    await reopened.ready();
    final saved = reopened.downloadedEditions.single;
    expect(saved.key, edition.key);
    expect(saved.nameAr, edition.nameAr);
    expect(saved.editionName, 'مرتل');
    expect(reopened.downloadedSurahs(saved), [112]);
    expect(await reopened.totalSize(), 5);
  });

  test('failed, truncated or foreign downloads leave nothing behind', () async {
    final notFound = store(serving([1, 2, 3], status: 404));
    await expectLater(notFound.download(edition, 112), throwsA(anything));
    expect(notFound.isDownloaded(edition, 112), isFalse);

    final truncated = store(serving([1, 2, 3], length: 10));
    await expectLater(truncated.download(edition, 112), throwsA(anything));
    expect(truncated.isDownloaded(edition, 112), isFalse);

    await expectLater(
      store(serving([1, 2, 3])).download(edition, 3),
      throwsStateError,
    );
    final files = root
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last);
    expect(files.where((name) => name.contains('.mp3')), isEmpty);
  });

  test(
    'cancel stops a running download and removes the partial file',
    () async {
      final chunks = StreamController<List<int>>();
      final s = store(
        MockClient.streaming(
          (_, _) async =>
              http.StreamedResponse(chunks.stream, 200, contentLength: 100),
        ),
      );
      final running = s.download(edition, 112);
      chunks.add([1, 2, 3]);
      // Folder setup is real file I/O; wait until the first chunk is counted.
      for (var i = 0; i < 100 && s.progress(edition, 112) == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(s.isDownloading(edition, 112), isTrue);
      expect(s.progress(edition, 112), closeTo(0.03, 1e-9));
      await s.cancel(edition, 112);
      await expectLater(running, throwsA(isA<FullSurahDownloadCancelled>()));
      expect(s.isDownloading(edition, 112), isFalse);
      expect(s.isDownloaded(edition, 112), isFalse);
      expect(
        root
            .listSync(recursive: true)
            .where((f) => f.path.endsWith('.download')),
        isEmpty,
      );
      await chunks.close();
    },
  );

  test(
    'a surah cached by the player is listed; partial caches are not',
    () async {
      final s = store(MockClient((_) async => http.Response('', 500)));
      final cache = await s.cacheFile(edition, 2);
      File('${cache.path}.part').writeAsBytesSync([9]);
      File('${cache.path}.mime').writeAsStringSync('audio/mpeg');
      await s.refresh();
      expect(s.isDownloaded(edition, 2), isFalse);

      File('${cache.path}.part').renameSync(cache.path);
      await s.refresh();
      expect(s.isDownloaded(edition, 2), isTrue);

      await s.deleteSurah(edition, 2);
      expect(s.downloadedEditions, isEmpty);
      expect(
        Directory('${root.path}/full_surah/${edition.key}').existsSync(),
        isFalse,
      );
    },
  );

  test('saved metadata from a foreign server is ignored', () {
    final json = edition.toJson()..['server'] = 'https://evil.example/x/';
    expect(FullSurahEdition.fromJson(json), isNull);
    expect(FullSurahEdition.fromJson(edition.toJson())!.surahs, {1, 2, 112});
  });
}
