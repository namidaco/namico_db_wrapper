import 'dart:io';

import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:test/test.dart';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

void main() {
  group('Main tests', () {
    test('read/write', () {
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
      final dir = '${Directory.current.path}${Platform.pathSeparator}db_test';
      Directory(dir).createSync();
      final dbwrapper = DBWrapper.open(dir, '_-test-_');

      dbwrapper.put('_', {'title': 'hehe'});
      final res = dbwrapper.get('_');
      print(res);
      expect(res != null, true);
    });
    test('concurrent writing', () async {
      Future<void> preventIsolateClosing() => Future.delayed(Duration(seconds: 1));
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
      final dir = '${Directory.current.path}${Platform.pathSeparator}db_test';
      Directory(dir).createSync();
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
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
      final dir = '${Directory.current.path}${Platform.pathSeparator}db_test';
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
}
