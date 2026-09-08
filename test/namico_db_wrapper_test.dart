// ignore_for_file: unused_element

import 'dart:io';

import 'package:benchmarking/benchmarking.dart';
import 'package:test/test.dart';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

void main() {
  late String dir;
  setUpAll(
    () {
      dir = '${Directory.current.path}${Platform.pathSeparator}db_test';
      Directory(dir).createSync();
    },
  );

  group('Main tests', () {
    test('read/write', () {
      final dbwrapper = DBWrapper.openSync(dir, '_-test-_');

      dbwrapper.put('_', {'title': 'hehe sync'});
      final res = dbwrapper.get('_');
      print(res);
      expect(res != null, true);
    });

    test('read/write async', () async {
      final dbwrapper = DBWrapper.open(dir, '_-test-_');

      await dbwrapper.put('_', {'title': 'hehe async'});
      final res = await dbwrapper.get('_');
      print(res);
      expect(res, isNotNull);
      final containsKey = await dbwrapper.containsKey('_');
      print(containsKey);
      expect(containsKey, isTrue);
    });
    test('async disposal', () async {
      final disposeDuration = Duration(seconds: 3);
      Future<void> delay() => Future.delayed(Duration(seconds: 4));
      final dbwrapper = DBWrapper.open(dir, '_-test-_', config: DBConfig(autoDisposeTimerDuration: disposeDuration));
      final res = await dbwrapper.get('_');
      print(res);
      expect(res, isNotNull);
      print(dbwrapper.isOpen);
      expect(dbwrapper.isOpen, isTrue);
      await delay();
      print(dbwrapper.isOpen);
      expect(dbwrapper.isOpen, isFalse);
      final res2 = await dbwrapper.get('_');
      print(res2);
      expect(res2, isNotNull);
      print(dbwrapper.isOpen);
      expect(dbwrapper.isOpen, isTrue); // open after requesting result
      await delay();
      print(dbwrapper.isOpen);
      expect(dbwrapper.isOpen, isFalse); // then closed again.
    });

    test('read/write bulk', () async {
      final dbwrapper = DBWrapper.openSync(dir, '_-test-_');

      dbwrapper.put('_1', {'title': 'item1'});
      dbwrapper.put('_2', {'title': 'item2'});
      dbwrapper.put('_3', {'title': 'item3'});
      final res = dbwrapper.getAll(['_1', '_2', 'non_existent', '_3']);
      print(res);
      expect(res.isNotEmpty, true);
      expect(res.length, 3);
    });

    test('concurrent writing', () async {
      Future<void> preventIsolateClosing() => Future.delayed(Duration(seconds: 1));

      final dbwrapper = DBWrapper.openSyncAsync(dir, '_-test-_');

      final items = List.generate(100, (index) => MapEntry(index, {'title': 'hehe$index'}));
      await Future.wait([
        dbwrapper.putAll(items, (item) => MapEntry("${item.key}", item.value)),
        dbwrapper.putAll(items, (item) => MapEntry("${item.key + items.length}", item.value)),
      ]);
      await preventIsolateClosing();
      await dbwrapper.delete('5');
      await preventIsolateClosing();

      int countTest = 0;
      countTest++;

      dbwrapper.sync.loadEverythingKeyed(
        (key, value) {
          print('$key ||| $value');
          countTest++;
        },
      );
      print('------> $countTest');
      expect(countTest > 1, isTrue);
    });

    test('use another ref of db after disposing', () async {
      final dbwrapperRef1 = DBWrapper.openSync(dir, '_-test-_');
      final dbwrapperRef2 = DBWrapper.openSync(dir, '_-test-_');

      var val1 = dbwrapperRef1.get('_');
      expect(val1, isNotNull);

      dbwrapperRef1.close();
      expect(dbwrapperRef1.isOpen, isFalse);

      var val2 = dbwrapperRef2.get('_');
      expect(val2, isNotNull);
      expect(dbwrapperRef2.isOpen, isTrue);
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
      final dbwrapper = DBWrapper.open(
        dir,
        'custom_db',
        config: DBConfig(
          customTypes: customTypes,
          createIfNotExist: true,
        ),
      );

      final dfvUsername = 'darkchoco';
      final dfvNickname = 'coolahhmaster';

      await dbwrapper.put('_', {
        'username': dfvUsername,
        'nickname': dfvNickname,
        'is_cool': true,
      });
      final res = await dbwrapper.get('_');
      print(res);
      expect(res != null, true);
      expect(res!['username'], dfvUsername);
      expect(res['nickname'], dfvNickname);
      expect(res['is_cool'], 1);
      expect(res['is_cool2'], 0);
    });

    test('write with unordered keys & null values', () {
      final customTypes = [
        DBColumnType(type: DBColumnTypeEnum.string, name: 'username', nullable: false, defaultValue: ''),
        DBColumnType(type: DBColumnTypeEnum.string, name: 'nickname', nullable: true),
        DBColumnType(type: DBColumnTypeEnum.int, name: 'age', nullable: true),
      ];
      final dbwrapper = DBWrapper.openSync(
        dir,
        'custom_db_unordered',
        config: DBConfig(customTypes: customTypes, createIfNotExist: true, autoDisposeTimerDuration: null),
      );
      dbwrapper.delete('u1');
      dbwrapper.put('u1', {'age': 20, 'nickname': null, 'username': 'first'});
      var res = dbwrapper.get('u1')!;
      expect(res['username'], 'first');
      expect(res['age'], 20);
      expect(res['nickname'], isNull);

      dbwrapper.put('u1', {'nickname': 'nick'});
      res = dbwrapper.get('u1')!;
      expect(res['username'], 'first');
      expect(res['nickname'], 'nick');

      expect(dbwrapper.containsKey('u1'), isTrue);
      expect(dbwrapper.containsKey('u2'), isFalse);
      dbwrapper.close();
    });

    test('key only writes', () {
      final customTypes = [
        DBColumnType(type: DBColumnTypeEnum.string, name: 'nickname', nullable: true),
        DBColumnType(type: DBColumnTypeEnum.string, name: 'title', nullable: false, defaultValue: "it's"),
      ];
      final dbwrapper = DBWrapper.openSync(
        dir,
        'custom_db_keyonly',
        config: DBConfig(customTypes: customTypes, createIfNotExist: true, autoDisposeTimerDuration: null),
      );
      dbwrapper.put('u1', {'nickname': 'nick'});
      dbwrapper.put('u1', null);
      dbwrapper.put('u1', {});
      dbwrapper.put('u2', {'nickname': null});
      final res = dbwrapper.get('u1')!;
      expect(res['nickname'], 'nick');
      expect(res['title'], "it's");
      expect(dbwrapper.containsKey('u2'), isTrue);
      expect(dbwrapper.get('u2')!['nickname'], isNull);
      dbwrapper.close();
    });

    test('same config returns same instance', () {
      DBConfig buildConfig() => DBConfig(
            customTypes: [DBColumnType(type: DBColumnTypeEnum.string, name: 'username', nullable: true)],
            createIfNotExist: true,
          );
      final db1 = DBWrapper.openSync(dir, 'custom_db_same', config: buildConfig());
      final db2 = DBWrapper.openSync(dir, 'custom_db_same', config: buildConfig());
      expect(identical(db1, db2), isTrue);
      db1.close();
    });
  });
  group('Bulk tests', () {
    test('getAll/deleteBulk above parameters limit', () {
      final dbwrapper = DBWrapper.openSync(dir, 'bulk_db', config: DBConfig(createIfNotExist: true, autoDisposeTimerDuration: null));
      const count = 2500;
      final items = List.generate(count, (i) => MapEntry('k$i', {'i': i}));
      dbwrapper.putAll(DBWriteList(items));
      final keys = items.map((e) => e.key).toList();
      expect(dbwrapper.getAll(keys).length, count);
      expect(dbwrapper.loadAllKeysResult().length, count);
      dbwrapper.deleteBulk(keys.sublist(0, 2001));
      expect(dbwrapper.getAll(keys).length, count - 2001);
      dbwrapper.delete('k2400');
      expect(dbwrapper.containsKey('k2400'), isFalse);
      dbwrapper.deleteEverything();
      expect(dbwrapper.loadAllKeysResult(), isEmpty);
      dbwrapper.close();
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
          await dbwrapper.putAll(items, (item) => MapEntry("${item.key}", item.value));

          await asyncBenchmark('loadEverythingKeyed', () => dbwrapper.loadEverythingKeyedResult())._report();
          await asyncBenchmark('loadEverything', () => dbwrapper.loadEverythingResult())._report();
        },
      );
    },
  );
}

extension _SyncBenchmarkExt on BenchmarkResult {
  void _report() {
    final res = this;
    res.report();
  }
}

extension _AsyncBenchmarkExt on Future<BenchmarkResult> {
  Future<void> _report() async {
    final res = await this;
    res.report();
  }
}
