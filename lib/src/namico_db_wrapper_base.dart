part of '../namico_db_wrapper.dart';

/// A wrapper around SQLite3 that facilitates readings/insertions/deletions/etc.
///
/// The columns can be specified using [customTypes] which are pre-defined/dynamically-added columns, otherwise they default to a single json-encoded [String] `value` column.
/// The id is always a [String] `key`.
///
/// All async functions inside this class run on a separate *single* isolate, using [PortsProvider]
/// which means:
/// 1. the future returned refers to actual completions, you can safely access the modified table directly after the future returns.
/// 2. executing multiple async functions simultaneously will be safe, since operations would still be blocked but on another isolate.
class DBWrapper {
  /// The sqlite3 object that holds the db.
  late final Database sql;

  late final String _dbTableName;

  late final _DBIsolateManager _isolateManager;

  /// File info for the db.
  final DbWrapperFileInfo fileInfo;

  /// Defines the columns for the database.
  ///
  /// Columns that are added later after the table is already created, will be added inside the db by executing `ALTER TABLE table_name ADD COLUMN column_name`,
  /// this can be quite an expensive operation depending on how large the db is.
  ///
  /// Columns that are removed will not be deleted from the db.
  final List<DBColumnType>? customTypes;

  final DBCommandsBase _commands;

  late final _DBCommandsManager _commandsManager;

  /// Opens a db by specifying [directory] & [dbName] with optional [encryptionKey].
  ///
  /// Passing [customTypes] can define how the table looks, otherwise the objects are saved as a json string in one column.
  DBWrapper.open(
    String directory,
    String dbName, {
    String? encryptionKey,
    bool createIfNotExist = false,
    this.customTypes,
  })  : fileInfo = DbWrapperFileInfo(directory: directory, dbName: dbName, encryptionKey: encryptionKey),
        _commands = DBCommandsBase.dynamic(customTypes) {
    _dbTableName = '`${fileInfo.dbName}`';
    _openFromInfoInternal(
      fileInfo: fileInfo,
      encryptionKey: encryptionKey,
      createIfNotExist: createIfNotExist,
      customTypes: customTypes,
    );
  }

  /// Opens a db by specifying [fileInfo] with optional [encryptionKey].
  ///
  /// Passing [customTypes] can define how the table looks, otherwise the objects are saved as a json string in one column.
  DBWrapper.openFromInfo({
    required this.fileInfo,
    String? encryptionKey,
    bool createIfNotExist = false,
    this.customTypes,
  })  : _dbTableName = '`${fileInfo.dbName}`',
        _commands = DBCommandsBase.dynamic(customTypes) {
    _openFromInfoInternal(
      fileInfo: fileInfo,
      encryptionKey: encryptionKey,
      createIfNotExist: createIfNotExist,
      customTypes: customTypes,
    );
  }

  void _openFromInfoInternal({
    required DbWrapperFileInfo fileInfo,
    String? encryptionKey,
    bool createIfNotExist = false,
    List<DBColumnType>? customTypes,
  }) {
    _isOpen = true;

    final dbFile = fileInfo.file;
    if (createIfNotExist && !dbFile.existsSync()) dbFile.createSync(recursive: true);
    final uri = Uri.file(dbFile.path);
    final dbOpenUriFinal = "$uri?cache=shared";
    sql = sqlite3.open(dbOpenUriFinal, uri: true);
    sql.prepareDatabase(encryptionKey: encryptionKey);

    final tableName = _dbTableName;
    _commandsManager = _DBCommandsManager(sql, tableName, _commands);
    _commandsManager.createTable();
    _readSt = _commandsManager.buildReadKeyStatement();
    if (_commands is DBCommands) _writeStDefault = _commandsManager.buildWriteStatement(null);
    _isolateManager = _DBIsolateManager(tableName, dbOpenUriFinal, customTypes);
  }

  PreparedStatement? _writeStDefault;
  late final PreparedStatement _readSt;
  PreparedStatement? _existSt;

  bool get isOpen => _isOpen;
  bool _isOpen = false;

  void close() {
    _isOpen = false;
    _readSt.dispose();
    _writeStDefault?.dispose();
    _existSt?.dispose();
    sql.dispose();
    _isolateManager.dispose();
  }

  void claimFreeSpace() => sql.execute(_commands.vacuumCommand());

  Future<void> claimFreeSpaceAsync() => _executeAsyncMODIFY(const IsolateEncodableClaimFreeSpace());

  void loadEverything(void Function(Map<String, dynamic> value) onValue) {
    final command = _commands.loadEverythingCommand(_dbTableName);
    final res = sql.select(command);
    res.rows.loop(
      (row) {
        final parsed = _commands.parseResults(res);
        if (parsed != null) onValue(parsed);
      },
    );
  }

  void loadEverythingKeyed(void Function(String key, Map<String, dynamic> value) onValue) {
    final command = _commands.loadEverythingKeyedCommand(_dbTableName);
    final res = sql.select(command);

    res.rows.loop(
      (row) {
        try {
          final parsedKeyed = _commands.parseKeyedResults(res);
          if (parsedKeyed != null) {
            final parsed = parsedKeyed.map;
            if (parsed != null) onValue(parsedKeyed.key, parsed);
          }
        } catch (_) {}
      },
    );
  }

  bool containsKey(String key) {
    _existSt ??= _commandsManager.buildExistStatement();
    return _existSt?.select([key]).isNotEmpty == true;
  }

  Map<String, dynamic>? get(String key) {
    final res = _readSt.select([key]);
    return _commands.parseResults(res);
  }

  Future<Map<String, dynamic>?> getAsync(String key) {
    return _readAsync(
      (readStatement, utils) {
        final res = readStatement.select([key]);
        try {
          return utils.commands.parseResults(res);
        } catch (_) {
          return null;
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAllAsync(List<String> keys) {
    return _readAsync(
      (readStatement, utils) {
        final values = <Map<String, dynamic>>[];
        keys.loop((key) {
          final res = readStatement.select([key]);
          final parsed = utils.commands.parseResults(res);
          if (parsed != null) values.add(parsed);
        });
        return values;
      },
    );
  }

  void put(String key, Map<String, dynamic> object) {
    final params = _commands.objectToWriteParameters(key, object);
    if (_writeStDefault != null) {
      _writeStDefault!.execute(params);
    } else {
      // `DBCommandsCustom` needs to create it each time, cuz the parameters passed by [object] could not be the same as the default parameters.
      final statement = _commandsManager.buildWriteStatement(object.keys);
      statement.execute(params);
      statement.dispose();
    }
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
    final st = command.buildStatement(sql, _dbTableName, commands: _commands);
    try {
      return command.execute(st, commands: _commands);
    } finally {
      st.dispose();
    }
  }

  Future<void> deleteAsync(String key) {
    final command = IsolateEncodableDeleteList([key]);
    return _executeAsyncMODIFY(command);
  }

  Future<void> deleteEverything() {
    return _executeAsyncMODIFY(const IsolateEncodableDeleteEverything());
  }

  Future<void> _writeAsync(IsolateEncodableWriteList writeList) {
    return _executeAsyncMODIFY(writeList);
  }

  Future<T> _readAsync<T>(T Function(PreparedStatement readStatement, _DBCommandsManager utils) fn) {
    return _executeAsyncREAD(
      (db, utils) {
        final st = utils.buildReadKeyStatement();
        try {
          return fn(st, utils);
        } finally {
          st.dispose();
        }
      },
    );
  }

  Future<T> _executeAsyncREAD<T>(T Function(Database db, _DBCommandsManager utils) fn) {
    final customTypes = this.customTypes;
    final dbFilePath = fileInfo.file.path;
    final dbtablename = _dbTableName;
    return Isolate.run(
      () {
        NamicoDBWrapper.initialize();
        final uri = Uri.file(dbFilePath);
        final sql = sqlite3.open("$uri?cache=shared", mode: OpenMode.readOnly, uri: true);
        final commands = DBCommandsBase.dynamic(customTypes);
        final utils = _DBCommandsManager(sql, dbtablename, commands);
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

class _DBCommandsManager {
  final Database sql;
  final String tableName;
  final DBCommandsBase _commands;

  DBCommandsBase get commands => _commands;

  const _DBCommandsManager(
    this.sql,
    this.tableName,
    this._commands,
  );

  void createTable() {
    final command = _commands.createTableCommand(tableName);
    sql.execute(command);
    _commands.alterIfRequired(tableName, sql);
  }

  PreparedStatement buildWriteStatement(Iterable<String>? keys) {
    final command = _commands.writeCommand(tableName, keys);
    return sql.prepare(command, persistent: true);
  }

  PreparedStatement buildReadKeyStatement() {
    final command = _commands.selectKeyCommand(tableName);
    return sql.prepare(command, persistent: true);
  }

  PreparedStatement buildExistStatement() {
    final command = _commands.doesKeyExistCommand(tableName);
    return sql.prepare(command, persistent: true);
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
  final List<DBColumnType>? customTypes;

  _DBIsolateManager(
    this.tableName,
    this.dbOpenUriFinal,
    this.customTypes,
  );

  final _completers = <int, Completer<void>?>{};

  void dispose() => disposePort();

  Future<void> executeIsolate(IsolateEncodableBase command) async {
    if (!isInitialized) await initialize();
    final token = _IsolateMessageToken.create().key;
    _completers[token]?.complete(); // useless but anyways
    final completer = _completers[token] = Completer<void>();
    sendPort([command, token]);
    await completer.future;
    _completers[token] = null; // dereferencing
  }

  @override
  IsolateFunctionReturnBuild<Map> isolateFunction(SendPort port) {
    final params = {
      'port': port,
      'tableName': tableName,
      'customTypes': customTypes,
      'uriFinal': dbOpenUriFinal,
    };
    return IsolateFunctionReturnBuild(_prepareResourcesAndListen, params);
  }

  static void _prepareResourcesAndListen(Map params) async {
    final sendPort = params['port'] as SendPort;
    final tableName = params['tableName'] as String;
    final customTypes = params['customTypes'] as List<DBColumnType>?;
    final uriFinal = params['uriFinal'] as String;

    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    NamicoDBWrapper.initialize();
    final sql = sqlite3.open(uriFinal, mode: OpenMode.readWriteCreate, uri: true);
    final commands = DBCommandsBase.dynamic(customTypes);
    final utils = _DBCommandsManager(sql, tableName, commands);

    final PreparedStatement? writeStatementDefault = commands is DBCommands ? utils.buildWriteStatement(null) : null;

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (PortsProvider.isDisposeMessage(p)) {
        recievePort.close();
        streamSub?.cancel();
        writeStatementDefault?.dispose();
        sql.dispose();
        return;
      }

      p as List;
      final command = p[0] as IsolateEncodableBase;
      final token = p[1] as int;

      PreparedStatement statement;
      bool canDisposeStatement;
      if (command is IsolateEncodableWriteList && writeStatementDefault != null) {
        // only when `_commands` is `DBCommands`, because `DBCommandsCustom` needs to create it each time
        statement = writeStatementDefault;
        canDisposeStatement = false;
      } else {
        statement = command.buildStatement(sql, tableName, commands: commands);
        canDisposeStatement = true;
      }
      try {
        sql.execute('BEGIN;');
        command.execute(statement, commands: commands);
        sql.execute('COMMIT;');
      } catch (e) {
        try {
          sql.execute('ROLLBACK;');
        } catch (_) {}
        rethrow;
      } finally {
        if (canDisposeStatement) statement.dispose();
        sendPort.send(token);
      }
    });

    sendPort.send(PortsProviderMessages.prepared); // prepared
  }

  @override
  void onResult(token) {
    final completer = _completers[token as int];
    if (completer != null && completer.isCompleted == false) completer.complete();
  }
}

class _IsolateMessageToken {
  _IsolateMessageToken.create();

  int get key => hashCode;
}
