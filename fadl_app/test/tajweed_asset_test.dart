import 'dart:io';

import 'package:fadl/core/mushaf_layout.dart';
import 'package:fadl/core/offline_tajweed.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<int>> asset() async =>
      (await rootBundle.load(tajweedAsset)).buffer.asUint8List();

  test(
    'bundled tajweed covers every ayah and matches the mushaf letters',
    () async {
      final verses = parseTajweedVerses(gzip.decode(await asset()));
      expect(verses, hasLength(6236));
      // The page view colors an ayah only when the letters match exactly.
      final layout = await MushafLayout.load();
      final words = <String, StringBuffer>{};
      for (var page = 1; page <= layout.pageCount; page++) {
        for (final line in layout.lines(page)) {
          for (final token in line.tokens) {
            if (!token.isEnd) {
              words
                  .putIfAbsent(token.ayahKey, StringBuffer.new)
                  .write(token.text!.replaceAll(RegExp(r'\s+'), ''));
            }
          }
        }
      }
      final mismatched = [
        for (final MapEntry(:key, :value) in verses.entries)
          if (parseTajweedMarkup(value)
                  .map((piece) => piece.text.replaceAll(RegExp(r'\s+'), ''))
                  .join() !=
              words[key].toString())
            key,
      ];
      expect(mismatched, isEmpty);
      final rules = {
        for (final markup in verses.values)
          for (final piece in parseTajweedMarkup(markup))
            if (piece.rule != null) piece.rule!,
      };
      expect(rules, containsAll(['ham_wasl', 'madda_necessary', 'iqlab']));
    },
  );

  test('installs offline from the bundled file and can be removed', () async {
    final root = await Directory.systemTemp.createTemp('fadl_tajweed_');
    addTearDown(() => root.delete(recursive: true));
    final store = OfflineTajweed(asset: asset, root: () async => root);
    await store.ready();
    expect(store.isDownloaded, isFalse);
    await store.download();
    expect(store.isDownloaded, isTrue);
    expect(store.pieces('1:1')!.where((p) => p.rule == 'ham_wasl'), isNotEmpty);
    // A fresh instance reads the installed copy back.
    final reopened = OfflineTajweed(asset: asset, root: () async => root);
    await reopened.ready();
    expect(reopened.isDownloaded, isTrue);
    await reopened.delete();
    expect(reopened.isDownloaded, isFalse);
  });

  test('a damaged bundled file fails cleanly', () async {
    final root = await Directory.systemTemp.createTemp('fadl_tajweed_');
    addTearDown(() => root.delete(recursive: true));
    final store = OfflineTajweed(
      asset: () async => gzip.encode('{"verses": []}'.codeUnits),
      root: () async => root,
    );
    await expectLater(
      store.download(),
      throwsA(isA<TajweedDownloadException>()),
    );
    expect(store.isDownloaded, isFalse);
  });
}
