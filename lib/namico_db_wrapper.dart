library namico_db_wrapper;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:sqlite3/open.dart' as sqlopen;
import 'package:sqlite3/sqlite3.dart';

import 'package:namico_db_wrapper/src/ports_provider.dart';

part 'package:namico_db_wrapper/src/core/commands/commands.dart';
part 'package:namico_db_wrapper/src/core/commands/commands_custom.dart';
part 'src/class/db_column_type.dart';
part 'src/class/db_keyed_result.dart';
part 'src/class/db_wrapper_file_info.dart';
part 'src/class/isolate_encodable_read.dart';
part 'src/class/isolate_encodable_write_list.dart';
part 'src/core/commands/commands_base.dart';
part 'src/core/enum.dart';
part 'src/db_core_functions.dart';
part 'src/db_wrapper_auto_disposable.dart';
part 'src/db_wrapper_interface.dart';
part 'src/db_wrapper_main.dart';
part 'src/namico_db_wrapper_base.dart';

typedef CacheWriteItemToEntryCallback<E> = MapEntry<String, Map<String, dynamic>?> Function(E item);

class NamicoDBWrapper {
  static DynamicLibrary? _lib;

  static void initialize() {
    sqlopen.open.overrideForAll(() {
      return _lib ??= _sqlcipherOpen();
    });
  }
}

DynamicLibrary _sqlcipherOpen() {
  // Taken from https://github.com/simolus3/sqlite3.dart/blob/e66702c5bec7faec2bf71d374c008d5273ef2b3b/sqlite3/lib/src/load_library.dart#L24
  if (Platform.isLinux || Platform.isAndroid) {
    try {
      return DynamicLibrary.open('libsqlcipher.so');
    } catch (_) {
      if (Platform.isAndroid) {
        // On some (especially old) Android devices, we somehow can't dlopen
        // libraries shipped with the apk. We need to find the full path of the
        // library (/data/data/<id>/lib/libsqlite3.so) and open that one.
        // For details, see https://github.com/simolus3/moor/issues/420
        final appIdAsBytes = File('/proc/self/cmdline').readAsBytesSync();

        // app id ends with the first \0 character in here.
        final endOfAppId = math.max(appIdAsBytes.indexOf(0), 0);
        final appId = String.fromCharCodes(appIdAsBytes.sublist(0, endOfAppId));

        return DynamicLibrary.open('/data/data/$appId/lib/libsqlcipher.so');
      }

      rethrow;
    }
  }
  if (Platform.isWindows) return DynamicLibrary.open('sqlite3.dll');
  if (Platform.isIOS) return DynamicLibrary.process();
  if (Platform.isMacOS) return DynamicLibrary.open('/usr/lib/libsqlite3.dylib');
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}
