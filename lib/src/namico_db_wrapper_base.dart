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
class DBWrapper extends DBWrapperInterface {
  /// The sqlite3 object that holds the db.
  late final Database sql;

  late final String _dbTableName;

  late final _DBIsolateManager _isolateManager;

  /// File info for the db.
  final DbWrapperFileInfo fileInfo;

  final String? encryptionKey;

  final bool createIfNotExist;

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
  static DBWrapper open(
    String directory,
    String dbName, {
    String? encryptionKey,
    List<DBColumnType>? customTypes,
    bool createIfNotExist = false,
    Duration? autoDisposeTimerDuration = _DBWrapperAutoDisposable.defaultDisposeTimerDuration,
  }) {
    final fileInfo = DbWrapperFileInfo(directory: directory, dbName: dbName, encryptionKey: encryptionKey);
    return DBWrapper.openFromInfo(
      fileInfo: fileInfo,
      encryptionKey: encryptionKey,
      customTypes: customTypes,
      createIfNotExist: createIfNotExist,
      autoDisposeTimerDuration: autoDisposeTimerDuration,
    );
  }

  /// Opens a db by specifying [fileInfo] with optional [encryptionKey].
  ///
  /// Passing [customTypes] can define how the table looks, otherwise the objects are saved as a json string in one column.
  static DBWrapper openFromInfo({
    required DbWrapperFileInfo fileInfo,
    String? encryptionKey,
    List<DBColumnType>? customTypes,
    bool createIfNotExist = false,
    Duration? autoDisposeTimerDuration = _DBWrapperAutoDisposable.defaultDisposeTimerDuration,
  }) {
    if (autoDisposeTimerDuration == null) {
      return DBWrapper._openFromInfo(
        fileInfo: fileInfo,
        encryptionKey: encryptionKey,
        createIfNotExist: createIfNotExist,
        customTypes: customTypes,
      );
    } else {
      return _DBWrapperAutoDisposable._openFromInfo(
        fileInfo: fileInfo,
        encryptionKey: encryptionKey,
        createIfNotExist: createIfNotExist,
        customTypes: customTypes,
        disposeTimerDuration: autoDisposeTimerDuration,
      );
    }
  }

  DBWrapper._openFromInfo({
    required this.fileInfo,
    this.encryptionKey,
    this.createIfNotExist = false,
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
    bool createTable = true,
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
    if (createTable) _commandsManager.createTable();
    _readSt = _commandsManager.buildReadKeyStatement();
    if (_commands is DBCommands) _writeStDefault = _commandsManager.buildWriteStatement(null);
    _isolateManager = _DBIsolateManager(tableName, dbOpenUriFinal, customTypes);
  }

  PreparedStatement? _writeStDefault;
  late final PreparedStatement _readSt;
  PreparedStatement? _existSt;

  /// Wether the db is currently open or not.
  bool get isOpen => _isOpen;
  bool _isOpen = false;

  /// close the db and free allocated resources.
  @override
  void close() {
    _isOpen = false;
    _readSt.dispose();
    _writeStDefault?.dispose();
    _existSt?.dispose();
    sql.dispose();
    _isolateManager.dispose();
  }

  void reOpen() {
    return _openFromInfoInternal(
      fileInfo: fileInfo,
      createIfNotExist: createIfNotExist,
      customTypes: customTypes,
      encryptionKey: encryptionKey,
      createTable: false,
    );
  }

  /// Early prepare the isolate channel responsible for async methods.
  /// This is not really needed unless you want to speed up first time execution.
  @override
  Future<void> prepareIsolateChannel() => _isolateManager.initialize();

  /// Claim free space after duplicate inserts or deletions. this can be an expensive operation
  @override
  void claimFreeSpace() => sql.execute(_commands.vacuumCommand());

  /// Async version of [claimFreeSpace]
  @override
  Future<void> claimFreeSpaceAsync() => _executeAsync(const IsolateEncodableClaimFreeSpace());

  /// Load all rows inside the db. if [customTypes] are provided then the key will exist in the map provided, otherwise see [loadEverythingKeyed].
  @override
  void loadEverything(void Function(Map<String, dynamic> value) onValue) {
    final command = _commands.loadEverythingCommand(_dbTableName);
    final res = sql.select(command);
    final columnNames = res.columnNames;
    res.rows.loop(
      (row) {
        final parsed = _commands.parseRow(columnNames, row);
        if (parsed != null) onValue(parsed);
      },
    );
  }

  /// Load all rows inside the db with their key.
  @override
  void loadEverythingKeyed(void Function(String key, Map<String, dynamic> value) onValue) {
    final command = _commands.loadEverythingKeyedCommand(_dbTableName);
    final res = sql.select(command);
    final columnNames = res.columnNames;
    res.rows.loop(
      (row) {
        try {
          final parsedKeyed = _commands.parseKeyedRow(columnNames, row);
          if (parsedKeyed != null) {
            final parsed = parsedKeyed.map;
            if (parsed != null) onValue(parsedKeyed.key, parsed);
          }
        } catch (_) {}
      },
    );
  }

  /// Wether the db contains [key] or not. note that null values are allowed so the key may exist with a null value.
  /// In that case you might need to check the actual value by [get].
  @override
  bool containsKey(String key) {
    _existSt ??= _commandsManager.buildExistStatement();
    return _existSt?.select([key]).isNotEmpty == true;
  }

  /// get a value of a key. this can return null if key doesn't exist or value is null.
  /// use [containsKey] if you want to check the key itself
  @override
  Map<String, dynamic>? get(String key) {
    final command = IsolateEncodableReadKey(key);
    return command.execute(_readSt, commands: _commands);
  }

  @override
  List<Map<String, dynamic>> getAll(List<String> keys) {
    final command = IsolateEncodableReadList(keys);
    return command.execute(_readSt, commands: _commands);
  }

  /// async version of [get].
  @override
  Future<Map<String, dynamic>?> getAsync(String key) async {
    final command = IsolateEncodableReadKey(key);
    final res = await _executeAsync(command);
    return res as Map<String, dynamic>?;
  }

  /// async version of [getAll].
  @override
  Future<List<Map<String, dynamic>>> getAllAsync(List<String> keys) async {
    final command = IsolateEncodableReadList(keys);
    final res = await _executeAsync(command);
    return res as List<Map<String, dynamic>>;
  }

  /// puts a value [object] to a [key] in the db. if the key already exists then it's overriden.
  /// if [customTypes] are provided then the keys of [object] should be the same as the column names of [customTypes].
  @override
  void put(String key, Map<String, dynamic>? object) {
    final params = _commands.objectToWriteParameters(key, object);
    if (_writeStDefault != null) {
      _writeStDefault!.execute(params);
    } else {
      // `DBCommandsCustom` needs to create it each time, cuz the parameters passed by [object] could not be the same as the default parameters.
      final statement = _commandsManager.buildWriteStatement(object?.keys);
      statement.execute(params);
      statement.dispose();
    }
  }

  /// async version of [put].
  @override
  Future<void> putAsync(String key, Map<String, dynamic>? object) {
    final entries = IsolateEncodableWriteList.fromEntry(key, object);
    return _writeAsync(entries);
  }

  /// same as [put] but for multiple values.
  @override
  Future<void> putAllAsync<E>(List<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = IsolateEncodableWriteList.fromList(items, itemToEntry);
    return _writeAsync(entries);
  }

  /// same as [putAllAsync] except that [putAllAsync] is better with lists.
  @override
  Future<void> putAllIterableAsync<E>(Iterable<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = IsolateEncodableWriteList.fromIterable(items, itemToEntry);
    return _writeAsync(entries);
  }

  /// delete a single row inside the db.
  @override
  void delete(String key) {
    final command = IsolateEncodableDeleteList([key]);
    final st = command.buildStatement(sql, _dbTableName, commands: _commands);
    try {
      return command.execute(st, commands: _commands);
    } finally {
      st.dispose();
    }
  }

  /// async version of [delete].
  @override
  Future<void> deleteAsync(String key) {
    final command = IsolateEncodableDeleteList([key]);
    return _executeAsync(command);
  }

  /// delete all rows inside the db.
  @override
  Future<void> deleteEverything() {
    return _executeAsync(const IsolateEncodableDeleteEverything());
  }

  Future<void> _writeAsync(IsolateEncodableWriteList writeList) {
    return _executeAsync(writeList);
  }

  Future<dynamic> _executeAsync(IsolateEncodableBase command) {
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

  PreparedStatement buildReadKeysAllStatement(int keysCount) {
    final command = _commands.selectKeysAllCommand(tableName, keysCount);
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

  final _completers = <int, Completer<dynamic>?>{};

  void dispose() => disposePort();

  Future<dynamic> executeIsolate(IsolateEncodableBase command) async {
    if (!isInitialized) await initialize();
    final token = _IsolateMessageToken.create().key;
    _completers[token]?.complete(null); // useless but anyways
    final completer = _completers[token] = Completer<dynamic>();
    sendPort([command, token]);
    var res = await completer.future;
    _completers[token] = null; // dereferencing
    return res;
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
      dynamic readRes;
      if (command is IsolateEncodableClaimFreeSpace) {
        try {
          command.execute(statement, commands: commands);
        } finally {
          if (canDisposeStatement) statement.dispose();
          sendPort.send([token, readRes]);
        }
      } else {
        try {
          readRes = command.execute(statement, commands: commands);
        } finally {
          if (canDisposeStatement) statement.dispose();
          sendPort.send([token, readRes]);
        }
      }
    });

    sendPort.send(PortsProviderMessages.prepared); // prepared
  }

  @override
  void onResult(result) {
    final token = result[0] as int;
    final completer = _completers[token];
    if (completer != null && completer.isCompleted == false) completer.complete(result[1]);
  }
}

class _IsolateMessageToken {
  _IsolateMessageToken.create();

  int get key => hashCode;
}
