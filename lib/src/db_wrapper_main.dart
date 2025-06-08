// ignore_for_file: unnecessary_this

part of '../namico_db_wrapper.dart';

/// {@macro DBWrapperMainBase}
///
/// The databases are of type [DBWrapperAsync].
class DBWrapperMain extends DBWrapperMainBase<DBWrapperAsync> {
  DBWrapperMain(
    super.defaultDirectory, {
    super.onFirstOpen,
  });

  @override
  bool _isOpen(DBWrapperAsync box) => box.isOpen;

  @override
  DBWrapperAsync _createDB(String directory, String dbName, {DBConfig config = const DBConfig()}) {
    return DBWrapper.open(directory, dbName, config: config);
  }

  @override
  Future<void>? close(String dbName) => _openDB[dbName]?.close();

  @override
  Future<void> closeAll() async {
    final boxes = _openDB.values.toList();
    _openDB.clear();

    await Future.wait(boxes.map((e) => e.close()));
  }
}

/// {@macro DBWrapperMainBase}
///
/// The databases are of type [DBWrapperSync].
class DBWrapperMainSync extends DBWrapperMainBase<DBWrapperSync> {
  DBWrapperMainSync(
    super.defaultDirectory, {
    super.onFirstOpen,
  });

  @override
  bool _isOpen(DBWrapperSync box) => box.isOpen;

  @override
  DBWrapperSync _createDB(String directory, String dbName, {DBConfig config = const DBConfig()}) {
    return DBWrapper.openSync(directory, dbName, config: config);
  }

  @override
  void close(String dbName) => _openDB[dbName]?.close();

  @override
  void closeAll() {
    final boxes = _openDB.values.toList();
    _openDB.clear();

    for (int i = 0; i < boxes.length; i++) {
      boxes[i].close();
    }
  }
}

/// {@macro DBWrapperMainBase}
///
/// The databases are of type [DBWrapper], which is both sync and async.
class DBWrapperMainSyncAsync extends DBWrapperMainBase<DBWrapper> {
  DBWrapperMainSyncAsync(
    super.defaultDirectory, {
    super.onFirstOpen,
  });

  @override
  DBWrapper getDB(
    String dbName, {
    DBConfig config = const DBConfig(),
  });

  @override
  bool _isOpen(DBWrapper box) => box.isOpen;

  @override
  DBWrapper _createDB(String directory, String dbName, {DBConfig config = const DBConfig()}) {
    return DBWrapper.openSyncAsync(directory, dbName, config: config);
  }

  @override
  Future<void>? close(String dbName) => _openDB[dbName]?.close();

  @override
  Future<void> closeAll() async {
    final boxes = _openDB.values.toList();
    _openDB.clear();

    await Future.wait(boxes.map((e) => e.close()));
  }
}

/// {@template DBWrapperMainBase}
/// A Manager for group of databases in a specific directroy.
/// {@endtemplate}
abstract class DBWrapperMainBase<D extends DBWrapperInterfaceSync> {
  final String _defaultDirectory;
  final void Function(D db)? onFirstOpen;

  /// Initialize a databases manager for a directory.
  DBWrapperMainBase(
    this._defaultDirectory, {
    this.onFirstOpen,
  });

  bool _isOpen(D box);

  D _createDB(String directory, String dbName, {DBConfig config = const DBConfig()});

  final _openDB = <String, D>{};

  /// opens a new db or returns the already opened one. see [DBWrapper.open] or [DBWrapperSync.open] for internal implementation
  D getDB(
    String dbName, {
    DBConfig config = const DBConfig(),
  }) {
    final box = _openDB[dbName];
    if (box != null && _isOpen(box)) return box;

    final dir = _defaultDirectory;
    final newDB = _createDB(
      dir,
      dbName,
      config: config,
    );
    _openDB[dbName] = newDB;
    if (onFirstOpen != null) onFirstOpen!(newDB);
    return newDB;
  }

  /// Close a db by [dbName].
  FutureOr<void> close(String dbName);

  /// Close all databases in [_defaultDirectory] specified by [DBWrapperMain.new].
  FutureOr<void> closeAll();
}
