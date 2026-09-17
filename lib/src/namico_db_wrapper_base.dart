// ignore_for_file: public_member_api_docs, sort_constructors_first
// ignore_for_file: unnecessary_this, experimental_member_use

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

  static const _kDBFilesSuffixes = <String>{'', '-wal', '-wal2', '-shm', '-journal'};

  /// Deletes the db file and its journal files, the db must be closed.
  ///
  /// Retries for a moment as windows can hold the file lock after closing, and empties the file as a last resort.
  static Future<void> deleteFiles(DbWrapperFileInfo fileInfo) async {
    final dbPath = fileInfo.file.path;
    for (final suffix in _kDBFilesSuffixes) {
      final file = File('$dbPath$suffix');
      if (!file.existsSync()) continue;
      bool deleted = false;
      for (int i = 0; i < 10 && !deleted; i++) {
        try {
          await file.delete();
          deleted = true;
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      if (!deleted) {
        try {
          await file.writeAsBytes(const []);
        } catch (_) {}
      }
    }
  }

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
    return DBWrapperAsync.openFromInfo(
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
    return DBWrapperSync.openFromInfo(
      fileInfo: fileInfo,
      config: config,
    );
  }

  /// Sync version of [DBWrapper.openFromInfo].
  static DBWrapperSync openFromInfoSync({
    required DbWrapperFileInfo fileInfo,
    DBConfig config = const DBConfig(),
  }) {
    return DBWrapperSync.openFromInfo(
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
    final sync = DBWrapperSync.openFromInfo(
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
      () => DBWrapperSync.openFromInfo(
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
        attemptsCount++;
        final isLocked = checkCode(261) || checkCode(5) || checkCode(6) || checkMessage('database is locked') || checkMessage('database table is locked');
        if (!isLocked || attemptsCount > maxAttempts) break;
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }
      attemptsCount++;
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
    if (_isOpen) close();

    _isOpen = true;
    try {
      final dbFile = fileInfo.file;
      if (config.createIfNotExist && !dbFile.existsSync()) dbFile.createSync(recursive: true);
      final sql = this.sql = sqlite3.open(fileInfo.dbOpenUriFinal, uri: true);
      sql.prepareDatabase(config: config);
      _commandsManager = _DBCommandsManager(sql, fileInfo.dbTableName, _commands);
      if (createTable) _commandsManager.createTable();
      _readSt = _commandsManager.buildReadKeyStatement();
      if (_commands.isWriteStatementStatic) _writeStDefault = _commandsManager.buildWriteStatement(null);
      _openedDBSync.putIfAbsent(_DBKey(fileInfo: this.fileInfo, config: this.config), () => this);
      return this;
    } catch (_) {
      close();
      rethrow;
    }
  }

  PreparedStatement? _writeStDefault;
  PreparedStatement? _readSt;
  PreparedStatement? _existSt;
  PreparedStatement? _deleteSt;
  List<String>? _readStColumnNames;

  /// Write statements for [DBCommandsCustom], keyed by the written columns.
  final _writeStCache = <String, PreparedStatement>{};

  @override
  bool get isOpen => _isOpen;
  bool _isOpen = false;

  @override
  void close() {
    _isOpen = false;
    final dbKey = _DBKey(fileInfo: fileInfo, config: config);
    if (identical(_openedDBSync[dbKey], this)) _openedDBSync.remove(dbKey);

    _readSt?.close();
    _writeStDefault?.close();
    _existSt?.close();
    _deleteSt?.close();
    for (final st in _writeStCache.values) {
      st.close();
    }
    _writeStCache.clear();
    sql?.close();

    _readSt = null;
    _readStColumnNames = null;
    _writeStDefault = null;
    _existSt = null;
    _deleteSt = null;
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

  /// Runs [action] inside a single transaction, rolling back on error.
  ///
  /// Batching writes this way avoids one implicit transaction (and wal frame flush) per statement.
  T transaction<T>(T Function() action) {
    final sql = this.sql!;
    sql.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      sql.execute('COMMIT');
      return result;
    } catch (_) {
      try {
        sql.execute('ROLLBACK');
      } catch (_) {}
      rethrow;
    }
  }

  @override
  List<Map<String, dynamic>> loadEverythingResult() {
    final values = <Map<String, dynamic>>[];
    this.loadEverything(values.add);
    return values;
  }

  void loadEverything(LoadEverythingCallback onValue) {
    final st = _commandsManager.buildLoadEverythingStatement();
    final (columnNames, rows) = _readAllRows(st, null);
    for (int i = 0; i < rows.length; i++) {
      final parsed = _commands.parseRow(columnNames, rows[i]);
      if (parsed != null) onValue(parsed);
    }
  }

  /// Reads all rows of [st] then closes it. Rows are materialized first & parsed after,
  /// which is measurably faster than interleaving ffi reads with parsing.
  (List<String>, List<List<Object?>>) _readAllRows(PreparedStatement st, List<String>? cachedColumnNames) {
    final rows = <List<Object?>>[];
    List<String> columnNames = const [];
    try {
      final raw = st.raw;
      if (raw.step()) {
        columnNames = _commands.columnNamesForRow(raw, cachedColumnNames);
        final columnCount = raw.columnCount;
        do {
          rows.add(DBCommandsBase.readRawRow(raw, columnCount));
        } while (raw.step());
      }
    } finally {
      st.close();
    }
    return (columnNames, rows);
  }

  @override
  Map<String, Map<String, dynamic>> loadEverythingKeyedResult() {
    final valuesMap = <String, Map<String, dynamic>>{};
    this.loadEverythingKeyed((key, value) => valuesMap[key] = value);
    return valuesMap;
  }

  void loadEverythingKeyed(LoadEverythingKeyedCallback onValue) {
    final st = _commandsManager.buildLoadEverythingKeyedStatement();
    final (columnNames, rows) = _readAllRows(st, null);
    for (int i = 0; i < rows.length; i++) {
      final parsedKeyed = _commands.parseKeyedRow(columnNames, rows[i]);
      if (parsedKeyed == null) continue;
      final parsed = parsedKeyed.map;
      if (parsed != null) onValue(parsedKeyed.key, parsed);
    }
  }

  @override
  List<String> loadAllKeysResult() {
    final values = <String>[];
    this.loadAllKeys(values.add);
    return values;
  }

  /// Reads only `key` + the json fields at [jsonPaths] (e.g. `$.title`) of every row,
  /// extracted by sqlite without decoding the whole value. Values are raw sqlite values (String/int/double/null).
  void loadEverythingExtracted(List<String> jsonPaths, LoadEverythingExtractedCallback onValue) {
    final st = _commandsManager.buildLoadEverythingExtractedStatement(jsonPaths);
    try {
      final raw = st.raw;
      final pathsCount = jsonPaths.length;
      while (raw.step()) {
        if (raw.columnType(0) != SqlType.SQLITE_TEXT) continue;
        final key = raw.columnText(0);
        final values = List<Object?>.filled(pathsCount, null);
        for (int i = 0; i < pathsCount; i++) {
          values[i] = DBCommandsBase.readColumnValue(raw, i + 1);
        }
        onValue(key, values);
      }
    } finally {
      st.close();
    }
  }

  void loadAllKeys(LoadAllKeysCallback onValue) {
    final st = _commandsManager.buildSelectAllKeysStatement();
    try {
      final raw = st.raw;
      while (raw.step()) {
        if (raw.columnType(0) == SqlType.SQLITE_TEXT) onValue(raw.columnText(0));
      }
    } finally {
      st.close();
    }
  }

  @override
  bool containsKey(String key) {
    final st = _existSt ??= _commandsManager.buildExistStatement();
    final raw = st.raw;
    st.reset();
    raw.bindText(1, key);
    try {
      return raw.step();
    } finally {
      st.reset();
    }
  }

  @override
  Map<String, dynamic>? get(String key) {
    final st = _readSt!;
    final raw = st.raw;
    st.reset();
    raw.bindText(1, key);
    try {
      if (!raw.step()) return null;
      final columnNames = _readStColumnNames = _commands.columnNamesForRow(raw, _readStColumnNames);
      return _commands.parseRow(columnNames, DBCommandsBase.readRawRow(raw, raw.columnCount));
    } finally {
      st.reset();
    }
  }

  @override
  List<Map<String, dynamic>> getAll(List<String> keys) {
    final values = <Map<String, dynamic>>[];
    if (keys.isEmpty) return values;

    const chunkSize = DBCommandsBase.maxParametersPerStatement;
    final fullChunks = keys.length ~/ chunkSize;
    final remainder = keys.length % chunkSize;

    if (fullChunks > 0) {
      final st = _commandsManager.buildReadKeysAllStatement(chunkSize);
      try {
        for (int c = 0; c < fullChunks; c++) {
          _readAllInto(st, keys, c * chunkSize, chunkSize, values);
        }
      } finally {
        st.close();
      }
    }
    if (remainder > 0) {
      final st = _commandsManager.buildReadKeysAllStatement(remainder);
      try {
        _readAllInto(st, keys, fullChunks * chunkSize, remainder, values);
      } finally {
        st.close();
      }
    }
    return values;
  }

  void _readAllInto(PreparedStatement st, List<String> keys, int start, int count, List<Map<String, dynamic>> values) {
    final raw = st.raw;
    st.reset();
    for (int i = 0; i < count; i++) {
      raw.bindText(i + 1, keys[start + i]);
    }
    if (!raw.step()) return;
    final columnNames = _readStColumnNames = _commands.columnNamesForRow(raw, _readStColumnNames);
    final columnCount = raw.columnCount;
    final rows = <List<Object?>>[];
    do {
      rows.add(DBCommandsBase.readRawRow(raw, columnCount));
    } while (raw.step());
    for (int i = 0; i < rows.length; i++) {
      final parsed = _commands.parseRow(columnNames, rows[i]);
      if (parsed != null) values.add(parsed);
    }
  }

  @override
  void put(String key, Map<String, dynamic>? object) => _put(key, object);

  void _put(String key, Map<String, dynamic>? object) {
    final writeStDefault = _writeStDefault;
    if (writeStDefault != null) {
      writeStDefault.execute(_commands.objectToWriteParameters(key, object, null));
      return;
    }
    // `DBCommandsCustom` statement depends on which columns [object] has.
    final writeColumns = _commands.writeColumnsOf(object);
    final cacheKey = writeColumns == null ? '' : writeColumns.join(',');
    final st = _writeStCache[cacheKey] ??= _commandsManager.buildWriteStatement(writeColumns);
    st.execute(_commands.objectToWriteParameters(key, object, writeColumns));
  }

  void putAll<E>(DBWriteList writeList) {
    final items = writeList.items;
    if (items.isEmpty) return;
    if (items.length == 1) {
      final item = items[0];
      _put(item.key, item.value);
      return;
    }
    transaction(() {
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        _put(item.key, item.value);
      }
    });
  }

  @override
  void delete(String key) {
    final st = _deleteSt ??= _commandsManager.buildDeleteStatement(1, persistent: true);
    st.execute([key]);
  }

  @override
  void deleteBulk(List<String> keys) {
    if (keys.isEmpty) return;
    const chunkSize = DBCommandsBase.maxParametersPerStatement;
    if (keys.length == 1) return delete(keys[0]);
    if (keys.length <= chunkSize) {
      final st = _commandsManager.buildDeleteStatement(keys.length);
      try {
        st.execute(keys);
      } finally {
        st.close();
      }
      return;
    }

    final fullChunks = keys.length ~/ chunkSize;
    final remainder = keys.length % chunkSize;
    transaction(() {
      final st = _commandsManager.buildDeleteStatement(chunkSize);
      try {
        for (int c = 0; c < fullChunks; c++) {
          final start = c * chunkSize;
          st.execute(keys.sublist(start, start + chunkSize));
        }
      } finally {
        st.close();
      }
      if (remainder > 0) {
        final st = _commandsManager.buildDeleteStatement(remainder);
        try {
          st.execute(keys.sublist(fullChunks * chunkSize));
        } finally {
          st.close();
        }
      }
    });
  }

  @override
  void deleteEverything({bool claimFreeSpaceAndCheckpoint = true}) {
    try {
      sql!.execute(_commands.deleteEverythingCommand(fileInfo.dbTableName));
    } catch (_) {
      _nukeDatabaseFilesAndRecreate();
      return;
    }

    if (claimFreeSpaceAndCheckpoint) this.claimFreeSpaceAndCheckpoint();
  }

  void _nukeDatabaseFilesAndRecreate() {
    try {
      close();
    } catch (_) {}

    final dbPath = fileInfo.file.path;
    for (final suffix in DBWrapper._kDBFilesSuffixes) {
      _deleteWithRetry('$dbPath$suffix');
    }

    _openFromInfoInternal(
      fileInfo: fileInfo,
      config: config.copyWith(createIfNotExist: true),
      createTable: true,
    );
  }

  /// Desperate attempt to overcome windows file lock not being released after [close].
  /// Other platforms could benefit from the retries too.
  void _deleteWithRetry(String path) {
    final file = File(path);
    if (!file.existsSync()) return;

    for (int i = 0; i < 5; i++) {
      try {
        file.deleteSync();
        return;
      } catch (_) {
        sleep(const Duration(milliseconds: 100));
      }
    }
    try {
      file.writeAsBytesSync([]);
    } catch (_) {}
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

  PreparedStatement buildWriteStatement(List<String>? writeColumns) {
    final command = _commands.writeCommand(tableName, writeColumns);
    return sql.prepare(command, persistent: true);
  }

  PreparedStatement buildDeleteStatement(int keysCount, {bool persistent = false}) {
    final command = _commands.deleteCommand(tableName, keysCount);
    return sql.prepare(command, persistent: persistent);
  }

  PreparedStatement buildReadKeyStatement() {
    final command = _commands.selectKeyCommand(tableName);
    return sql.prepare(command, persistent: true);
  }

  PreparedStatement buildReadKeysAllStatement(int keysCount) {
    final command = _commands.selectKeysAllCommand(tableName, keysCount);
    return sql.prepare(command, persistent: false);
  }

  PreparedStatement buildExistStatement() {
    final command = _commands.doesKeyExistCommand(tableName);
    return sql.prepare(command, persistent: true);
  }

  PreparedStatement buildLoadEverythingStatement() {
    final command = _commands.loadEverythingCommand(tableName);
    return sql.prepare(command, persistent: false);
  }

  PreparedStatement buildLoadEverythingKeyedStatement() {
    final command = _commands.loadEverythingKeyedCommand(tableName);
    return sql.prepare(command, persistent: false);
  }

  PreparedStatement buildSelectAllKeysStatement() {
    final command = _commands.selectAllKeysCommand(tableName);
    return sql.prepare(command, persistent: false);
  }

  PreparedStatement buildLoadEverythingExtractedStatement(List<String> jsonPaths) {
    final command = _commands.loadEverythingExtractedCommand(tableName, jsonPaths);
    return sql.prepare(command, persistent: false);
  }
}

extension DatabaseUtils on Database {
  void prepareDatabase({required DBConfig config}) {
    final sql = this;
    final encryptionKey = config.encryptionKey;
    if (encryptionKey != null) {
      try {
        sql.execute("PRAGMA cipher = 'sqlcipher'; PRAGMA legacy = 4;");
        sql.execute('PRAGMA key = ${DBCommandsBase.sqlLiteral(encryptionKey)};');
      } catch (_) {}
    } else {
      try {
        sql.execute("PRAGMA cipher_memory_security = OFF; PRAGMA cipher_use_hmac = OFF; PRAGMA cipher_page_size = 8192; PRAGMA kdf_iter = 8;");
      } catch (_) {}
    }

    // -- wal2 doesn't always work (like on windows)
    const preferredJournalMode = 'wal2';
    const fallbackJournalMode = 'wal';

    String? journalMode;
    try {
      final res = sql.select("PRAGMA journal_mode=$preferredJournalMode;");
      journalMode = res.rows.firstOrNull?.firstOrNull?.toString();
    } catch (_) {}

    final journalModeCommand = journalMode == preferredJournalMode || journalMode == fallbackJournalMode ? '' : 'PRAGMA journal_mode=$fallbackJournalMode; ';

    sql.execute("${journalModeCommand}PRAGMA synchronous=NORMAL; PRAGMA busy_timeout=15000; PRAGMA temp_store=MEMORY;");
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
  final _completers = <int, Completer<dynamic>>{};

  Future<void> dispose({bool beGentle = true}) async {
    // -- give a small chance for queued operations to finish before closing
    if (_completers.isNotEmpty && beGentle) {
      await Future.microtask(() {}); // -- drain already queued port messages
      if (_completers.isNotEmpty) {
        // -- wait up to 500ms
        const interval = Duration(milliseconds: 50);
        for (int i = 0; i < 10 && _completers.isNotEmpty; i++) {
          await Future.delayed(interval);
        }
      }
    }

    if (isInitialized) await disposePort();

    if (_completers.isNotEmpty) {
      final pendingCompleters = _completers.values.toList();
      _completers.clear();

      final err = DatabaseDisposedEarlyException(fileInfo: fileInfo, config: config);
      for (final c in pendingCompleters) {
        c.completeError(err);
      }
    }
  }

  Future<dynamic> executeIsolate(_IsolateEncodable command) async {
    if (!isInitialized) await initialize();
    final token = _tokenManager.next();
    final completer = _completers[token] = Completer<dynamic>();
    sendPort([token, command]);
    return await completer.future;
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
    streamSub = recievePort.listen((p) {
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
      try {
        readRes = command.execute(db);
      } catch (e) {
        exception = e;
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
    final completer = _completers.remove(token);
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
