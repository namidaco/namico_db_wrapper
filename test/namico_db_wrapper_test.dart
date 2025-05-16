import 'dart:io';

import 'package:benchmarking/benchmarking.dart';
import 'package:test/test.dart';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

void main() {
  late String dir;
  setUpAll(
    () {
      NamicoDBWrapper.initialize();
      dir = '${Directory.current.path}${Platform.pathSeparator}db_test';
      Directory(dir).createSync();
    },
  );

  group('Main tests', () {
    test('read/write', () {
      final dbwrapper = DBWrapper.open(dir, '_-test-_');

      dbwrapper.put('_', {'title': 'hehe'});
      final res = dbwrapper.get('_');
      print(res);
      expect(res != null, true);
    });

    test('read/write bulk', () async {
      final dbwrapper = DBWrapper.open(dir, '_-test-_');

      dbwrapper.put('_1', {'title': 'item1'});
      dbwrapper.put('_2', {'title': 'item2'});
      dbwrapper.put('_3', {'title': 'item3'});
      final res = await dbwrapper.getAllAsync(['_1', '_2', 'non_existent', '_3']);
      print(res);
      expect(res.isNotEmpty, true);
      expect(res.length, 3);
    });

    test('concurrent writing', () async {
      Future<void> preventIsolateClosing() => Future.delayed(Duration(seconds: 1));

      final dbwrapper = DBWrapper.open(dir, '_-test-_');

      final items = List.generate(100, (index) => MapEntry(index, {'title': 'hehe$index'}));
      await Future.wait([
        dbwrapper.putAllAsync(items, (item) => MapEntry("${item.key}", item.value)),
        dbwrapper.putAllAsync(items, (item) => MapEntry("${item.key + items.length}", item.value)),
      ]);
      await preventIsolateClosing();
      await dbwrapper.deleteAsync('5');
      await preventIsolateClosing();

      dbwrapper.loadEverythingKeyed(
        (key, value) => print('$key ||| $value'),
      );
    });
  });
  group('Custom DB tests', () {
    test('read/write', () async {
      final customTypes = [
        DBColumnType(
          type: DBColumnTypeEnum.string,
          name: 'username',
          nullable: false,
        ),
        DBColumnType(
          type: DBColumnTypeEnum.string,
          name: 'nickname',
          nullable: true,
        ),
        DBColumnType(
          type: DBColumnTypeEnum.bool,
          name: 'is_cool',
          nullable: true,
        ),
        DBColumnType(
          type: DBColumnTypeEnum.bool,
          name: 'is_cool2',
          nullable: false,
          defaultValue: 0,
        ),
        // -- this will throw an error when inserting without this field, since its non-nullable & no default value provided.
        // DBColumnType(
        //   type: DBColumnTypeEnum.bool,
        //   name: 'is_cool3',
        //   nullable: false,
        //   defaultValue: null,
        // ),
      ];
      final dbwrapper = DBWrapper.open(dir, 'custom_db', customTypes: customTypes, createIfNotExist: true);

      final dfvUsername = 'darkchoco';
      final dfvNickname = 'coolahhmaster';

      await dbwrapper.putAsync('_', {
        'username': dfvUsername,
        'nickname': dfvNickname,
        'is_cool': true,
      });
      final res = await dbwrapper.getAsync('_');
      print(res);
      expect(res != null, true);
      expect(res!['username'], dfvUsername);
      expect(res['nickname'], dfvNickname);
      expect(res['is_cool'], 1);
      expect(res['is_cool2'], 0);
    });
  });
  group(
    'Benchmark tests',
    () {
      test(
        'load everything',
        () async {
          final dbwrapper = DBWrapper.open(dir, '_-test-_');
          final items = List.generate(10005, (index) => MapEntry(index, {'title': 'hehe$index'}));
          await dbwrapper.putAllAsync(items, (item) => MapEntry("${item.key}", item.value));

          syncBenchmark('loadEverythingKeyed', () => dbwrapper.loadEverythingKeyed((key, value) {})).report();
          syncBenchmark('loadEverything', () => dbwrapper.loadEverything((e) {})).report();
        },
      );
    },
  );
}
