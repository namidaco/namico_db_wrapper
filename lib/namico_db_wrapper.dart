library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:namico_db_wrapper/src/ports_provider.dart';

part 'package:namico_db_wrapper/src/core/commands/commands.dart';
part 'package:namico_db_wrapper/src/core/commands/commands_custom.dart';
part 'src/class/db_column_type.dart';
part 'src/class/db_config.dart';
part 'src/class/db_keyed_result.dart';
part 'src/class/db_wrapper_file_info.dart';
part 'src/class/db_write_list.dart';
part 'src/class/isolate_encodable_read.dart';
part 'src/class/isolate_encodable_write.dart';
part 'src/class/isolate_encodable.dart';
part 'src/core/commands/commands_base.dart';
part 'src/core/enum.dart';
part 'src/db_core_functions.dart';
part 'src/db_wrapper_auto_disposable.dart';
part 'src/db_wrapper_interface.dart';
part 'src/db_wrapper_main.dart';
part 'src/namico_db_wrapper_base.dart';

typedef CacheWriteItemToEntryCallback<E> = MapEntry<String, Map<String, dynamic>?> Function(E item);
typedef LoadEverythingCallback = void Function(Map<String, dynamic> value);
typedef LoadEverythingKeyedCallback = void Function(String key, Map<String, dynamic> value);
typedef LoadAllKeysCallback = void Function(String key);

class NamicoDBWrapper {
  static Future<void> dispose() async {
    final openedDBSync = DBWrapperSync._openedDBSync.values.toList();
    for (final db in openedDBSync) {
      db.close();
    }
    final openedDBAsync = DBWrapperAsync._openedDBAsync.values.toList();
    await Future.wait(openedDBAsync.map((db) => db.close().catchError((_) {})));
  }
}
