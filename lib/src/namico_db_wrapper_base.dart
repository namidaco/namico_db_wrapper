// ignore_for_file: public_member_api_docs, sort_constructors_first
// ignore_for_file: unnecessary_this

part of '../namico_db_wrapper.dart';

/// This class mixes [DBWrapperSync] with [DBWrapperAsync], meaning that 2 instances of the db will be active,
/// one on main isolate and the other on a separate isolate. Use this only when really needed.
///
/// See also:
///
///  * [DBWrapperSync], the sync implementation.
///  * [DBWrapperAsync], the async implementation.
class DBWrapper extends DBWrapperAsync {
  final DBWrapperSync sync;

  DBWrapper._({
    required this.sync,
    required super.fileInfo,
    required super.config,
  }) : super._openFromInfo();

  /// Opens a db by specifying [directory] & [dbName] with optional [DBConfig.encryptionKey].
  ///
  ///
  /// {@template DBWrapper.open}
  ///
  /// Passing [DBConfig.customTypes] can define how the table looks, otherwise the objects are saved as a json string in one column.
  ///
  /// Opening another database with the same info, returns the same instance as the previous one.
  ///
  /// {@endtemplate}
  static DBWrapperAsync open(
    String directory,
    String dbName, {
    DBConfig config = const DBConfig(),
  }) {
    final fileInfo = DbWrapperFileInfo(
      directory: directory,
      dbName: dbName,
      encryptionKey: config.encryptionKey,
    );
    return DBWrapper.openFromInfo(
      fileInfo: fileInfo,
      config: config,
    );
  }

  /// Opens a db by specifying [file] with optional [DBConfig.encryptionKey].
  ///
  /// {@macro DBWrapper.open}
  static DBWrapperAsync openFromFile(
    File file, {
    DBConfig config = const DBConfig(),
  }) {
    final fileInfo = DbWrapperFileInfo.fromFile(
      dbFile: file,
      encryptionKey: config.encryptionKey,
    );
    return DBWrapper.openFromInfo(
      fileInfo: fileInfo,
      config: config,
    );
  }

  /// Opens a db by specifying [fileInfo] with optional [DBConfig.encryptionKey].
  ///
  /// {@macro DBWrapper.open}
  static DBWrapperAsync openFromInfo({
    required DbWrapperFileInfo fileInfo,
    DBConfig config = const DBConfig(),
  }) {
    return DBWrapperAsync._openFromInfo(
      fileInfo: fileInfo,
      config: config,
    );
  }

  /// Sync version of [DBWrapper.open].
  static DBWrapperSync openSync(
    String directory,
    String dbName, {
    DBConfig config = const DBConfig(),
  }) {
    final fileInfo = DbWrapperFileInfo(
      directory: directory,
      dbName: dbName,
      encryptionKey: config.encryptionKey,
    );
    return DBWrapperSync.openFromInfo(
      fileInfo: fileInfo,
      config: config,
    );
  }

  /// Sync version of [DBWrapper.openFromFile].
  static DBWrapperSync openFromFileSync(
    File file, {
    DBConfig config = const DBConfig(),
  }) {
    final fileInfo = DbWrapperFileInfo.fromFile(
      dbFile: file,
      encryptionKey: config.encryptionKey,
    );
    return DBWrapperSync._openFromInfo(
      fileInfo: fileInfo,
      config: config,
    );
  }

  /// Sync version of [DBWrapper.openFromInfo].
  static DBWrapperSync openFromInfoSync({
    required DbWrapperFileInfo fileInfo,
    DBConfig config = const DBConfig(),
  }) {
    return DBWrapperSync._openFromInfo(
      fileInfo: fileInfo,
      config: config,
    );
  }

  /// Combines [DBWrapper.open] & [DBWrapper.openSync].
  ///
  /// The result object contains 2 db instances: [DBWrapper.sync] & [DBWrapperAsync].
  static DBWrapper openSyncAsync(
    String directory,
    String dbName, {
    DBConfig config = const DBConfig(),
  }) {
    final fileInfo = DbWrapperFileInfo(
      directory: directory,
      dbName: dbName,
      encryptionKey: config.encryptionKey,
    );
    return DBWrapper.openFromInfoSyncAsync(
      fileInfo: fileInfo,
      config: config,
    );
  }

  static DBWrapper openFromInfoSyncAsync({
    required DbWrapperFileInfo fileInfo,
    DBConfig config = const DBConfig(),
  }) {
    final sync = DBWrapperSync._openFromInfo(
      fileInfo: fileInfo,
      config: config,
    );
    return DBWrapper._(
      sync: sync,
      fileInfo: fileInfo,
      config: config,
    );
  }

  @override
  DbWrapperFileInfo get fileInfo => sync.fileInfo;

  @override
  bool get isOpen => super.isOpen || sync.isOpen;

  @override
  Future<void> close() async {
    sync.close();
    return await super.close();
  }

  // ===== try methods =====

  static Future<DBWrapperSync?> openSyncTry(
    String directory,
    String dbName, {
    DBConfig config = const DBConfig(),
  }) {
    return DBWrapper._tryOpenDB(
      () => DBWrapper.openSync(
        directory,
        dbName,
        config: config,
      ),
    );
  }

  static Future<DBWrapperSync?> openFromInfoSyncTry({
    required DbWrapperFileInfo fileInfo,
    DBConfig config = const DBConfig(),
  }) {
    return DBWrapper._tryOpenDB(
      () => DBWrapper.openFromInfoSync(
        fileInfo: fileInfo,
        config: config,
      ),
    );
  }

  static Future<DBWrapper?> openSyncAsyncTry(
    String directory,
    String dbName, {
    DBConfig config = const DBConfig(),
  }) {
    final fileInfo = DbWrapperFileInfo(
      directory: directory,
      dbName: dbName,
      encryptionKey: config.encryptionKey,
    );
    return DBWrapper.openFromInfoSyncAsyncTry(
      fileInfo: fileInfo,
      config: config,
    );
  }

  static Future<DBWrapper?> openFromInfoSyncAsyncTry({
    required DbWrapperFileInfo fileInfo,
    DBConfig config = const DBConfig(),
  }) async {
    final sync = await DBWrapper._tryOpenDB(
      () => DBWrapperSync._openFromInfo(
        fileInfo: fileInfo,
        config: config,
      ),
    );
    if (sync == null) return null;
    return DBWrapper._(
      sync: sync,
      fileInfo: fileInfo,
      config: config,
    );
  }

  /// try open a db by retrying for [maxAttempts] times in case it was locked.
  static Future<T?> _tryOpenDB<T>(T? Function() openFn, {int maxAttempts = 20, File? reportDbFile}) async {
    T? db;
    int attemptsCount = 0;
    while (db == null) {
      try {
        db = openFn();
      } on SqliteException catch (sqlException) {
        bool checkCode(int code) => sqlException.resultCode == code || sqlException.extendedResultCode == code;
        bool checkMessage(String containsText) => sqlException.message.contains(containsText) || (sqlException.explanation?.contains(containsText) == true);
        if (checkCode(261) || checkCode(5) || checkMessage('database is locked')) {
          await Future.delayed(Duration(milliseconds: 200));
        }
      } finally {
        attemptsCount++;
      }
      if (attemptsCount > maxAttempts) break;
    }

    if (kDebugMode) {
      if (attemptsCount > 1) {
        String msg = db == null ? 'failed to open db after $attemptsCount attempts :(' : 'opened db after $attemptsCount attempts :)';
        if (reportDbFile != null) msg += ". $reportDbFile";
        debugPrint('DBWrapper._tryOpenDB: $msg');
      }
    }

    return db;
  }
}

/// {@template DBWrapperSync}
/// A wrapper around SQLite3 that facilitates readings/insertions/deletions/etc.
///
/// The columns can be specified using [DBConfig.customTypes] which are pre-defined/dynamically-added columns, otherwise they default to a single json-encoded [String] `value` column.
/// The id is always a [String] `key`.
///
/// {@endtemplate}
class DBWrapperSync with DBWrapperInterfaceSync {
  // == calling methods while db is disposed, will throw null check error.

  static final _openedDBSync = <_DBKey, DBWrapperSync>{};

  /// The sqlite3 object that holds the db.
  Database? sql;

  /// File info for the db.
  final DbWrapperFileInfo fileInfo;

  /// Config for the db.
  final DBConfig config;

  final DBCommandsBase _commands;

  late _DBCommandsManager _commandsManager;

  final void Function()? onClose;

  factory DBWrapperSync.openFromInfo({
    required DbWrapperFileInfo fileInfo,
    DBConfig config = const DBConfig(),
    void Function()? onClose,
  }) {
    final dbKey = _DBKey(fileInfo: fileInfo, config: config);
    final cachedDb = _openedDBSync[dbKey];
    if (cachedDb != null) return cachedDb;

    final autoDisposeTimerDuration = config.autoDisposeTimerDuration;
    final newInstance = autoDisposeTimerDuration == null
        ? DBWrapperSync._openFromInfo(
            fileInfo: fileInfo,
            config: config,
            onClose: onClose,
          )
        : _DBWrapperSyncAutoDisposable._openFromInfo(
            fileInfo: fileInfo,
            config: config,
            disposeTimerDuration: autoDisposeTimerDuration,
            onClose: onClose,
          );
    return _openedDBSync[dbKey] = newInstance;
  }

  DBWrapperSync._openFromInfo({
    required this.fileInfo,
    required this.config,
    this.onClose,
  }) : _commands = DBCommandsBase.dynamic(config.customTypes) {
    _openFromInfoInternal(
      fileInfo: fileInfo,
      config: config,
    );
  }

  DBWrapperSync _openFromInfoInternal({
    required DbWrapperFileInfo fileInfo,
    required DBConfig config,
    bool createTable = true,
  }) {
    if (_isOpen) close(); // -- unpossible scemario but warever

    _isOpen = true;
    try {
      final dbFile = fileInfo.file;
      if (config.createIfNotExist && !dbFile.existsSync()) dbFile.createSync(recursive: true);
      sql = sqlite3.open(fileInfo.dbOpenUriFinal, uri: true);
      sql!.prepareDatabase(config: config);
      _commandsManager = _DBCommandsManager(sql!, fileInfo.dbTableName, _commands);
      if (createTable) _commandsManager.createTable();
      _readSt = _commandsManager.buildReadKeyStatement();
      if (_commands is DBCommands) _writeStDefault = _commandsManager.buildWriteStatement(null);
      return this;
    } catch (_) {
      close();
      rethrow;
    }
  }

  PreparedStatement? _writeStDefault;
  PreparedStatement? _readSt;
  PreparedStatement? _existSt;

  @override
  bool get isOpen => _isOpen;
  bool _isOpen = false;

  @override
  void close() {
    _isOpen = false;
    final dbKey = _DBKey(fileInfo: fileInfo, config: config);
    _openedDBSync.remove(dbKey);

    _readSt?.dispose();
    _writeStDefault?.dispose();
    _existSt?.dispose();
    sql?.dispose();

    _readSt = null;
    _writeStDefault = null;
    _existSt = null;
    sql = null;

    onClose?.call();
  }

  @override
  DBWrapperSync reOpen() {
    return _openFromInfoInternal(
      fileInfo: fileInfo,
      config: config,
      createTable: false,
    );
  }

  @override
  void claimFreeSpaceAndCheckpoint() {
    sql!.execute(_commands.vacuumCommand());
    try {
      sql!.execute(_commands.checkpointCommand()); // force a checkpoint to merge wal content to db.
    } catch (_) {}
  }

  @override
  void checkpoint() {
    sql!.execute(_commands.checkpointCommand());
  }

  @override
  List<Map<String, dynamic>> loadEverythingResult() {
    final values = <Map<String, dynamic>>[];
    this.loadEverything(values.add);
    return values;
  }

  void loadEverything(LoadEverythingCallback onValue) {
    final command = _commands.loadEverythingCommand(fileInfo.dbTableName);
    final res = sql!.select(command);
    final columnNames = res.columnNames;

    final int length = res.rows.length;
    for (int i = 0; i < length; i++) {
      final parsed = _commands.parseRow(columnNames, res.rows[i]);
      if (parsed != null) onValue(parsed);
    }
  }

  @override
  Map<String, Map<String, dynamic>> loadEverythingKeyedResult() {
    final valuesMap = <String, Map<String, dynamic>>{};
    this.loadEverythingKeyed((key, value) => valuesMap[key] = value);
    return valuesMap;
  }

  void loadEverythingKeyed(LoadEverythingKeyedCallback onValue) {
    final command = _commands.loadEverythingKeyedCommand(fileInfo.dbTableName);
    final res = sql!.select(command);
    final columnNames = res.columnNames;
    final int length = res.rows.length;
    for (int i = 0; i < length; i++) {
      try {
        final parsedKeyed = _commands.parseKeyedRow(columnNames, res.rows[i]);
        if (parsedKeyed != null) {
          final parsed = parsedKeyed.map;
          if (parsed != null) onValue(parsedKeyed.key, parsed);
        }
      } catch (_) {}
    }
  }

  @override
  List<String> loadAllKeysResult() {
    final values = <String>[];
    this.loadAllKeys(values.add);
    return values;
  }

  void loadAllKeys(LoadAllKeysCallback onValue) {
    final command = _commands.selectAllKeysCommand(fileInfo.dbTableName);
    final res = sql!.select(command);
    final int length = res.rows.length;
    for (int i = 0; i < length; i++) {
      try {
        final row = res.rows[i];
        final parsedKey = _commands.parseKeyFromRow(row);
        if (parsedKey != null) {
          onValue(parsedKey);
        }
      } catch (_) {}
    }
  }

  @override
  bool containsKey(String key) {
    _existSt ??= _commandsManager.buildExistStatement();
    return _existSt?.select([key]).isNotEmpty == true;
  }

  @override
  Map<String, dynamic>? get(String key) {
    final res = _readSt!.select([key]);
    final row = res.rows.firstOrNull;
    if (row == null) return null;
    final columnNames = res.columnNames;
    try {
      return _commands.parseRow(columnNames, row);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Map<String, dynamic>> getAll(List<String> keys) {
    final command = _commandsManager.buildReadKeysAllStatement(keys.length);
    try {
      final res = command.select(keys);
      final values = <Map<String, dynamic>>[];
      final columnNames = res.columnNames;

      final rows = res.rows;
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        final parsed = _commands.parseRow(columnNames, row);
        if (parsed != null) values.add(parsed);
      }

      return values;
    } finally {
      command.dispose();
    }
  }

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

  void putAll<E>(DBWriteList writeList) {
    final items = writeList.items;
    if (items.isEmpty) return;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      put(item.key, item.value);
    }
  }

  @override
  void delete(String key) {
    return deleteBulk([key]);
  }

  @override
  void deleteBulk(List<String> keys) {
    if (keys.isEmpty) return;
    final st = _commandsManager.buildDeleteStatement(keys);
    try {
      return st.execute(keys);
    } finally {
      st.dispose();
    }
  }

  @override
  void deleteEverything({bool claimFreeSpaceAndCheckpoint = true}) {
    final st = _commandsManager.buildDeleteEverythingStatement();
    try {
      st.execute();
    } finally {
      st.dispose();
    }

    if (claimFreeSpaceAndCheckpoint) this.claimFreeSpaceAndCheckpoint();
  }
}

/// {@template DBWrapperAsync}
///
/// All async functions inside this class run on a separate *single* isolate, using [PortsProvider]
/// which means:
/// 1. the future returned refers to actual completions, you can safely access the modified table directly after the future returns.
/// 2. executing multiple async functions simultaneously will be safe, since operations would still be blocked but on another isolate.
///
/// {@endtemplate}

class DBWrapperAsync with DBWrapperInterfaceAsync {
  static final _openedDBAsync = <_DBKey, DBWrapperAsync>{};

  final DbWrapperFileInfo fileInfo;
  final DBConfig config;

  final _DBIsolateManager _isolateManager;

  factory DBWrapperAsync.openFromInfo({
    required DbWrapperFileInfo fileInfo,
    DBConfig config = const DBConfig(),
  }) {
    final dbKey = _DBKey(fileInfo: fileInfo, config: config);
    final cachedDb = _openedDBAsync[dbKey];
    if (cachedDb != null) return cachedDb;

    final newInstance = DBWrapperAsync._openFromInfo(
      fileInfo: fileInfo,
      config: config,
    );
    return _openedDBAsync[dbKey] = newInstance;
  }

  DBWrapperAsync._openFromInfo({
    required this.fileInfo,
    required this.config,
  }) : _isolateManager = _DBIsolateManager(
          fileInfo: fileInfo,
          config: config,
        ) {
    _prepareIsolateChannel();
  }

  @override
  bool get isOpen => _isolateManager.isInitialized;

  @override
  Future<void> close() {
    final dbKey = _DBKey(fileInfo: fileInfo, config: config);
    _openedDBAsync.remove(dbKey);
    return _isolateManager.dispose();
  }

  /// In [DBWrapperAsync], it just re-initializes the isolate channel.
  @override
  Future<DBWrapperAsync> reOpen() async {
    await _prepareIsolateChannel();
    return this;
  }

  /// Manually prepare the isolate channel responsible for async methods.
  Future<void> _prepareIsolateChannel() => _isolateManager.initialize();

  @override
  Future<void> claimFreeSpaceAndCheckpoint() => _executeAsync(const _IsolateEncodable.claimFreeSpaceAndCheckpoint());

  @override
  Future<void> checkpoint() => _executeAsync(const _IsolateEncodable.checkpoint());

  @override
  Future<List<Map<String, dynamic>>> loadEverythingResult() async => await _executeAsync(const _IsolateEncodable.loadEverything());

  @override
  Future<Map<String, Map<String, dynamic>>> loadEverythingKeyedResult() async => await _executeAsync(const _IsolateEncodable.loadEverythingKeyed());

  @override
  Future<List<String>> loadAllKeysResult() async => await _executeAsync(const _IsolateEncodable.loadAllKeys());

  @override
  Future<bool> containsKey(String key) async {
    final enc = _IsolateEncodable.containsKey(key);
    final res = await _executeAsync(enc);
    return res as bool;
  }

  @override
  Future<Map<String, dynamic>?> get(String key) async {
    final command = _IsolateEncodable.readKey(key);
    final res = await _executeAsync(command);
    return res as Map<String, dynamic>?;
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(List<String> keys) async {
    final command = _IsolateEncodable.readList(keys);
    final res = await _executeAsync(command);
    return res as List<Map<String, dynamic>>;
  }

  @override
  Future<void> put(String key, Map<String, dynamic>? object) {
    final entries = DBWriteList.fromEntry(key, object);
    return _writeAsync(entries);
  }

  @override
  Future<void> putAll<E>(List<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    if (items.isEmpty) return Future.value(null);
    final entries = DBWriteList.fromList(items, itemToEntry);
    return _writeAsync(entries);
  }

  @override
  Future<void> putAllIterable<E>(Iterable<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    if (items.isEmpty) return Future.value(null);
    final entries = DBWriteList.fromIterable(items, itemToEntry);
    return _writeAsync(entries);
  }

  @override
  Future<void> delete(String key) {
    final command = _IsolateEncodable.delete(key);
    return _executeAsync(command);
  }

  @override
  Future<void> deleteBulk(List<String> keys) {
    if (keys.isEmpty) return Future.value(null);
    final command = _IsolateEncodable.deleteBulk(keys);
    return _executeAsync(command);
  }

  @override
  Future<void> deleteEverything({bool claimFreeSpaceAndCheckpoint = true}) {
    final exc = claimFreeSpaceAndCheckpoint ? const _IsolateEncodable.deleteEverythingAndClaimSpace() : const _IsolateEncodable.deleteEverything();
    return _executeAsync(exc);
  }

  Future<void> _writeAsync(DBWriteList writeList) {
    if (writeList.items.isEmpty) return Future.value(null);
    final writeListEnc = _IsolateEncodable.writeList(writeList);
    return _executeAsync(writeListEnc);
  }

  Future<dynamic> _executeAsync(_IsolateEncodable command) {
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
    return sql.prepare(command, persistent: false);
  }

  PreparedStatement buildDeleteStatement(List<String> keys) {
    final command = _commands.deleteCommand(tableName, keys);
    return sql.prepare(command, persistent: false);
  }

  PreparedStatement buildDeleteEverythingStatement() {
    final command = _commands.deleteEverythingCommand(tableName);
    return sql.prepare(command, persistent: false);
  }

  PreparedStatement buildReadKeyStatement() {
    final command = _commands.selectKeyCommand(tableName);
    return sql.prepare(command, persistent: false);
  }

  PreparedStatement buildReadKeysAllStatement(int keysCount) {
    final command = _commands.selectKeysAllCommand(tableName, keysCount);
    return sql.prepare(command, persistent: false);
  }

  PreparedStatement buildExistStatement() {
    final command = _commands.doesKeyExistCommand(tableName);
    return sql.prepare(command, persistent: false);
  }
}

extension DatabaseUtils on Database {
  void prepareDatabase({required DBConfig config}) {
    final sql = this;
    final encryptionKey = config.encryptionKey;
    if (encryptionKey != null) {
      try {
        sql.execute('PRAGMA key = "$encryptionKey";');
      } catch (_) {}
    } else {
      sql.execute("PRAGMA cipher_memory_security = OFF; PRAGMA cipher_use_hmac = OFF; PRAGMA cipher_page_size = 8192; PRAGMA kdf_iter = 8;");
    }

    // -- wal2 doesn't always work (like on windows)
    String journalModeCommand = '';
    const preferredJournalMode = 'wal2';
    const fallbackJournalMode = 'wal';

    String? journalMode;
    try {
      final res = sql.select("PRAGMA journal_mode=$preferredJournalMode;");
      journalMode = res.rows.firstOrNull?.firstOrNull?.toString();
    } catch (_) {}

    if (journalMode != preferredJournalMode && journalMode != fallbackJournalMode) {
      journalModeCommand = 'PRAGMA journal_mode=$fallbackJournalMode; ';
    }

    sql.execute("${journalModeCommand}PRAGMA synchronous=NORMAL; PRAGMA busy_timeout=15000; PRAGMA read_uncommitted=1;");
  }
}

class _DBIsolateManager with PortsProvider<Map> {
  final DbWrapperFileInfo fileInfo;
  final DBConfig config;

  _DBIsolateManager({
    required this.fileInfo,
    required this.config,
  });

  final _tokenManager = _IsolateMessageToken.create();
  final _completers = <int, Completer<dynamic>?>{};

  Future<void> dispose() async {
    if (isInitialized) await disposePort();

    final pendingCompleters = _completers.values.toList();
    _completers.clear();
    for (final c in pendingCompleters) {
      c?.completeError(Exception('DB was closed before receiving result'));
    }
  }

  Future<dynamic> executeIsolate(_IsolateEncodable command) async {
    if (!isInitialized) await initialize();
    final token = _tokenManager.next();
    _completers[token]?.complete(null); // useless but anyways
    final completer = _completers[token] = Completer<dynamic>();
    sendPort([token, command]);
    var res = await completer.future;
    _completers.remove(token); // dereferencing
    return res;
  }

  @override
  IsolateFunctionReturnBuild<Map> isolateFunction(SendPort port) {
    final params = {
      'port': port,
      'fileInfo': fileInfo,
      'config': config,
    };
    return IsolateFunctionReturnBuild(_prepareResourcesAndListen, params);
  }

  static void _prepareResourcesAndListen(Map params) async {
    final sendPort = params['port'] as SendPort;
    final fileInfo = params['fileInfo'] as DbWrapperFileInfo;
    final config = params['config'] as DBConfig;

    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    NamicoDBWrapper.initialize();

    DBWrapperSync? db = await DBWrapper._tryOpenDB(
      () => DBWrapperSync.openFromInfo(
        fileInfo: fileInfo,
        config: config,
        onClose: () => sendPort.send(PortsProviderMessages.disposed),
      ),
      reportDbFile: fileInfo.file,
    );

    if (db == null) {
      sendPort.send(PortsProviderMessages.prepared); // send prepared first to assign ports
      sendPort.send(PortsProviderMessages.disposed);
      return;
    }

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (PortsProvider.isDisposeMessage(p)) {
        recievePort.close();
        streamSub?.cancel();
        db.close();
        return;
      }

      p as List;
      final token = p[0] as int;
      final command = p[1] as _IsolateEncodable;

      dynamic readRes;
      Object? exception;
      bool manualCommit = false;

      if (manualCommit) {
        // TODO: start transaction function
        try {
          db.sql!.execute('BEGIN;');
          readRes = command.execute(db);
          db.sql!.execute('COMMIT;');
        } catch (e) {
          exception = e;
          try {
            db.sql!.execute('ROLLBACK;');
          } catch (e) {
            exception = e;
          }
        }
      } else {
        try {
          readRes = command.execute(db);
        } catch (e) {
          exception = e;
        }
      }

      sendPort.send([token, readRes, exception]);
    });

    sendPort.send(PortsProviderMessages.prepared); // prepared
  }

  @override
  void onResult(result) {
    if (PortsProvider.isDisposeMessage(result)) {
      if (kDebugMode) debugPrint('PortsProvider.onResult: recieved internal auto dispose message. closing: `${fileInfo.file.path}`');
      dispose();
      return;
    }

    final token = result[0] as int;
    final completer = _completers[token];
    if (completer != null && completer.isCompleted == false) {
      final exc = result[2];
      if (exc != null) {
        completer.completeError(exc);
      } else {
        completer.complete(result[1]);
      }
    }
  }
}

class _IsolateMessageToken {
  int _initial = 0;
  _IsolateMessageToken.create();

  int next() => _initial++;
}

class _DBKey {
  final DbWrapperFileInfo fileInfo;
  final DBConfig config;

  const _DBKey({required this.fileInfo, required this.config});

  @override
  bool operator ==(covariant _DBKey other) {
    if (identical(this, other)) return true;

    return other.fileInfo == fileInfo && other.config == config;
  }

  @override
  int get hashCode => fileInfo.hashCode ^ config.hashCode;
}
