part of '../namico_db_wrapper.dart';

class DBWrapper {
  late final Database sql;
  final String _dbDirectory;
  final String _dbName;
  final String _extension;

  DBWrapper.open(this._dbDirectory, this._dbName, {String? encryptionKey}) : _extension = encryptionKey != null ? '' : '.db' {
    _isOpen = true;

    final dbDirectory = _dbDirectory;
    final name = _dbName;

    sql = sqlite3.open("$dbDirectory/$name$_extension");
    if (encryptionKey != null) {
      try {
        sql.execute('PRAGMA key = "$encryptionKey";');
      } catch (_) {}
    }
    sql.execute("PRAGMA journal_mode=WAL");

    final utils = _DBUtils(sql, name);
    utils.createTable();
    _readSt = utils.buildReadKeyStatement();
    _writeSt = utils.buildWriteStatement();
  }

  late final PreparedStatement _writeSt;
  late final PreparedStatement _readSt;
  PreparedStatement? _existSt;

  bool get isOpen => _isOpen;
  bool _isOpen = false;

  void close() {
    _isOpen = false;
    sql.dispose();
    _readSt.dispose();
    _writeSt.dispose();
    _existSt?.dispose();
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

  bool containsKey(String key) {
    _existSt ??= _DBUtils(sql, _dbName).buildExistStatement();
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
    return _writeAsync(
      (writeStatement) {
        writeStatement.execute([key, object.encode()]);
      },
    );
  }

  Future<void> putAllAsync<E>(List<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = <MapEntry<String, Map<String, dynamic>>>[];
    items.loop((e) {
      final entry = itemToEntry(e);
      entries.add(entry);
    });
    return _writeAsync(
      (writeStatement) {
        entries.loop((item) => writeStatement.execute([item.key, item.value.encode()]));
      },
    );
  }

  Future<void> putAllIterableAsync<E>(Iterable<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = <MapEntry<String, Map<String, dynamic>>>[];
    for (final e in items) {
      final entry = itemToEntry(e);
      entries.add(entry);
    }
    return _writeAsync(
      (writeStatement) {
        entries.loop((item) => writeStatement.execute([item.key, item.value.encode()]));
      },
    );
  }

  void delete(String key) {
    sql.execute('DELETE FROM $_dbName WHERE key = ?', [key]);
  }

  Future<void> deleteAsync(String key) {
    return _executeAsync(
      (db, utils) {
        sql.execute('DELETE FROM $_dbName WHERE key = ?', [key]);
      },
      readOnly: false,
    );
  }

  Future<void> deleteEverything() {
    return _executeAsync(
      (db, utils) {
        sql.execute('DELETE FROM $_dbName'); //  WHERE true
      },
      readOnly: false,
    );
  }

  Future<T> _writeAsync<T>(T Function(PreparedStatement writeStatement) fn) {
    return _executeAsync(
      (db, utils) {
        final st = utils.buildWriteStatement();
        try {
          return fn(st);
        } finally {
          st.dispose();
        }
      },
      readOnly: false,
    );
  }

  Future<T> _readAsync<T>(T Function(PreparedStatement readStatement) fn) {
    return _executeAsync(
      (db, utils) {
        final st = utils.buildReadKeyStatement();
        try {
          return fn(st);
        } finally {
          st.dispose();
        }
      },
      readOnly: true,
    );
  }

  Future<T> _executeAsync<T>(T Function(Database db, _DBUtils utils) fn, {required bool readOnly}) {
    final dbDirectory = _dbDirectory;
    final name = _dbName;
    final ext = _extension;

    return Isolate.run(
      () {
        sqlopen.open.overrideFor(sqlopen.OperatingSystem.android, sqlcipher.openCipherOnAndroid);
        final sql = sqlite3.open("$dbDirectory/$name$ext", mode: readOnly ? OpenMode.readOnly : OpenMode.readWriteCreate);
        final utils = _DBUtils(sql, name);
        try {
          return fn(sql, utils);
        } finally {
          sql.dispose();
        }
      },
    );
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

class _DBUtils {
  final Database sql;
  final String tableName;

  const _DBUtils(this.sql, this.tableName);

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
