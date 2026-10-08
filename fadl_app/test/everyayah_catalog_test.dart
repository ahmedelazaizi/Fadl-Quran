import 'dart:io';
import 'dart:typed_data';

import 'package:fadl/core/audio_store.dart';
import 'package:fadl/core/reciters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shaped like everyayah.com/data/recitations.js.
const _index = '''
var recitations = {"ayahCount":[7,286,200],
"1":{"subfolder":"Alafasy_64kbps","name":"Alafasy","bitrate":"64kbps"},
"2":{"subfolder":"Alafasy_128kbps","name":"Alafasy","bitrate":"128kbps"},
"3":{"subfolder":"Yasser_Ad-Dussary_128kbps","name":"Yasser Ad-Dussary","bitrate":"128kbps"},
"4":{"subfolder":"Husary_128kbps_Mujawwad","name":"Husary Mujawwad","bitrate":"128kbps"},
"5":{"subfolder":"Husary_64kbps","name":"Husary","bitrate":"64kbps"},
"6":{"subfolder":"warsh/warsh_Abdul_Basit_128kbps","name":"Warsh Abdul Basit","bitrate":"128kbps"},
"7":{"subfolder":"translations/urdu_shamshad_ali_khan_46kbps","name":"(Urdu) Shamshad Ali Khan","bitrate":"46kbps"},
"8":{"subfolder":"../escape","name":"Bad","bitrate":"64kbps"},
"9":{"subfolder":"Some_New_Reciter_32kbps","name":"Some New Reciter","bitrate":"32kbps"}};
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('one entry per recording set, preferring 128 kbps', () {
    final parsed = parseEveryAyahIndex(_index);
    final byFolder = {for (final r in parsed) r['folder']: r};
    expect(byFolder.keys.toSet(), {
      'Alafasy_128kbps',
      'Yasser_Ad-Dussary_128kbps',
      'Husary_128kbps_Mujawwad',
      'Husary_64kbps',
      'warsh/warsh_Abdul_Basit_128kbps',
      'Some_New_Reciter_32kbps',
    });
    final dussary = byFolder['Yasser_Ad-Dussary_128kbps']!;
    expect(dussary['nameAr'], 'ياسر الدوسري');
    expect(dussary['id'], 'ea.Yasser_Ad-Dussary_128kbps');
    expect(byFolder['Husary_128kbps_Mujawwad']!['style'], 'مجود');
    final warsh = byFolder['warsh/warsh_Abdul_Basit_128kbps']!;
    expect(warsh['riwaya'], 'ورش عن نافع');
    expect(warsh['id'], isNot(contains('/')));
    // Unknown names stay readable in English rather than guessed.
    expect(byFolder['Some_New_Reciter_32kbps']!['nameAr'], 'Some New Reciter');
  });

  test('files are addressed by surah and ayah', () {
    expect(
      everyAyahUrl('Alafasy_128kbps', 2, 255),
      'https://everyayah.com/data/Alafasy_128kbps/002255.mp3',
    );
  });

  group('catalog', () {
    late List<Uri> requests;
    late ReciterCatalog catalog;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      requests = [];
    });

    Future<ReciterCatalog> open(Future<http.Response> Function() reply) async {
      final c = ReciterCatalog(
        client: MockClient((request) {
          requests.add(request.url);
          return reply();
        }),
      );
      await c.load();
      // load() refreshes in the background; let it finish.
      await c.refresh();
      return c;
    }

    test('stays available offline after one successful download', () async {
      catalog = await open(() async => http.Response(_index, 200));
      expect(requests.first.toString(), everyAyahIndexUrl);
      expect(catalog.everyAyah, hasLength(6));

      final offline = await open(
        () async => throw const SocketException('offline'),
      );
      expect(offline.everyAyah, hasLength(6));
    });

    test('favourites persist and come first', () async {
      catalog = await open(() async => http.Response(_index, 200));
      await catalog.toggleFavorite('ea.Yasser_Ad-Dussary_128kbps');
      final reopened = await open(() async => http.Response('', 500));
      expect(reopened.isFavorite('ea.Yasser_Ad-Dussary_128kbps'), isTrue);
      expect(reopened.ordered().first['id'], 'ea.Yasser_Ad-Dussary_128kbps');
      await reopened.toggleFavorite('ea.Yasser_Ad-Dussary_128kbps');
      expect(reopened.isFavorite('ea.Yasser_Ad-Dussary_128kbps'), isFalse);
    });
  });

  test('downloading an everyayah surah fetches SSSAAA files', () async {
    SharedPreferences.setMockInitialValues({});
    ReciterCatalog.instance.everyAyah = parseEveryAyahIndex(_index);
    addTearDown(() => ReciterCatalog.instance.everyAyah = const []);
    final root = await Directory.systemTemp.createTemp('fadl_everyayah_');
    addTearDown(() => root.delete(recursive: true));
    final urls = <String>[];
    final store = AudioStore(
      root: () async => root,
      client: MockClient((request) async {
        urls.add(request.url.toString());
        return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
      }),
    );
    const id = 'ea.Yasser_Ad-Dussary_128kbps';
    expect(reciterById(id), isNotNull);
    await store.downloadSurah(id, 1);
    expect(urls.toSet(), {
      for (var ayah = 1; ayah <= 7; ayah++)
        'https://everyayah.com/data/Yasser_Ad-Dussary_128kbps/001${'$ayah'.padLeft(3, '0')}.mp3',
    });
    expect(store.status(id, 1), DownloadStatus.complete);
  });
}
