import 'package:fadl/core/download_updates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const url = 'https://api.alquran.cloud/v1/quran/ar.muyassar';
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('download records validators and date', () async {
    final updates = DownloadUpdates();
    await updates.record('tafsir:ar.muyassar', url, {
      'etag': '"first"',
      'last-modified': 'Mon, 01 Jan 2024 00:00:00 GMT',
    });
    final stored = await updates.recordFor('tafsir:ar.muyassar');
    expect(stored?.url, url);
    expect(stored?.etag, '"first"');
    expect(stored?.lastModified, 'Mon, 01 Jan 2024 00:00:00 GMT');
    expect(
      stored!.downloadedAt.isBefore(
        DateTime.now().add(const Duration(seconds: 1)),
      ),
      isTrue,
    );
  });

  test('304 keeps a downloaded item current', () async {
    final updates = DownloadUpdates(
      client: MockClient((request) async {
        expect(request.method, 'HEAD');
        expect(request.headers['If-None-Match'], '"first"');
        return http.Response('', 304);
      }),
    );
    await updates.record('book', url, {'etag': '"first"'});
    expect(await updates.check('book', url), UpdateStatus.current);
  });

  test('changed ETag indicates update without replacing baseline', () async {
    final updates = DownloadUpdates(
      client: MockClient(
        (_) async => http.Response('', 200, headers: {'etag': '"second"'}),
      ),
    );
    await updates.record('book', url, {'etag': '"first"'});
    expect(await updates.check('book', url), UpdateStatus.available);
    expect((await updates.recordFor('book'))?.etag, '"first"');
  });

  test('missing source validators cannot establish freshness', () async {
    final updates = DownloadUpdates(
      client: MockClient((_) async => http.Response('', 200)),
    );
    await updates.record('book', url, {'etag': '"first"'});
    expect(await updates.check('book', url), UpdateStatus.unknown);
    expect(await updates.check('legacy', url), UpdateStatus.unknown);
  });

  test('network failure retains previous validators', () async {
    final updates = DownloadUpdates(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await updates.record('book', url, {'etag': '"first"'});
    await expectLater(
      updates.check('book', url),
      throwsA(isA<http.ClientException>()),
    );
    expect((await updates.recordFor('book'))?.etag, '"first"');
  });
}
