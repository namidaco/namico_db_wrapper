import 'dart:io';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:test/test.dart';

void main() {
  group('Main tests', () {
    test('read/write', () async {
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
      final dir = '${Directory.current.path}${Platform.pathSeparator}db_test';
      Directory(dir).createSync();
      final dbwrapper = DBWrapper.open(dir, 'test');

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
      final dbwrapper = DBWrapper.open(dir, 'test');

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
}
