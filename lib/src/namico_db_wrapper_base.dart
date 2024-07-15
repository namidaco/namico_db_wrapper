part of '../namico_db_wrapper.dart';

class DBWrapper {
  late final Database sql;
  late final String _dbDirectory;
  final String _dbName;
  final String _extension;
  late final _DBIsolateManager _isolateManager;

  DBWrapper.open(String directory, this._dbName, {String? encryptionKey}) : _extension = encryptionKey != null ? '' : '.db' {
    _isOpen = true;

    if (!directory.endsWith(Platform.pathSeparator)) directory += Platform.pathSeparator;

    _dbDirectory = directory;
    final name = _dbName;

    final path = "$directory$name$_extension";
    final uri = Uri.file(path);
    final dbOpenUriFinal = "$uri?cache=shared";
    sql = sqlite3.open(dbOpenUriFinal, uri: true);
    sql.prepareDatabase(encryptionKey: encryptionKey);

    final utils = DBUtils(sql, name);
    utils.createTable();
    _readSt = utils.buildReadKeyStatement();
    _writeSt = utils.buildWriteStatement();
    _isolateManager = _DBIsolateManager(_dbName, dbOpenUriFinal);
  }

  late final PreparedStatement _writeSt;
  late final PreparedStatement _readSt;
  PreparedStatement? _existSt;

  bool get isOpen => _isOpen;
  bool _isOpen = false;

  void close() {
    _isOpen = false;
    _readSt.dispose();
    _writeSt.dispose();
    _existSt?.dispose();
    sql.dispose();
    _isolateManager.dispose();
  }

  void loadEverything(void Function(Map<String, dynamic> value) onValue) {
    final res = sql.select('SELECT value FROM $_dbName'); //  WHERE true
    res.rows.loop(
      (row) {
        final parsed = row.parseRow();
        if (parsed != null) onValue(parsed);
      },
    );
  }

  void loadEverythingKeyed(void Function(String key, Map<String, dynamic> value) onValue) {
    final res = sql.select('SELECT value,key FROM $_dbName'); //  WHERE true
    res.rows.loop(
      (row) {
        final key = row[1] as String;
        final parsed = row.parseRow();
        if (parsed != null) onValue(key, parsed);
      },
    );
  }

  bool containsKey(String key) {
    _existSt ??= DBUtils(sql, _dbName).buildExistStatement();
    return _existSt?.select([key]).isNotEmpty == true;
  }

  Map<String, dynamic>? get(String key) {
    final res = _readSt.select([key]);
    try {
      return res.rows.first.parseRow();
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getAsync(String key) {
    return _readAsync(
      (readStatement) {
        final res = readStatement.select([key]);
        try {
          return res.rows.first.parseRow();
        } catch (_) {
          return null;
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAllAsync(List<String> keys) {
    return _readAsync(
      (readStatement) {
        final values = <Map<String, dynamic>>[];
        keys.loop((key) {
          final res = readStatement.select([key]);
          final parsed = res.rows.first.parseRow();
          if (parsed != null) values.add(parsed);
        });
        return values;
      },
    );
  }

  void put(String key, Map<String, dynamic> object) {
    _writeSt.execute([key, object.encode()]);
  }

  Future<void> putAsync(String key, Map<String, dynamic> object) {
    final entries = IsolateEncodableWriteList.fromEntry(key, object);
    return _writeAsync(entries);
  }

  Future<void> putAllAsync<E>(List<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = IsolateEncodableWriteList.fromList(items, itemToEntry);
    return _writeAsync(entries);
  }

  Future<void> putAllIterableAsync<E>(Iterable<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = IsolateEncodableWriteList.fromIterable(items, itemToEntry);
    return _writeAsync(entries);
  }

  void delete(String key) {
    final command = IsolateEncodableDeleteList([key]);
    final st = command.buildStatement(sql, _dbName);
    try {
      return command.execute(st);
    } finally {
      st.dispose();
    }
  }

  Future<void> deleteAsync(String key) {
    final command = IsolateEncodableDeleteList([key]);
    return _executeAsyncMODIFY(command);
  }

  Future<void> deleteEverything() {
    final command = IsolateEncodableDeleteEverything();
    return _executeAsyncMODIFY(command);
  }

  Future<void> _writeAsync(IsolateEncodableWriteList writeList) {
    return _executeAsyncMODIFY(writeList);
  }

  Future<T> _readAsync<T>(T Function(PreparedStatement readStatement) fn) {
    return _executeAsyncREAD(
      (db, utils) {
        final st = utils.buildReadKeyStatement();
        try {
          return fn(st);
        } finally {
          st.dispose();
        }
      },
    );
  }

  Future<T> _executeAsyncREAD<T>(T Function(Database db, DBUtils utils) fn) {
    final dbDirectory = _dbDirectory;
    final name = _dbName;
    final ext = _extension;

    return Isolate.run(
      () {
        sqlopen.open.overrideFor(sqlopen.OperatingSystem.android, sqlcipher.openCipherOnAndroid);

        final path = "$dbDirectory$name$ext";
        final uri = Uri.file(path);
        final sql = sqlite3.open("$uri?cache=shared", mode: OpenMode.readOnly, uri: true);

        final utils = DBUtils(sql, name);
        try {
          return fn(sql, utils);
        } finally {
          sql.dispose();
        }
      },
    );
  }

  Future<void> _executeAsyncMODIFY(IsolateEncodableBase command) {
    return _isolateManager.executeIsolate(command);
  }
}

extension _ValueParser on List<Object?> {
  Map<String, dynamic>? parseRow() {
    try {
      return jsonDecode(first as String) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }
}

extension _ValueEncoder on Map<String, dynamic> {
  String encode() => jsonEncode(this);
}

class DBUtils {
  final Database sql;
  final String tableName;

  const DBUtils(this.sql, this.tableName);

  void createTable() {
    return sql.execute('''
    CREATE TABLE IF NOT EXISTS $tableName (
      key TEXT NOT NULL UNIQUE,
      value TEXT NOT NULL,
      PRIMARY KEY (key)
    );
  ''');
  }

  PreparedStatement buildWriteStatement() {
    return sql.prepare('''
INSERT INTO $tableName (key, value)
VALUES (?, ?)
ON CONFLICT (key) DO UPDATE
SET value=EXCLUDED.value
''');
  }

  PreparedStatement buildReadKeyStatement() {
    return sql.prepare('SELECT value FROM $tableName WHERE key IN (?)');
  }

  PreparedStatement buildExistStatement() {
    return sql.prepare('SELECT 1 FROM $tableName WHERE key IN (?)');
  }
}

extension _Listie<E> on List<E> {
  void loop(void Function(E item) fn) {
    final int length = this.length;
    for (int i = 0; i < length; i++) {
      fn(this[i]);
    }
  }
}

extension DatabaseUtils on Database {
  void prepareDatabase({String? encryptionKey}) {
    final sql = this;
    if (encryptionKey != null) {
      try {
        sql.execute('PRAGMA key = "$encryptionKey";');
      } catch (_) {}
    }
    sql.execute("PRAGMA journal_mode=wal2");
    sql.execute("PRAGMA synchronous=NORMAL");
    sql.execute("PRAGMA busy_timeout=5000");
  }
}

class _DBIsolateManager with PortsProvider<Map> {
  final String tableName;
  final String dbOpenUriFinal;
  _DBIsolateManager(this.tableName, this.dbOpenUriFinal);

  void dispose() => disposePort();

  Future<void> executeIsolate(IsolateEncodableBase command) async {
    await initialize();
    await sendPort(command);
  }

  @override
  IsolateFunctionReturnBuild<Map> isolateFunction(SendPort port) {
    final params = {
      'port': port,
      'tableName': tableName,
      'uriFinal': dbOpenUriFinal,
    };
    return IsolateFunctionReturnBuild(_prepareResourcesAndSearch, params);
  }

  static void _prepareResourcesAndSearch(Map params) async {
    final sendPort = params['port'] as SendPort;
    final tableName = params['tableName'] as String;
    final uriFinal = params['uriFinal'] as String;

    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    sqlopen.open.overrideFor(sqlopen.OperatingSystem.android, sqlcipher.openCipherOnAndroid);

    final sql = sqlite3.open(uriFinal, mode: OpenMode.readWriteCreate, uri: true);

    final utils = DBUtils(sql, tableName);
    final writeStatement = utils.buildWriteStatement();

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (PortsProvider.isDisposeMessage(p)) {
        recievePort.close();
        streamSub?.cancel();
        writeStatement.dispose();
        sql.dispose();
        return;
      }
      final command = p as IsolateEncodableBase;

      PreparedStatement statement;
      bool canDisposeStatement;
      if (command is IsolateEncodableWriteList) {
        statement = writeStatement;
        canDisposeStatement = false;
      } else {
        statement = command.buildStatement(sql, tableName);
        canDisposeStatement = true;
      }
      try {
        sql.execute('BEGIN;');
        command.execute(statement);
        sql.execute('COMMIT;');
      } catch (e) {
        try {
          sql.execute('ROLLBACK;');
        } catch (_) {}
        rethrow;
      } finally {
        if (canDisposeStatement) statement.dispose();
      }
    });

    sendPort.send(PortsProviderMessages.prepared); // prepared
  }

  @override
  void onResult(_) {}
}
