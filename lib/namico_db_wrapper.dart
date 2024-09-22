library namico_db_wrapper;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart' as sqlcipher;
import 'package:sqlite3/open.dart' as sqlopen;
import 'package:sqlite3/sqlite3.dart';

import 'package:namico_db_wrapper/src/ports_provider.dart';

part 'package:namico_db_wrapper/src/core/commands/commands.dart';
part 'package:namico_db_wrapper/src/core/commands/commands_custom.dart';
part 'src/class/db_column_type.dart';
part 'src/class/db_keyed_result.dart';
part 'src/class/db_wrapper_file_info.dart';
part 'src/class/isolate_encodable_write_list.dart';
part 'src/core/commands/commands_base.dart';
part 'src/core/enum.dart';
part 'src/db_core_functions.dart';
part 'src/db_wrapper_main.dart';
part 'src/namico_db_wrapper_base.dart';

typedef CacheWriteItemToEntryCallback<E> = MapEntry<String, Map<String, dynamic>?> Function(E item);

class NamicoDBWrapper {
  static initialize() {
    sqlopen.open.overrideFor(sqlopen.OperatingSystem.android, sqlcipher.openCipherOnAndroid);
  }
}
