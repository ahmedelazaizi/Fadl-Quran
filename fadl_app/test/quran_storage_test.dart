import 'dart:convert';

import 'package:fadl/core/quran_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'saving a reading position updates listeners and persistent storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LastReadStore.instance;
      const position = ReadingPosition(
        key: '2:10',
        page: 3,
        number: 10,
        juz: 1,
        surahName: 'البقرة',
      );

      await store.save(position);

      expect(store.value?.page, 3);
      final prefs = await SharedPreferences.getInstance();
      final persisted = ReadingPosition.fromJson(
        jsonDecode(prefs.getString('fadl.lastRead')!),
      );
      expect(persisted?.key, '2:10');
      expect(persisted?.page, 3);
      expect(persisted?.surahName, 'البقرة');
    },
  );

  test(
    'invalid cached reading page is rejected instead of opening a wrong page',
    () {
      expect(ReadingPosition.fromJson({'key': '2:10', 'page': 605}), isNull);
    },
  );
}
