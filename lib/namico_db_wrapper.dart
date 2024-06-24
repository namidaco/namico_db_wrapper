library namico_db_wrapper;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:namico_db_wrapper/src/ports_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart' as sqlcipher;
import 'package:sqlite3/open.dart' as sqlopen;
import 'package:sqlite3/sqlite3.dart';

part 'src/class/isolate_encodable_write_list.dart';
part 'src/core.dart';
part 'src/db_wrapper_main.dart';
part 'src/namico_db_wrapper_base.dart';

typedef CacheWriteItemToEntryCallback<E> = MapEntry<String, Map<String, dynamic>> Function(E item);
